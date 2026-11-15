import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/data/agronomy_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AgronomyCatalog.load();
  });
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('las parcelas antiguas se cargan sin perder lecturas ni geometría', () {
    final original = demoParcels().first;
    final oldJson = original.toJson()
      ..remove('soilAnalysis')
      ..remove('cropHistory');
    final restored = Parcel.fromJson(oldJson);
    expect(restored.crop, original.crop);
    expect(restored.points, original.points);
    expect(restored.nitrogen, original.nitrogen);
    expect(restored.soilAnalysis, isNull);
    expect(restored.cropHistory, isEmpty);
  });

  test(
    'análisis e historial se conservan al reiniciar sin sustituir índices demo',
    () async {
      final store = TerraStore();
      await store.load();
      final original = store.parcels.first;
      await store.updateParcel(
        original.copyWith(
          soilAnalysis: SoilAnalysis(
            ph: 7.8,
            ec: 2.5,
            organicMatter: 1.2,
            nitrogen: NutrientLevel.low,
            phosphorus: NutrientLevel.adequate,
            potassium: NutrientLevel.unknown,
            sandySoil: true,
            moistureLow: true,
            waterlogged: false,
            sampledAt: DateTime(2026, 11, 15),
          ),
          cropHistory: ['Cebolla', 'Haba'],
        ),
      );
      final reloaded = TerraStore();
      await reloaded.load();
      final saved = reloaded.parcels.first;
      expect(saved.soilAnalysis!.ph, 7.8);
      expect(saved.soilAnalysis!.ec, 2.5);
      expect(saved.soilAnalysis!.nitrogen, NutrientLevel.low);
      expect(saved.soilAnalysis!.potassium, NutrientLevel.unknown);
      expect(saved.soilAnalysis!.moistureLow, isTrue);
      expect(saved.soilAnalysis!.waterlogged, isFalse);
      expect(saved.soilAnalysis!.soilDiseaseHistory, isNull);
      expect(saved.cropHistory, ['Cebolla', 'Haba']);
      expect(saved.nitrogen, original.nitrogen);
      expect(saved.points, original.points);
    },
  );

  test(
    'registrar otro cultivo añade el actual al historial una sola vez',
    () async {
      final store = TerraStore();
      await store.load();
      final original = store.parcels.first;
      await store.updateParcel(original.copyWith(crop: 'Haba'));
      expect(store.parcels.first.cropHistory, ['Maíz']);
      await store.updateParcel(
        store.parcels.first.copyWith(name: 'Parcela renombrada'),
      );
      expect(store.parcels.first.cropHistory, ['Maíz']);
      await store.updateParcel(store.parcels.first.copyWith(crop: 'Zapallo'));
      final reloaded = TerraStore();
      await reloaded.load();
      expect(reloaded.parcels.first.cropHistory, ['Maíz', 'Haba']);
      expect(reloaded.parcels.first.crop, 'Zapallo');
    },
  );

  test(
    'normalizar el nombre del mismo cultivo no inventa una campaña',
    () async {
      final store = TerraStore();
      await store.load();
      await store.updateParcel(store.parcels.first.copyWith(crop: 'maiz'));
      expect(store.parcels.first.cropHistory, isEmpty);
    },
  );

  test(
    'lecturas ausentes o inválidas quedan desconocidas, no se convierten en cero',
    () {
      final analysis = SoilAnalysis.fromJson({
        'ph': double.nan,
        'ec': -1,
        'organicMatter': 120,
        'nitrogen': 'unrecognized',
      });
      expect(analysis.ph, isNull);
      expect(analysis.ec, isNull);
      expect(analysis.organicMatter, isNull);
      expect(analysis.nitrogen, NutrientLevel.unknown);
      final parcel = demoParcels().first.copyWith(
        soilAnalysis: const SoilAnalysis(),
      );
      expect(parcel.copyWith(name: 'Otro nombre').soilAnalysis, isNotNull);
      expect(parcel.copyWith(clearSoilAnalysis: true).soilAnalysis, isNull);
    },
  );
}
