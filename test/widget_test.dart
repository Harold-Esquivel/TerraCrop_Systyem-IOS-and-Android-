import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/main.dart';
import 'package:terracrop/app/app_shell.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/app/brand.dart';

Widget shellWith(TerraStore store) => ChangeNotifierProvider.value(
  value: store,
  child: MaterialApp(theme: appTheme, home: const AppShell()),
);

void main() {
  test('una parcela crítica conserva sus datos al serializar', () {
    final original = demoParcels()[1];
    final restored = Parcel.fromJson(original.toJson());
    expect(restored.critical, isTrue);
    expect(restored.name, original.name);
    expect(restored.points.length, 4);
    expect(restored.devices.length, 2);
  });

  testWidgets('navegación muestra los cinco módulos en español', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = TerraStore()..parcels = demoParcels();
    await tester.pumpWidget(shellWith(store));
    expect(find.text('Mapa de parcelas'), findsOneWidget);
    await tester.tap(find.text('Mis cultivos'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Mis cultivos'), findsWidgets);
    await tester.tap(find.text('Modo prueba'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Nivel de pH'), findsOneWidget);
    expect(find.byIcon(Icons.science_outlined), findsWidgets);
  });

  testWidgets('los cinco módulos caben en una pantalla compacta', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TerraStore()..parcels = demoParcels();
    await tester.pumpWidget(shellWith(store));
    for (final label in [
      'Mis cultivos',
      'Dispositivos',
      'Mi perfil',
      'Modo prueba',
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 10));
      expect(tester.takeException(), isNull, reason: '$label begin');
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('logo, entrada y plantas preceden a los módulos', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = TerraStore()..parcels = demoParcels();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const TerraCropApp()),
    );
    expect(find.byType(LogoMark), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.tap(find.byKey(const Key('entry-login-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('growing-plants')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Mapa de parcelas'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Mapa de parcelas'), findsOneWidget);
  });

  testWidgets('el círculo viaja entre módulos distantes', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = TerraStore()..parcels = demoParcels();
    await tester.pumpWidget(shellWith(store));
    final finder = find.byKey(const Key('nav-selection-indicator'));
    final start = tester.getCenter(finder).dx;
    await tester.tap(find.text('Modo prueba'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 190));
    final middle = tester.getCenter(finder).dx;
    await tester.pump(const Duration(milliseconds: 250));
    final end = tester.getCenter(finder).dx;
    expect(middle, greaterThan(start));
    expect(middle, lessThan(end));
    expect(find.text('Modo prueba'), findsWidgets);
  });
}
