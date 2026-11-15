enum MarketCurrency {
  pen('S/'),
  usd('US\$');

  const MarketCurrency(this.symbol);
  final String symbol;

  String format(int minorUnits) =>
      '$symbol ${(minorUnits / 100).toStringAsFixed(minorUnits % 100 == 0 ? 0 : 2)}';
}

enum MarketVariable {
  moisture('Humedad'),
  temperature('Temperatura'),
  ph('pH'),
  conductivity('Conductividad');

  const MarketVariable(this.label);
  final String label;
}

class MarketProduct {
  const MarketProduct({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.variables,
    required this.measurement,
    required this.notes,
    required this.priceMinor,
    required this.currency,
    required this.availabilityReference,
    this.imported = false,
    this.unavailableLocalPriceMinor,
  });

  final String id;
  final String name;
  final String subtitle;
  final String description;
  final List<MarketVariable> variables;
  final String measurement;
  final String notes;
  final int priceMinor;
  final MarketCurrency currency;
  final String availabilityReference;
  final bool imported;
  final int? unavailableLocalPriceMinor;

  String get priceLabel => currency.format(priceMinor);
}

/// Reference data supplied in Resumen de Sensores Agrícolas.md.
/// Prices, stock and import costs are not live offers.
const marketCatalog = <MarketProduct>[
  MarketProduct(
    id: 'sen0193',
    name: 'SEN0193',
    subtitle: 'Humedad del suelo',
    description:
        'Sensor capacitivo analógico que estima el contenido de agua del suelo mediante una salida de voltaje.',
    variables: [MarketVariable.moisture],
    measurement: 'Humedad del suelo',
    notes: 'Requiere calibración para cada tipo de suelo.',
    priceMinor: 3700,
    currency: MarketCurrency.pen,
    availabilityReference: 'El archivo indica últimas unidades en Perú.',
  ),
  MarketProduct(
    id: 'ds18b20',
    name: 'DS18B20',
    subtitle: 'Temperatura del suelo',
    description:
        'Termómetro digital con protocolo 1-Wire y sonda impermeable para condiciones subterráneas.',
    variables: [MarketVariable.temperature],
    measurement: 'Temperatura del suelo',
    notes: 'Sonda impermeable; comunicación digital 1-Wire.',
    priceMinor: 2000,
    currency: MarketCurrency.pen,
    availabilityReference: 'El archivo indica disponibilidad en Perú.',
  ),
  MarketProduct(
    id: 'sht31',
    name: 'SHT31',
    subtitle: 'Ambiente de tu cultivo',
    description:
        'Sensor ambiental digital de alta precisión con interfaz I²C para temperatura y humedad relativa del aire.',
    variables: [MarketVariable.temperature, MarketVariable.moisture],
    measurement: 'Temperatura y humedad relativa del aire',
    notes:
        'Necesita protección contra radiación solar directa, lluvia y condensación.',
    priceMinor: 3000,
    currency: MarketCurrency.pen,
    availabilityReference: 'El archivo indica disponibilidad en Perú.',
  ),
  MarketProduct(
    id: 'sen0161-v2',
    name: 'SEN0161-V2',
    subtitle: 'pH en suspensión suelo-agua',
    description:
        'Electrodo electroquímico analógico que mide acidez o alcalinidad en mezclas líquidas.',
    variables: [MarketVariable.ph],
    measurement: 'pH de suspensión suelo-agua',
    notes:
        'No mide en suelo seco. Requiere extracción suelo-agua y calibración.',
    priceMinor: 25000,
    currency: MarketCurrency.pen,
    availabilityReference: 'El archivo indica disponibilidad en Perú.',
  ),
  MarketProduct(
    id: 'dfr0300',
    name: 'DFR0300 (K=1)',
    subtitle: 'Conductividad eléctrica',
    description:
        'Sonda analógica de conductividad para evaluar soluciones acuosas extraídas del terreno.',
    variables: [MarketVariable.conductivity],
    measurement: 'Conductividad eléctrica del extracto acuoso del suelo',
    notes:
        'La medición se realiza en una solución acuosa, no directamente en suelo seco. Los costos de importación y envío no están incluidos.',
    priceMinor: 6990,
    currency: MarketCurrency.usd,
    availabilityReference: 'El archivo lo ofrece por importación a Perú.',
    imported: true,
  ),
  MarketProduct(
    id: 'sen0604',
    name: 'SEN0604 (4 en 1)',
    subtitle: 'Una sonda, cuatro variables',
    description:
        'Sonda industrial multiparámetro RS485/Modbus con alimentación de 5 a 30 V.',
    variables: [
      MarketVariable.moisture,
      MarketVariable.temperature,
      MarketVariable.ph,
      MarketVariable.conductivity,
    ],
    measurement: 'Humedad, temperatura, pH y conductividad eléctrica del suelo',
    notes:
        'La oferta de esta demo corresponde a importación. El archivo indica que la alternativa local de S/390 está agotada. Importación y envío no incluidos.',
    priceMinor: 6900,
    currency: MarketCurrency.usd,
    availabilityReference:
        'Importación según el archivo. Alternativa local agotada.',
    imported: true,
    unavailableLocalPriceMinor: 39000,
  ),
];

class MarketCart {
  final Map<String, int> _quantities = {};

  Map<String, int> get quantities => Map.unmodifiable(_quantities);
  int get itemCount => _quantities.values.fold(0, (sum, count) => sum + count);
  bool get isEmpty => _quantities.isEmpty;

  int quantityOf(MarketProduct product) => _quantities[product.id] ?? 0;

  void add(MarketProduct product) =>
      setQuantity(product, quantityOf(product) + 1);

  void setQuantity(MarketProduct product, int quantity) {
    if (quantity <= 0) {
      _quantities.remove(product.id);
    } else {
      _quantities[product.id] = quantity.clamp(1, 99);
    }
  }

  void clear() => _quantities.clear();

  Map<MarketCurrency, int> get totals {
    final result = <MarketCurrency, int>{};
    for (final product in marketCatalog) {
      final quantity = quantityOf(product);
      if (quantity > 0) {
        result.update(
          product.currency,
          (amount) => amount + product.priceMinor * quantity,
          ifAbsent: () => product.priceMinor * quantity,
        );
      }
    }
    return Map.unmodifiable(result);
  }
}
