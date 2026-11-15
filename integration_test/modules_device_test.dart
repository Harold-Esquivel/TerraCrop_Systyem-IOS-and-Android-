import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:terracrop/data/terra_store.dart';
import 'package:terracrop/main.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsOneWidget);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('perfil, dispositivos, Smart-Cycle y carrito de Smart-Market', (
    tester,
  ) async {
    final store = TerraStore();
    await store.load();
    final originalParcels = store.parcels.map((p) => p.toJson()).toList();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const TerraCropApp()),
    );
    final login = find.byKey(const Key('entry-login-button'));
    await waitFor(tester, login);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(login);
    await waitFor(tester, find.byKey(const Key('nav-tab-0')));
    await tester.pump(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('01-perfil');
    await tester.tap(find.byKey(const Key('profile-devices-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Mis dispositivos'), findsOneWidget);
    await binding.takeScreenshot('02-dispositivos');
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const Key('nav-tab-1')));
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('03-smart-cycle-eventos');
    await tester.scrollUntilVisible(
      find.byKey(const Key('cycle-window-result')),
      220,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot('04-smart-cycle-resultados');
    await tester.scrollUntilVisible(
      find.text('Evolución de la condición'),
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot('05-smart-cycle-grafica');

    await tester.tap(find.byKey(const Key('nav-tab-3')));
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('06-smart-market');
    await tester.enterText(find.byKey(const Key('market-search')), 'SEN0193');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));
    final add = find.byKey(const Key('market-add-sen0193'));
    await tester.scrollUntilVisible(
      add,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 500));
    // Switching modules must retain the cart and the scenario.
    await tester.tap(find.byKey(const Key('nav-tab-0')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('nav-tab-3')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('market-cart')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('S/ 37'), findsWidgets);
    expect(find.byKey(const Key('market-demo-checkout')), findsOneWidget);
    await binding.takeScreenshot('07-smart-market-carrito');
    expect(store.parcels.map((p) => p.toJson()).toList(), originalParcels);
    expect(tester.takeException(), isNull);
  });
}
