import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_appearance.dart';
import 'package:terracrop/app/app_shell.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/models.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/screens/profile_screen.dart';

Widget appearanceApp(TerraStore store, AppAppearance appearance) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: appearance),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          theme: appTheme,
          darkTheme: appDarkTheme,
          themeMode: context.watch<AppAppearance>().mode,
          home: const AppShell(),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => AgronomyCatalog.load());
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'guarda y recupera la apariencia sin cambiar los datos agrícolas',
    () async {
      final store = TerraStore();
      await store.load();
      final before = store.parcels.map((p) => p.toJson()).toList();
      final appearance = AppAppearance();
      await appearance.load();
      expect(appearance.mode, ThemeMode.light);
      await appearance.toggle();
      final reopened = AppAppearance();
      await reopened.load();
      expect(reopened.mode, ThemeMode.dark);
      final reloadedStore = TerraStore();
      await reloadedStore.load();
      expect(reloadedStore.parcels.map((p) => p.toJson()).toList(), before);
      await reopened.toggle();
      expect(
        await SharedPreferencesAsync().getString(AppAppearance.preferenceKey),
        'light',
      );
    },
  );

  testWidgets(
    'botón de luna sobre los módulos alterna tema y aparece solo en perfil',
    (tester) async {
      final store = TerraStore()..parcels = demoParcels();
      final appearance = AppAppearance();
      await tester.pumpWidget(appearanceApp(store, appearance));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('profile-theme-toggle'));
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(
        tester.getCenter(toggle).dx,
        greaterThan(
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        ),
      );
      expect(
        tester.getBottomRight(toggle).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('nav-tab-0'))).dy),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(appearance.isDark, isTrue);
      expect(
        Theme.of(tester.element(find.byType(ProfileScreen))).brightness,
        Brightness.dark,
      );
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-tab-3')));
      await tester.pumpAndSettle();
      expect(toggle, findsNothing);
      await tester.tap(find.byKey(const Key('nav-tab-0')));
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(appearance.isDark, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('todos los módulos caben en modo oscuro a 320 píxeles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appearance = AppAppearance();
    await appearance.toggle();
    await tester.pumpWidget(
      appearanceApp(TerraStore()..parcels = demoParcels(), appearance),
    );
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(Key('nav-tab-$i')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'Módulo $i');
    }
  });

  test(
    'texto y acentos mantienen contraste con superficies claras y oscuras',
    () {
      double contrast(Color a, Color b) {
        final values = [a.computeLuminance(), b.computeLuminance()]..sort();
        return (values.last + .05) / (values.first + .05);
      }

      for (final colors in [AppColors.light, AppColors.dark]) {
        for (final background in [
          colors.surface,
          colors.canvas,
          colors.softBlue,
          colors.softGreen,
        ]) {
          expect(contrast(colors.ink, background), greaterThanOrEqualTo(4.5));
          expect(contrast(colors.muted, background), greaterThanOrEqualTo(4.5));
        }
        expect(
          contrast(colors.blue, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(colors.green, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
      }
    },
  );
}
