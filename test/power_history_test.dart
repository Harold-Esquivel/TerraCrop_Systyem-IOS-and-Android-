import 'package:flutter_test/flutter_test.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/campaign_engine.dart';
import 'package:terracrop/data/environment_repository.dart';
import 'package:terracrop/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EnvironmentRepository environment;
  late CampaignEngine engine;
  setUpAll(() async {
    environment = await EnvironmentRepository.load();
    engine = CampaignEngine(await AgronomyCatalog.load(), environment);
  });

  CampaignInput input({bool regional = false}) => CampaignInput(
    parcel: demoParcels().first.copyWith(clearSoilAnalysis: true),
    previousCrop: 'Papa',
    cropId: 'C014',
    start: DateTime.utc(2027, 2),
    availableDays: 180,
    useRegionalClimateReference: regional,
  );

  test('carga 924 observaciones nuevas y conserva las 1539 anteriores', () {
    expect(environment.sources, hasLength(9));
    expect(environment.observations, hasLength(2463));
    expect(environment.forecasts, isEmpty);
    final february = environment.monthly('power_T2M', 2)!;
    expect(february.years, 11);
    expect(february.period, '2015–2025');
    expect(february.mean, closeTo(21.5584, .000051));
    expect(environment.monthly('gpm', 2)!.period, '2015–2024');
  });

  test('lluvia es acumulado mensual y radiación se convierte de MJ a kWh', () {
    expect(
      environment.monthly('power_PRECTOTCORR', 2)!.mean,
      closeTo(24.2291, .000051),
    );
    final radiation = environment.monthly('power_ALLSKY_SFC_SW_DWN', 2)!;
    expect(radiation.source.unit, 'kWh/m²/day');
    expect(radiation.mean * 3.6, closeTo(20.9669, .000051));
    expect(environment.monthly('power_WS2M', 2)!.source.unit, 'm/s');
  });

  test(
    'las referencias sin coordenadas no se asignan automáticamente a una parcela',
    () {
      final regional = environment.sources.where((s) => s.isRegionalReference);
      expect(regional, hasLength(8));
      for (final source in regional) {
        expect(source.latitude, isNull);
        expect(source.longitude, isNull);
        expect(source.covers(input().parcel), isFalse);
      }
      expect(
        engine
            .evaluate(input())
            .climate
            .any((c) => c.source.id.startsWith('power_')),
        isFalse,
      );
    },
  );

  test(
    'la selección explícita usa clima histórico y conserva desconocidos suelo y riego',
    () {
      final evaluation = engine.evaluate(input(regional: true));
      expect(
        evaluation.climate.map((c) => c.source.id),
        containsAll([
          'power_T2M',
          'power_T2M_MIN',
          'power_T2M_MAX',
          'power_PRECTOTCORR',
          'power_RH2M',
          'power_ALLSKY_SFC_SW_DWN',
          'power_WS2M',
        ]),
      );
      expect(
        evaluation.alerts.any((a) => a.id == 'regional-climate-reference'),
        isTrue,
      );
      expect(evaluation.alerts.any((a) => a.id.startsWith('thermal-')), isTrue);
      expect(evaluation.input.parcel.soilAnalysis, isNull);
      expect(
        evaluation.missingData,
        contains('Disponibilidad de riego desconocida.'),
      );
      expect(evaluation.forecasts, isEmpty);
      expect(
        evaluation.forecastMessage,
        contains('Pronóstico estacional no disponible'),
      );
    },
  );

  test(
    'alternativas y secuencias conservan la elección de referencia climática',
    () {
      for (final evaluation in engine.alternatives(input(regional: true))) {
        expect(evaluation.input.useRegionalClimateReference, isTrue);
      }
      for (final sequence in engine.compareSequences(input(regional: true))) {
        expect(
          sequence.steps.every((s) => s.input.useRegionalClimateReference),
          isTrue,
        );
      }
    },
  );
}
