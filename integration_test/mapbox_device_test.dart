import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/main.dart';
import 'package:terracrop/screens/mapbox_parcel_map.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsOneWidget);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  testWidgets('Mapbox en dispositivo: vistas y persistencia de vértices', (
    tester,
  ) async {
    expect(token.startsWith('pk.'), isTrue, reason: 'Falta el token público');
    MapboxOptions.setAccessToken(token);
    final store = TerraStore();
    await store.load();
    // Use the real local store and UI without requesting notification permission.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const TerraCropApp()),
    );
    final login = find.byKey(const Key('entry-login-button'));
    await waitFor(tester, login);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(login);
    await waitFor(tester, find.byType(MapboxParcelMap));
    await tester.pump(const Duration(seconds: 15));
    expect(tester.takeException(), isNull);
    expect(find.byType(MapWidget), findsOneWidget);
    await binding.takeScreenshot('mapbox-3d');

    await tester.tap(find.text('Vista 2D'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Vista 3D'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('mapbox-2d');

    if (store.parcels.isNotEmpty) {
      final original = store.parcels.first;
      final map = tester.widget<MapboxParcelMap>(find.byType(MapboxParcelMap));
      // Exercise the drag-completion boundary, not a synthesized native gesture.
      map.onParcelTap(original.id);
      await tester.pump(const Duration(seconds: 1));
      final moved = LatLng(
        original.points.first.latitude + .0001,
        original.points.first.longitude + .0001,
      );
      try {
        await map.onVertexMoved(original.id, 0, moved);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Forma de la parcela guardada'), findsOneWidget);
        final reloaded = TerraStore();
        await reloaded.load();
        expect(
          reloaded.parcels.firstWhere((p) => p.id == original.id).points.first,
          moved,
        );
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('mapbox-vertice-guardado');
      } finally {
        await store.updateParcel(original);
      }
    }

    await tester.tap(find.text('Mis cultivos').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Mapa').last);
    await waitFor(tester, find.byType(MapboxParcelMap));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('mapbox-regreso-al-mapa');
  });
}
