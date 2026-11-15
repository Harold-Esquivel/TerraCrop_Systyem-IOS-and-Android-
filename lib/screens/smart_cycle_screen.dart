import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/growing_loading_view.dart';
import '../app/ui.dart';
import '../data/crop_simulation.dart';
import '../data/agronomy_catalog.dart';
import '../data/models.dart';
import '../data/terra_store.dart';

class SmartCycleScreen extends StatefulWidget {
  const SmartCycleScreen({super.key});

  @override
  State<SmartCycleScreen> createState() => _SmartCycleScreenState();
}

class _SmartCycleScreenState extends State<SmartCycleScreen> {
  String? selectedId;
  Parcel? draft;
  Set<SimulationEvent> events = {SimulationEvent.drought};
  double intensity = .5;
  int days = 30;
  int daysToHarvest = 15;
  bool showingResults = false;

  Future<void> _showResults(Parcel parcel) async {
    if (showingResults) return;
    final input = SimulationInput(
      parcel: parcel.copyWith(clearSoilAnalysis: true),
      events: events,
      intensity: intensity,
      days: days,
      daysToHarvest: daysToHarvest,
    );
    setState(() => showingResults = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SmartCycleResultsScreen(input: input),
        ),
      );
    } finally {
      if (mounted) setState(() => showingResults = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcels = context.watch<TerraStore>().parcels;
    final selected =
        parcels.where((p) => p.id == selectedId).firstOrNull ??
        parcels.firstOrNull;
    final current = draft?.id == selected?.id ? draft : selected;
    final reference = current == null
        ? null
        : AgronomyCatalog.current?.findCrop(current.crop);
    return Column(
      children: [
        const PageIntro(
          eyebrow: 'Explora antes de decidir',
          title: 'Smart-Cycle',
          subtitle: 'Simula el clima, las labores y el paso del tiempo',
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey('smart-cycle-scroll'),
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 25),
            children: [
              const SurfaceCard(
                color: paleBlue,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.science_outlined, color: blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Simulación de demostración. Las cifras son orientativas y no garantizan una fecha segura de cosecha. Tus parcelas conservan sus datos originales.',
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (selected == null || current == null)
                const SurfaceCard(
                  child: Text(
                    'Crea una parcela en MAPA para comenzar la simulación.',
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('cycle-parcel-${selected.id}'),
                  initialValue: selected.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Parcela y cultivo',
                  ),
                  items: [
                    for (final p in parcels)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.name} · ${p.crop}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    selectedId = id;
                    draft = null;
                  }),
                ),
                const SizedBox(height: 18),
                if (reference != null) ...[
                  _referenceProfile(reference),
                  const SizedBox(height: 14),
                ],
                if (current.soilAnalysis != null) ...[
                  const SurfaceCard(
                    child: Text(
                      'Los análisis de suelo se interpretan en Cultivos. Este simulador utiliza índices de demostración independientes; no transforma las necesidades en kg/ha de la ficha en lecturas de sensores.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Define el escenario',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Eventos climáticos',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _eventChips(climate: true),
                      const SizedBox(height: 14),
                      const Text(
                        'Eventos agrícolas',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _eventChips(climate: false),
                      const SizedBox(height: 12),
                      const Text(
                        'Puedes combinar eventos. Se aplican cada día con una intensidad constante.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      _control(
                        'Intensidad de los eventos',
                        '${(intensity * 100).round()}%',
                        intensity,
                        0,
                        1,
                        (v) => setState(() => intensity = v),
                        key: 'cycle-intensity',
                      ),
                      _control(
                        'Días a simular',
                        '$days días',
                        days.toDouble(),
                        1,
                        60,
                        (v) => setState(() => days = v.round()),
                        key: 'cycle-days',
                      ),
                      _control(
                        'Días que faltan para cosechar',
                        '$daysToHarvest días',
                        daysToHarvest.toDouble(),
                        0,
                        60,
                        (v) => setState(() => daysToHarvest = v.round()),
                        key: 'cycle-harvest',
                      ),
                      const Text(
                        'Este plazo lo defines tú: usa 0 si el cultivo ya está listo para cosechar.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SurfaceCard(
                  child: ExpansionTile(
                    key: const PageStorageKey('cycle-initial-conditions'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 8),
                    title: const Text(
                      'Condiciones iniciales',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Ajustes exclusivos de esta simulación',
                    ),
                    children: [
                      _control(
                        'pH del suelo',
                        current.ph.toStringAsFixed(1),
                        current.ph,
                        3,
                        9,
                        (v) => setState(() => draft = current.copyWith(ph: v)),
                      ),
                      _control(
                        'Humedad',
                        '${current.moisture.round()}%',
                        current.moisture,
                        0,
                        100,
                        (v) => setState(
                          () => draft = current.copyWith(moisture: v),
                        ),
                      ),
                      _control(
                        'Nitrógeno',
                        '${current.nitrogen.round()}%',
                        current.nitrogen,
                        0,
                        100,
                        (v) => setState(
                          () => draft = current.copyWith(nitrogen: v),
                        ),
                      ),
                      _control(
                        'Fósforo',
                        '${current.phosphorus.round()}%',
                        current.phosphorus,
                        0,
                        100,
                        (v) => setState(
                          () => draft = current.copyWith(phosphorus: v),
                        ),
                      ),
                      _control(
                        'Potasio',
                        '${current.potassium.round()}%',
                        current.potassium,
                        0,
                        100,
                        (v) => setState(
                          () => draft = current.copyWith(potassium: v),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => draft = null),
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Recuperar datos de la parcela'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('cycle-show-results'),
                onPressed: showingResults ? null : () => _showResults(current),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Ver el resultado'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _referenceProfile(CropProfile profile) => SurfaceCard(
    child: ExpansionTile(
      key: PageStorageKey('cycle-workbook-${profile.id}'),
      tilePadding: EdgeInsets.zero,
      title: const Text('Referencia del Excel'),
      subtitle: Text('${profile.name} · ${profile.classification}'),
      children: [
        Text(
          'Base regional: La Joya, Arequipa. pH ${profile.phMin}–${profile.phMax}.',
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          profile.periodMin == null || profile.periodMax == null
              ? 'No se define un ciclo por campaña para este cultivo perenne; el plazo hasta el siguiente corte debe indicarse localmente.'
              : 'Ciclo completo de referencia: ${profile.periodMin!.round()}–${profile.periodMax!.round()} días. El horizonte del simulador es de hasta 60 días desde el estado actual.',
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Demanda del cultivo: ${profile.waterMin}–${profile.waterMax} ${profile.waterUnit}. No equivale al riego aplicado ni a un ahorro garantizado.',
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          profile.validation,
          style: const TextStyle(fontSize: 11, color: muted, height: 1.5),
        ),
      ],
    ),
  );

  Widget _eventChips({required bool climate}) => Wrap(
    spacing: 7,
    runSpacing: 5,
    children: [
      for (final event in SimulationEvent.values.where(
        (e) => e.isClimate == climate,
      ))
        FilterChip(
          key: ValueKey('cycle-event-${event.name}'),
          label: Text(event.label),
          selected: events.contains(event),
          onSelected: (selected) => setState(() {
            events = {...events};
            if (selected) {
              events.add(event);
            } else {
              events.remove(event);
            }
          }),
        ),
    ],
  );

  Widget _control(
    String label,
    String value,
    double current,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String? key,
  }) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, color: blue),
            ),
          ],
        ),
        Slider(
          key: key == null ? null : ValueKey(key),
          value: current.clamp(min, max),
          min: min,
          max: max,
          divisions: max == 1
              ? 10
              : (max - min).round() * (label == 'pH del suelo' ? 10 : 1),
          label: value,
          semanticFormatterCallback: (_) => '$label: $value',
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

/// One immutable scenario, captured when the user requests its result.
class SmartCycleResultsScreen extends StatefulWidget {
  const SmartCycleResultsScreen({super.key, required this.input});
  final SimulationInput input;

  @override
  State<SmartCycleResultsScreen> createState() =>
      _SmartCycleResultsScreenState();
}

class _SmartCycleResultsScreenState extends State<SmartCycleResultsScreen>
    with SingleTickerProviderStateMixin {
  static const loadingDuration = Duration(seconds: 3);
  late final AnimationController growth = AnimationController(
    vsync: this,
    duration: loadingDuration,
  );
  Timer? finishTimer;
  SimulationResult? result;
  Object? error;
  int get days => widget.input.days;
  int get daysToHarvest => widget.input.daysToHarvest;

  @override
  void initState() {
    super.initState();
    growth.forward();
    finishTimer = Timer(loadingDuration, () {
      if (!mounted) return;
      try {
        final next = CropSimulation.run(widget.input);
        setState(() => result = next);
      } catch (failure) {
        setState(() => error = failure);
      }
    });
  }

  @override
  void dispose() {
    finishTimer?.cancel();
    growth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          result == null && error == null
              ? 'Generando resultado'
              : 'Resultado de Smart-Cycle',
        ),
      ),
      body: result == null && error == null
          ? AnimatedBuilder(
              animation: growth,
              builder: (context, _) => GrowingLoadingView(
                key: const Key('cycle-loading'),
                progress: growth.value,
                messages: const [
                  'Preparando tu simulación...',
                  'Analizando los eventos elegidos...',
                  'Comparando la evolución de tu cultivo...',
                  'Tu resultado está listo.',
                ],
                subtitle: 'Generando el resultado de Smart-Cycle',
              ),
            )
          : error != null || result == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No se pudo generar la simulación. Revisa las condiciones e inténtalo de nuevo.',
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Volver al escenario'),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              top: false,
              child: ListView(
                key: const PageStorageKey('cycle-results-scroll'),
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 25),
                children: [
                  SurfaceCard(
                    color: paleBlue,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.input.parcel.name} · ${widget.input.parcel.crop}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.input.events.isEmpty
                              ? 'Sin eventos adicionales'
                              : widget.input.events
                                    .map((event) => event.label)
                                    .join(' · '),
                          key: const Key('cycle-result-events'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Intensidad: ${(widget.input.intensity * 100).round()}% · Horizonte: $days días · Cosecha prevista: día $daysToHarvest',
                          key: const Key('cycle-result-settings'),
                          style: const TextStyle(fontSize: 12, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Estimación de demostración; no garantiza un plazo seguro de cosecha.',
                          style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '2. Compara los resultados',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Referencia: mismas condiciones iniciales, sin los eventos seleccionados.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 12),
                  _windowCard(result),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _metric(
                        'Condición final',
                        '${result.finalHealth.toStringAsFixed(0)}/100',
                        '${result.conditionDifference >= 0 ? '+' : ''}${result.conditionDifference.toStringAsFixed(1)} puntos vs. referencia',
                        blue,
                      ),
                      _metric(
                        'Merma potencial',
                        '${result.finalLossPercent.toStringAsFixed(1)}%',
                        '${result.lossDifference >= 0 ? '+' : ''}${result.lossDifference.toStringAsFixed(1)} puntos porcentuales',
                        Colors.deepOrange,
                      ),
                      _metric(
                        'Humedad media',
                        '${result.averageMoisture.toStringAsFixed(1)}%',
                        'Durante los $days días simulados',
                        green,
                      ),
                      _metric(
                        'Días extra simulados',
                        '${result.additionalDaysInParcel}',
                        'Después de la cosecha prevista',
                        blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evolución de la condición',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Índice del modelo: 100 es la mejor condición',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                        const SizedBox(height: 14),
                        Semantics(
                          label:
                              'Condición del cultivo: escenario ${result.finalHealth.round()} de 100; referencia ${result.baselineFinalHealth.round()} de 100 al día $days.',
                          child: SizedBox(
                            height: 190,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _CycleChart(
                                result.points,
                                result.basePoints,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Día 0',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                            Text(
                              'Día $days',
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _Legend(color: blue, text: 'Escenario'),
                            _Legend(color: green, text: 'Referencia'),
                            _Legend(
                              color: Colors.deepOrange,
                              text: 'Umbral de condición 60',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _dailyTable(result),
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: ExpansionTile(
                      key: const PageStorageKey('cycle-calculation-notes'),
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Cómo se calcula'),
                      children: [
                        const Text(
                          CropSimulation.methodology,
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          result.summary,
                          style: const TextStyle(fontSize: 12, height: 1.5),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Merma potencial es un indicador ficticio del escenario, no una predicción de producción. La ausencia de un umbral en el horizonte simulado no garantiza que el cultivo pueda permanecer ese tiempo en la parcela.',
                          style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    key: const Key('cycle-edit-scenario'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.tune),
                    label: const Text('Cambiar escenario'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _windowCard(SimulationResult result) {
    final riskDay = result.firstRiskDay;
    final extra = riskDay == null ? null : riskDay - daysToHarvest - 1;
    final String message;
    if (riskDay == 0) {
      message =
          'El cultivo ya supera el umbral de deterioro del modelo al inicio.';
    } else if (riskDay != null && riskDay <= daysToHarvest) {
      message =
          'El umbral aparece el día $riskDay, antes o al llegar a la cosecha prevista. El modelo no ofrece margen adicional.';
    } else if (extra != null) {
      message =
          'El umbral aparece el día $riskDay: se proyectan $extra días completos adicionales después de la cosecha prevista antes de alcanzarlo.';
    } else if (days < daysToHarvest) {
      message =
          'El horizonte termina antes de la cosecha prevista. Amplía los días a simular para evaluar la permanencia adicional.';
    } else {
      message =
          'No se alcanza el umbral en $days días, incluidos ${result.additionalDaysInParcel} después de la cosecha prevista. No se estima el comportamiento fuera de este horizonte.';
    }
    return SurfaceCard(
      color: riskDay == null ? paleBlue : const Color(0xFFFFF2E9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Cuánto tiempo más en la parcela?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            key: const Key('cycle-window-result'),
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Umbral: condición menor de 60/100 o merma potencial de al menos 15%. Es un criterio de demostración, no un plazo seguro.',
            style: TextStyle(fontSize: 11, color: muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, String detail, Color color) =>
      LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth > 340
              ? (constraints.maxWidth - 10) / 2
              : constraints.maxWidth,
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(detail, style: const TextStyle(fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ),
      );

  Widget _dailyTable(SimulationResult result) {
    final rows = result.points
        .where(
          (p) =>
              p.day == 0 ||
              p.day % 7 == 0 ||
              p.day == days ||
              p.day == daysToHarvest ||
              p.day == result.firstRiskDay,
        )
        .toList();
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadística por día',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 18,
              horizontalMargin: 0,
              columns: const [
                DataColumn(label: Text('Día')),
                DataColumn(label: Text('Humedad')),
                DataColumn(label: Text('Condición')),
                DataColumn(label: Text('Merma')),
              ],
              rows: [
                for (final point in rows)
                  DataRow(
                    cells: [
                      DataCell(Text('${point.day}')),
                      DataCell(Text('${point.moisture.toStringAsFixed(0)}%')),
                      DataCell(Text('${point.health.toStringAsFixed(0)}/100')),
                      DataCell(
                        Text('${point.lossPercent.toStringAsFixed(1)}%'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Flexible(child: Text(text, style: const TextStyle(fontSize: 11))),
    ],
  );
}

class _CycleChart extends CustomPainter {
  const _CycleChart(this.scenario, this.reference);
  final List<SimulationPoint> scenario;
  final List<SimulationPoint> reference;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(30, 8, size.width - 36, size.height - 18);
    final grid = Paint()
      ..color = border
      ..strokeWidth = 1;
    for (final tick in [0, 20, 40, 60, 80, 100]) {
      final y = area.bottom - area.height * tick / 100;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
      final text = TextPainter(
        text: TextSpan(
          text: '$tick',
          style: const TextStyle(color: muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, y - 6));
    }
    canvas.drawLine(
      Offset(area.left, area.bottom - area.height * .6),
      Offset(area.right, area.bottom - area.height * .6),
      Paint()
        ..color = Colors.deepOrange.withValues(alpha: .45)
        ..strokeWidth = 1,
    );
    void line(List<SimulationPoint> points, Color color) {
      if (points.isEmpty) return;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        final x =
            area.left +
            area.width * p.day / (points.last.day == 0 ? 1 : points.last.day);
        final y = area.bottom - area.height * p.health / 100;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    line(reference, green);
    line(scenario, blue);
  }

  @override
  bool shouldRepaint(covariant _CycleChart oldDelegate) =>
      oldDelegate.scenario != scenario || oldDelegate.reference != reference;
}
