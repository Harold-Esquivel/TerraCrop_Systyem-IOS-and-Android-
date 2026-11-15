import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/market_catalog.dart';
import '../data/terra_store.dart';
import 'market_advice_panel.dart';

class SmartMarketScreen extends StatefulWidget {
  const SmartMarketScreen({super.key});

  @override
  State<SmartMarketScreen> createState() => _SmartMarketScreenState();
}

class _SmartMarketScreenState extends State<SmartMarketScreen> {
  final _cart = MarketCart();
  String _query = '';
  MarketVariable? _filter;
  int _orderNumber = 0;

  void _add(MarketProduct product) {
    setState(() => _cart.add(product));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} añadido al carrito de demostración'),
          action: SnackBarAction(label: 'Ver carrito', onPressed: _showCart),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final products = marketCatalog.where((product) {
      final matchesQuery =
          '${product.name} ${product.subtitle} ${product.measurement}'
              .toLowerCase()
              .contains(_query.toLowerCase().trim());
      return matchesQuery &&
          (_filter == null || product.variables.contains(_filter));
    }).toList();
    return Column(
      children: [
        PageIntro(
          eyebrow: 'Tecnología para tu campo',
          title: 'Smart-Market',
          subtitle: 'Encuentra el sensor para cada variable',
          trailing: IconButton(
            key: const Key('market-cart'),
            tooltip: 'Carrito de demostración',
            onPressed: _showCart,
            icon: Badge(
              isLabelVisible: !_cart.isEmpty,
              label: Text('${_cart.itemCount}'),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: context.colors.blue,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 25),
            children: [
              if (context.watch<TerraStore?>()?.campaignContext
                  case final evaluation?) ...[
                MarketAdvicePanel(evaluation: evaluation),
                const SizedBox(height: 20),
              ],
              SurfaceCard(
                color: context.colors.softBlue,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      color: context.colors.blue,
                      size: 27,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tienda de demostración',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Explora y arma un pedido ficticio. No hay cobros ni envíos. Los precios y la disponibilidad son referencias del archivo de sensores.',
                            style: TextStyle(fontSize: 12, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('market-search'),
                decoration: const InputDecoration(
                  hintText: 'Busca un sensor o variable',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 11),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(null, 'Todos'),
                    for (final variable in MarketVariable.values)
                      _filterChip(variable, variable.label),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Text(
                '${products.length} sensores para explorar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (products.isEmpty)
                const SurfaceCard(
                  child: Text('No encontramos sensores con esa búsqueda.'),
                ),
              for (final product in products) ...[
                _productCard(product),
                const SizedBox(height: 14),
              ],
              Text(
                'Fuente: Resumen de Sensores Agrícolas. Los precios no incluyen costos de importación o envío. Soles y dólares se muestran por separado.',
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(MarketVariable? variable, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == variable,
      onSelected: (_) => setState(() => _filter = variable),
    ),
  );

  IconData _productIcon(MarketProduct product) {
    if (product.variables.length > 2) return Icons.sensors_rounded;
    return switch (product.variables.first) {
      MarketVariable.moisture => Icons.water_drop_outlined,
      MarketVariable.temperature => Icons.thermostat_outlined,
      MarketVariable.ph => Icons.science_outlined,
      MarketVariable.conductivity => Icons.bolt_outlined,
    };
  }

  Widget _productCard(MarketProduct product) => SurfaceCard(
    key: ValueKey('market-product-${product.id}'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 54,
              height: 60,
              decoration: BoxDecoration(
                color: context.colors.softBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _productIcon(product),
                color: context.colors.blue,
                size: 29,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.subtitle,
                    style: TextStyle(fontSize: 12, color: context.colors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          product.description,
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final variable in product.variables)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: context.colors.canvas,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  variable.label,
                  style: TextStyle(fontSize: 10, color: context.colors.muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          product.priceLabel,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: context.colors.blue,
          ),
        ),
        Text(
          product.imported ? 'Referencia de importación' : 'Referencia en Perú',
          style: TextStyle(color: context.colors.muted, fontSize: 11),
        ),
        if (product.unavailableLocalPriceMinor case final int localPrice) ...[
          const SizedBox(height: 6),
          Text(
            'Alternativa local: ${MarketCurrency.pen.format(localPrice)} · Agotada según el archivo',
            style: const TextStyle(color: Color(0xFFAE6240), fontSize: 11),
          ),
        ],
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: ValueKey('market-add-${product.id}'),
            onPressed: () => _add(product),
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text(
              product.imported ? 'Añadir importación · demo' : 'Añadir · demo',
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () => _showDetails(product),
            child: const Text('Ver ficha del sensor'),
          ),
        ),
      ],
    ),
  );

  Future<void> _showDetails(
    MarketProduct product,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .8,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Icon(_productIcon(product), size: 58, color: context.colors.blue),
            const SizedBox(height: 15),
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              product.subtitle,
              style: TextStyle(color: context.colors.muted),
            ),
            const SizedBox(height: 20),
            Text(product.description, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 20),
            _detail('Qué mide', product.measurement),
            _detail('Uso y calibración', product.notes),
            _detail('Referencia del archivo', product.availabilityReference),
            const SizedBox(height: 8),
            Text(
              product.priceLabel,
              style: TextStyle(
                fontSize: 28,
                color: context.colors.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Oferta ficticia. No se verifica stock en tiempo real ni se realizan cobros o envíos.',
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                _add(product);
              },
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Añadir al carrito de demo'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _detail(String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
      ],
    ),
  );

  Future<void> _showCart() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, updateSheet) {
        void updateQuantity(MarketProduct product, int quantity) {
          setState(() => _cart.setQuantity(product, quantity));
          updateSheet(() {});
        }

        return FractionallySizedBox(
          heightFactor: .85,
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Text(
                  'Tu carrito',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pedido ficticio · No se realizarán cobros ni envíos.',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (_cart.isEmpty)
                  const SurfaceCard(
                    child: Text(
                      'Tu carrito está vacío. Explora los sensores y añade uno para probar.',
                    ),
                  ),
                for (final product in marketCatalog)
                  if (_cart.quantityOf(product) > 0) ...[
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (product.imported)
                            Text(
                              'Importación · demo',
                              style: TextStyle(
                                color: context.colors.muted,
                                fontSize: 11,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text('${product.priceLabel} por unidad'),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Quitar una unidad de ${product.name}',
                                onPressed: () => updateQuantity(
                                  product,
                                  _cart.quantityOf(product) - 1,
                                ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                '${_cart.quantityOf(product)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Añadir una unidad de ${product.name}',
                                onPressed: _cart.quantityOf(product) >= 99
                                    ? null
                                    : () => updateQuantity(
                                        product,
                                        _cart.quantityOf(product) + 1,
                                      ),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              TextButton(
                                onPressed: () => updateQuantity(product, 0),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                if (!_cart.isEmpty) ...[
                  const Divider(height: 28),
                  const Text(
                    'Subtotales de referencia',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in _cart.totals.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        entry.key.format(entry.value),
                        style: TextStyle(
                          color: context.colors.blue,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Text(
                    'Monedas separadas, sin conversión. Importación y envío no incluidos.',
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('market-demo-checkout'),
                    onPressed: () {
                      final total = _cart.totals.entries
                          .map((entry) => entry.key.format(entry.value))
                          .join(' + ');
                      final count = _cart.itemCount;
                      setState(() {
                        _cart.clear();
                        _orderNumber++;
                      });
                      Navigator.pop(sheetContext);
                      showDialog<void>(
                        context: this.context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Pedido de demostración'),
                          content: Text(
                            'TC-DEMO-$_orderNumber\n$count unidades · $total\n\nLa simulación terminó. No se ha realizado ningún cobro ni se enviarán productos.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Entendido'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Completar pedido ficticio'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
