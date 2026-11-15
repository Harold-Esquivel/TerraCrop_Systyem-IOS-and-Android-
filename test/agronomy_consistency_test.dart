import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/crop_recommendations.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AgronomyCatalog catalog;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    catalog = await AgronomyCatalog.load();
  });

  test('un análisis vacío no aparece como suelo saludable', () {
    final parcel = demoParcels().first.copyWith(
      soilAnalysis: const SoilAnalysis(),
    );
    final assessment = CropRecommendationEngine(catalog).assess(parcel);
    expect(assessment.status, 'Datos por completar');
    expect(parcel.status, isNot('Saludable'));
    expect(
      parcel.warning,
      isTrue,
      reason:
          'Las vistas que cuentan !warning no deben contar datos desconocidos como parcelas saludables',
    );
  });

  test('la CE en el umbral de Papa exige revisión en todas las vistas', () {
    final parcel = demoParcels().first.copyWith(
      crop: 'Papa',
      soilAnalysis: const SoilAnalysis(
        ph: 6.5,
        ec: 1.7,
        organicMatter: 3,
        nitrogen: NutrientLevel.adequate,
        phosphorus: NutrientLevel.adequate,
        potassium: NutrientLevel.adequate,
        moistureLow: false,
        sandySoil: false,
        waterlogged: false,
        soilDiseaseHistory: false,
      ),
    );
    final assessment = CropRecommendationEngine(catalog).assess(parcel);
    expect(assessment.issues.any((issue) => issue.id == 'crop-ec'), isTrue);
    expect(parcel.warning, isTrue);
    expect(parcel.status, isNot('Saludable'));
  });

  test(
    'dos campañas consecutivas de Papa se conservan al registrar Maíz',
    () async {
      final original = demoParcels().first.copyWith(
        crop: 'Papa',
        cropHistory: const ['Papa'],
      );
      final store = TerraStore()..parcels = [original];
      addTearDown(store.dispose);
      await store.updateParcel(original.copyWith(crop: 'Maíz'));
      expect(store.parcels.single.cropHistory, ['Papa', 'Papa']);
      expect(store.parcels.single.crop, 'Maíz');

      final reloaded = TerraStore();
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.parcels.single.cropHistory, ['Papa', 'Papa']);
      expect(reloaded.parcels.single.crop, 'Maíz');
    },
  );
}
