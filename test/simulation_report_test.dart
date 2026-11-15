import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/crop_simulation.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/simulation_pdf.dart';
import 'package:terracrop/data/simulation_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AgronomyCatalog catalog;
  setUpAll(() async => catalog = await AgronomyCatalog.load());
  SimulationScenario scenario(
    Parcel parcel, {
    Set<SimulationEvent> events = const {SimulationEvent.drought},
  }) => SimulationScenario(
    source: parcel,
    input: SimulationInput(
      parcel: parcel.copyWith(clearSoilAnalysis: true),
      events: events,
    ),
  );
  SimulationReport report(List<SimulationScenario> scenarios) =>
      SimulationReport.generate(
        scenarios: scenarios,
        catalog: catalog,
        createdAt: DateTime(2026, 11, 15, 14, 30),
      );

  test(
    'solo incluye parcelas elegidas, cada una con sus resultados y datos originales',
    () {
      final parcels = demoParcels();
      final before = parcels.map((p) => p.toJson()).toList();
      final result = report([scenario(parcels[0]), scenario(parcels[2])]);
      expect(result.parcels.map((p) => p.scenario.source.id), [
        parcels[0].id,
        parcels[2].id,
      ]);
      for (final parcel in result.parcels) {
        final direct = CropSimulation.run(parcel.scenario.input);
        expect(parcel.result.finalHealth, direct.finalHealth);
        expect(parcel.result.finalLossPercent, direct.finalLossPercent);
      }
      expect(parcels.map((p) => p.toJson()).toList(), before);
      expect(result.fileName, 'TerraCrop-SmartCycle-20261115-143000.pdf');
    },
  );

  test(
    'recomendaciones usan el análisis y no convierten la fertilización simulada en una corrección real',
    () {
      final parcel = demoParcels().first.copyWith(
        soilAnalysis: const SoilAnalysis(
          organicMatter: 1.2,
          nitrogen: NutrientLevel.low,
          phosphorus: NutrientLevel.high,
        ),
      );
      final result = report([
        scenario(parcel, events: {SimulationEvent.fertilization}),
      ]).parcels.single;
      expect(
        result.currentCare.map((c) => c.id),
        containsAll(['S007', 'S009', 'high-fósforo']),
      );
      expect(
        result.currentCare.firstWhere((c) => c.id == 'S007').instruction,
        contains('estiércol bien curado'),
      );
      expect(result.currentCare.any((c) => c.id == 'S008'), isFalse);
      expect(result.scenarioCare.single.id, 'fertilization');
      expect(result.scenario.source.soilAnalysis?.nitrogen, NutrientLevel.low);
    },
  );

  test(
    'análisis parcial no hereda carencias demo y encharcamiento impide aconsejar más riego',
    () {
      final partial = demoParcels().first.copyWith(
        nitrogen: 0,
        phosphorus: 0,
        potassium: 0,
        soilAnalysis: const SoilAnalysis(ph: 6.5, waterlogged: true),
      );
      final result = report([scenario(partial)]).parcels.single;
      expect(result.currentCare.map((c) => c.id), ['S012']);
      expect(result.scenarioCare.any((c) => c.id == 'dry-weather'), isFalse);
      expect(result.needsSoilData, isTrue);
    },
  );

  test(
    'captura el análisis y rechaza selecciones vacías, duplicadas o de otra parcela',
    () {
      final parcel = demoParcels().first.copyWith(cropHistory: ['Cebolla']);
      final snapshot = scenario(parcel);
      final original = snapshot.source.cropHistory.toList();
      parcel.cropHistory.add('Papa');
      expect(snapshot.source.cropHistory, original);
      expect(() => report([]), throwsArgumentError);
      expect(() => report([snapshot, snapshot]), throwsArgumentError);
      expect(
        () => SimulationScenario(
          source: parcel,
          input: SimulationInput(parcel: demoParcels()[1]),
        ),
        throwsArgumentError,
      );
      parcel.cropHistory.clear();
    },
  );

  test(
    'genera un PDF multiparcela con acentos que puede abrirse sin conexión',
    () async {
      final first = demoParcels().first.copyWith(
        name: 'Parcela Norte · Maíz',
        soilAnalysis: const SoilAnalysis(
          organicMatter: 1.2,
          nitrogen: NutrientLevel.low,
          moistureLow: true,
          sandySoil: true,
        ),
      );
      final second = demoParcels()[1].copyWith(
        name: 'Parcela Sur · Papa',
        soilAnalysis: const SoilAnalysis(
          ph: 8.6,
          ec: 4.5,
          organicMatter: 1.2,
          nitrogen: NutrientLevel.low,
          phosphorus: NutrientLevel.low,
          potassium: NutrientLevel.low,
          waterlogged: true,
          moistureLow: true,
          sandySoil: true,
          soilDiseaseHistory: true,
        ),
      );
      final data = report([
        scenario(first, events: SimulationEvent.values.toSet()),
        scenario(second),
      ]);
      final bytes = await SimulationPdf.create(data);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(
        String.fromCharCodes(bytes.skip(bytes.length - 20)),
        contains('%%EOF'),
      );
      expect(bytes.length, greaterThan(1000));
      final file = File('build/simulation-report-review/example.pdf');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    },
  );
}
