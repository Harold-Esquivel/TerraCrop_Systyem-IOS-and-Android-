import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:terracrop/data/terra_store.dart';

final class FailsOncePreferences extends InMemorySharedPreferencesAsync {
  FailsOncePreferences() : super.empty();

  bool failNextWrite = false;

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('temporary write failure');
    }
    return super.setString(key, value, options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la geometría editada se conserva al recargar el almacén', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    final store = TerraStore();
    await store.load();
    final original = store.parcels.first;
    final newPoints = [
      ...original.points.take(1),
      const LatLng(-12.0438, -77.0275),
      ...original.points.skip(2),
    ];

    await store.updateParcel(original.copyWith(points: newPoints));

    final reloaded = TerraStore();
    await reloaded.load();
    final saved = reloaded.parcels.first;
    expect(saved.points, newPoints);
    expect(saved.name, original.name);
    expect(saved.crop, original.crop);
    expect(saved.devices.length, original.devices.length);
    expect(reloaded.parcels.length, store.parcels.length);
  });

  test('un fallo transitorio no bloquea los guardados posteriores', () async {
    final preferences = FailsOncePreferences();
    SharedPreferencesAsyncPlatform.instance = preferences;

    final store = TerraStore();
    await store.load();
    final original = store.parcels.first;
    preferences.failNextWrite = true;

    await expectLater(
      store.updateParcel(original.copyWith(name: 'Primer cambio')),
      throwsA(isA<StateError>()),
    );

    final editedPoints = [
      ...original.points.take(1),
      const LatLng(-12.0438, -77.0275),
      ...original.points.skip(2),
    ];
    await store.updateParcel(
      original.copyWith(name: 'Cambio guardado', points: editedPoints),
    );

    final reloaded = TerraStore();
    await reloaded.load();
    expect(reloaded.parcels.first.name, 'Cambio guardado');
    expect(reloaded.parcels.first.points, editedPoints);
  });
}
