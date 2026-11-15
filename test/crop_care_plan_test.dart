import 'package:flutter_test/flutter_test.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/crop_care_plan.dart';
import 'package:terracrop/data/crop_recommendations.dart';
import 'package:terracrop/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CropRecommendationEngine engine;
  setUpAll(
    () async => engine = CropRecommendationEngine(await AgronomyCatalog.load()),
  );
  List<CropCareAction> care(SoilAnalysis analysis) {
    final parcel = demoParcels().first.copyWith(soilAnalysis: analysis);
    return buildCropCarePlan(parcel, engine.assess(parcel));
  }

  test('estiércol curado solo cuando se conoce materia orgánica baja', () {
    final low = care(const SoilAnalysis(organicMatter: 1.2));
    expect(low.single.title, 'Refuerza la materia orgánica');
    expect(low.single.instruction, contains('estiércol bien curado'));
    expect(low.single.reason, contains('1.2%'));
    expect(care(const SoilAnalysis()), isEmpty);
    expect(care(const SoilAnalysis(organicMatter: 2)), isEmpty);
  });

  test(
    'riego concreto requiere humedad baja y textura arenosa confirmadas',
    () {
      final sandy = care(
        const SoilAnalysis(moistureLow: true, sandySoil: true),
      );
      expect(
        sandy.single.instruction,
        contains('más frecuentes y de menor lámina'),
      );
      final unknownTexture = care(const SoilAnalysis(moistureLow: true));
      expect(
        unknownTexture.single.instruction,
        contains('Confirma la humedad y la textura'),
      );
      expect(
        care(const SoilAnalysis(moistureLow: false, sandySoil: true)),
        isEmpty,
      );
    },
  );

  test('encharcamiento tiene prioridad y frena el aumento de riego', () {
    final actions = care(
      const SoilAnalysis(
        ec: 4.5,
        waterlogged: true,
        moistureLow: true,
        sandySoil: true,
      ),
    );
    expect(actions.first.topic, CropCareTopic.drainage);
    expect(actions.first.instruction, contains('Reduce la lámina'));
    expect(
      actions.firstWhere((a) => a.topic == CropCareTopic.water).instruction,
      contains('Los datos se contradicen'),
    );
    expect(
      actions.firstWhere((a) => a.topic == CropCareTopic.salinity).instruction,
      contains('Resuelve el encharcamiento antes'),
    );
  });

  test(
    'salinidad conserva precauciones para compost y potasio y agrupa CE',
    () {
      final actions = care(
        const SoilAnalysis(
          ec: 4.5,
          organicMatter: 1,
          potassium: NutrientLevel.low,
        ),
      );
      final salts = actions
          .where((a) => a.topic == CropCareTopic.salinity)
          .single;
      expect(salts.sourceIssueIds, containsAll(['S001', 'crop-ec']));
      expect(
        actions
            .firstWhere((a) => a.topic == CropCareTopic.organicMatter)
            .instruction,
        contains('evita estiércol fresco'),
      );
      expect(
        actions
            .firstWhere((a) => a.topic == CropCareTopic.potassium)
            .instruction,
        contains('sulfato de potasio en lugar de cloruro'),
      );
    },
  );

  test('nutrientes altos no generan una recomendación de aporte', () {
    final actions = care(const SoilAnalysis(nitrogen: NutrientLevel.high));
    expect(actions.single.title, 'Evita añadir más nitrógeno');
    expect(actions.single.topic, CropCareTopic.nutrientExcess);
  });

  test(
    'prioriza y agrupa problemas sin perder sus reglas ni cambiar datos',
    () {
      final parcel = demoParcels().first.copyWith(
        ph: 5.3,
        nitrogen: 20,
        phosphorus: 20,
        potassium: 20,
        moisture: 20,
      );
      final before = parcel.toJson();
      final assessment = engine.assess(parcel);
      final actions = buildCropCarePlan(parcel, assessment);
      expect(actions.length, 5);
      expect(actions.first.topic, CropCareTopic.ph);
      expect(actions.first.sourceIssueIds, containsAll(['S006', 'crop-ph']));
      expect(
        actions.expand((a) => a.sourceIssueIds).toSet(),
        assessment.issues.map((issue) => issue.id).toSet(),
      );
      for (final action in actions) {
        expect(action.instruction.length, lessThanOrEqualTo(160));
        expect(action.instruction, isNot(contains('Excel')));
      }
      expect(parcel.toJson(), before);
    },
  );
}
