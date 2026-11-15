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
import 'package:terracrop/screens/devices_screen.dart';
import 'package:terracrop/screens/map_screen.dart';
import 'package:terracrop/screens/profile_screen.dart';
import 'package:terracrop/screens/smart_cycle_screen.dart';
import 'package:terracrop/screens/smart_market_screen.dart';

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

  testWidgets('la navegación respeta el orden y abre Mi perfil primero', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = TerraStore()..parcels = demoParcels();
    await tester.pumpWidget(shellWith(store));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);
    const labels = [
      'Mi perfil',
      'Smart-Cycle',
      'Cultivos',
      'Smart-Market',
      'MAPA',
    ];
    double previousX = -1;
    for (var i = 0; i < labels.length; i++) {
      final tab = find.byKey(Key('nav-tab-$i'));
      expect(
        find.descendant(of: tab, matching: find.text(labels[i])),
        findsOneWidget,
      );
      final x = tester.getCenter(tab).dx;
      expect(x, greaterThan(previousX));
      previousX = x;
    }
    await tester.tap(find.byKey(const Key('nav-tab-1')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SmartCycleScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-tab-2')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Cultivos'), findsWidgets);
    await tester.tap(find.byKey(const Key('nav-tab-3')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SmartMarketScreen), findsOneWidget);
  });

  testWidgets('Dispositivos se abre desde Mi perfil y permite volver', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = TerraStore()..parcels = demoParcels();
    await tester.pumpWidget(shellWith(store));
    await tester.tap(find.byKey(const Key('profile-devices-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DevicesScreen), findsOneWidget);
    expect(find.text('Mis dispositivos'), findsOneWidget);
    expect(find.text('Sensor de suelo 01'), findsOneWidget);
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('profile-devices-button')), findsOneWidget);
  });

  testWidgets('simulador y tienda conservan su estado al cambiar de módulo', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = TerraStore()..parcels = demoParcels();
    await tester.pumpWidget(shellWith(store));
    await tester.tap(find.byKey(const Key('nav-tab-1')));
    await tester.pump(const Duration(milliseconds: 500));
    final cycle = tester.element(find.byType(SmartCycleScreen));
    await tester.tap(find.byKey(const Key('nav-tab-3')));
    await tester.pump(const Duration(milliseconds: 500));
    final market = tester.element(find.byType(SmartMarketScreen));
    await tester.tap(find.byKey(const Key('nav-tab-0')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('nav-tab-1')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      identical(tester.element(find.byType(SmartCycleScreen)), cycle),
      isTrue,
    );
    await tester.tap(find.byKey(const Key('nav-tab-3')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      identical(tester.element(find.byType(SmartMarketScreen)), market),
      isTrue,
    );
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
    for (var i = 0; i < 5; i++) {
      final label = [
        'Mi perfil',
        'Smart-Cycle',
        'Cultivos',
        'Smart-Market',
        'MAPA',
      ][i];
      await tester.tap(find.byKey(Key('nav-tab-$i')));
      await tester.pump(const Duration(milliseconds: 10));
      expect(tester.takeException(), isNull, reason: '$label begin');
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('Smart-Cycle permite revisar estadísticas en pantalla compacta', (
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
    await tester.tap(find.byKey(const Key('nav-tab-1')));
    await tester.pump(const Duration(milliseconds: 500));
    final scrollable = find
        .descendant(
          of: find.byType(SmartCycleScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Estadística por día'),
      300,
      scrollable: scrollable,
      maxScrolls: 30,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('Estadística por día'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cómo se calcula'),
      250,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Cómo se calcula'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
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
    expect(find.byType(ProfileScreen), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('el círculo viaja entre módulos distantes', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = TerraStore()..parcels = demoParcels();
    await tester.pumpWidget(shellWith(store));
    final finder = find.byKey(const Key('nav-selection-indicator'));
    final start = tester.getCenter(finder).dx;
    await tester.tap(find.byKey(const Key('nav-tab-4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 190));
    final middle = tester.getCenter(finder).dx;
    await tester.pump(const Duration(milliseconds: 250));
    final end = tester.getCenter(finder).dx;
    expect(middle, greaterThan(start));
    expect(middle, lessThan(end));
    expect(find.text('Mapa de parcelas'), findsOneWidget);
  });
}
