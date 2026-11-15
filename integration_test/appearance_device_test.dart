import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:terracrop/app/app_appearance.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/main.dart';
import 'package:terracrop/screens/profile_screen.dart';
import 'package:terracrop/screens/smart_cycle_screen.dart';
import 'package:terracrop/screens/smart_market_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('apariencia clara, oscura y persistencia entre módulos', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await AgronomyCatalog.load();
    final store = TerraStore();
    await store.load();
    final before = store.parcels.map((p) => p.toJson()).toList();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const TerraCropApp()),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('entry-login-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('01-perfil-claro');
    final toggle = find.byKey(const Key('profile-theme-toggle'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(ProfileScreen))).brightness,
      Brightness.dark,
    );
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    await binding.takeScreenshot('02-perfil-oscuro');
    await tester.tap(find.byKey(const Key('profile-devices-button')));
    // Connected-device dots animate continuously; wait for route entry.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('03-dispositivos-oscuro');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-tab-1')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SmartCycleScreen))).brightness,
      Brightness.dark,
    );
    expect(toggle, findsNothing);
    await binding.takeScreenshot('04-smart-cycle-oscuro');
    await tester.tap(find.byKey(const Key('cycle-show-results')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('05-resultado-oscuro');
    await tester.scrollUntilVisible(
      find.text('Evolución de la condición'),
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 25,
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('06-grafica-oscura');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-tab-3')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SmartMarketScreen))).brightness,
      Brightness.dark,
    );
    await binding.takeScreenshot('07-market-oscuro');
    await tester.tap(find.byKey(const Key('market-cart')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('08-carrito-oscuro');
    await tester.tapAt(const Offset(12, 100));
    await tester.pumpAndSettle();
    final reopened = AppAppearance();
    await reopened.load();
    expect(reopened.mode, ThemeMode.dark);
    reopened.dispose();
    await tester.tap(find.byKey(const Key('nav-tab-0')));
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(ProfileScreen))).brightness,
      Brightness.light,
    );
    expect(store.parcels.map((p) => p.toJson()).toList(), before);
    expect(tester.takeException(), isNull);
  });
}
