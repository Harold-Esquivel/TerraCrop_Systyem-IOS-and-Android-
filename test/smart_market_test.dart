import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terracrop/app/app_theme.dart';
import 'package:terracrop/data/market_catalog.dart';
import 'package:terracrop/screens/smart_market_screen.dart';

void main() {
  test('el carrito conserva monedas separadas y elimina subtotales vacíos', () {
    final cart = MarketCart();
    final soil = marketCatalog.firstWhere((p) => p.id == 'sen0193');
    final imported = marketCatalog.firstWhere((p) => p.id == 'dfr0300');

    cart.add(soil);
    cart.add(soil);
    cart.add(imported);

    expect(cart.itemCount, 3);
    expect(cart.totals, {MarketCurrency.pen: 7400, MarketCurrency.usd: 6990});
    expect(
      MarketCurrency.usd.format(cart.totals[MarketCurrency.usd]!),
      'US\$ 69.90',
    );

    cart.setQuantity(soil, 0);
    expect(cart.totals, {MarketCurrency.usd: 6990});
    expect(cart.quantityOf(imported), 1);
    cart.clear();
    expect(cart.isEmpty, isTrue);
    expect(cart.totals, isEmpty);
  });

  test('SEN0604 se añade como importación, no como oferta local agotada', () {
    final product = marketCatalog.firstWhere((p) => p.id == 'sen0604');
    final cart = MarketCart()..add(product);

    expect(product.imported, isTrue);
    expect(product.unavailableLocalPriceMinor, 39000);
    expect(cart.totals, {MarketCurrency.usd: 6900});
    expect(cart.totals.containsKey(MarketCurrency.pen), isFalse);
  });

  testWidgets('compra ficticia usable en pantalla compacta sin cobros', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: SafeArea(child: SmartMarketScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final add = find.byKey(const ValueKey('market-add-sen0193'));
    await tester.scrollUntilVisible(
      add,
      200,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-cart')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('S/ 37'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final checkout = find.byKey(const Key('market-demo-checkout'));
    await tester.ensureVisible(checkout);
    await tester.pumpAndSettle();
    await tester.tap(checkout);
    await tester.pumpAndSettle();
    expect(find.text('Pedido de demostración'), findsOneWidget);
    expect(
      find.textContaining('No se ha realizado ningún cobro'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market-cart')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tu carrito está vacío'), findsOneWidget);
  });

  testWidgets('la ficha de pH conserva la limitación de medición en seco', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: SmartMarketScreen()),
      ),
    );
    final search = find.byKey(const Key('market-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'SEN0161');
    await tester.pumpAndSettle();
    final details = find.text('Ver ficha del sensor');
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No mide en suelo seco. Requiere extracción suelo-agua y calibración.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
