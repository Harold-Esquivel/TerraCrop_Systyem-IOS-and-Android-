import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/growing_loading_view.dart';
import '../app/ui.dart';
import '../data/agronomy_catalog.dart';
import '../data/crop_simulation.dart';
import '../data/simulation_pdf.dart';
import '../data/simulation_report.dart';

class SmartCycleResultsScreen extends StatefulWidget {
  SmartCycleResultsScreen({
    super.key,
    required List<SimulationScenario> scenarios,
    this.saveReport = saveSimulationReport,
  }) : scenarios = List.unmodifiable(scenarios);
  final List<SimulationScenario> scenarios;
  final SaveSimulationReport saveReport;
  SimulationInput get input => scenarios.first.input;

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
  SimulationReport? report;
  Object? error;
  bool saving = false;
  bool saved = false;
  String? saveMessage;
  bool saveFailed = false;
  final expandedCare = <String>{};

  @override
  void initState() {
    super.initState();
    growth.forward();
    finishTimer = Timer(loadingDuration, () async {
      try {
        final catalog = await AgronomyCatalog.load();
        if (!mounted) return;
        final next = SimulationReport.generate(
          scenarios: widget.scenarios,
          catalog: catalog,
        );
        setState(() => report = next);
      } catch (failure) {
        if (mounted) setState(() => error = failure);
      }
    });
  }

  @override
  void dispose() {
    finishTimer?.cancel();
    growth.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = report;
    if (current == null || saving) return;
    setState(() {
      saving = true;
      saved = false;
      saveMessage = null;
      saveFailed = false;
    });
    try {
      final completed = await widget.saveReport(current);
      if (!mounted) return;
      setState(() {
        saved = completed;
        saveMessage = completed
            ? 'Informe PDF guardado en la ubicación elegida.'
            : 'Guardado cancelado.';
      });
    } catch (failure) {
      debugPrint('No se pudo guardar el informe: $failure');
      if (mounted) {
        setState(() {
          saveFailed = true;
          saveMessage = 'No se pudo guardar el informe. Vuelve a intentarlo.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          report == null && error == null
              ? 'Generando resultado'
              : 'Informe de Smart-Cycle',
        ),
      ),
      body: report == null && error == null
          ? AnimatedBuilder(
              animation: growth,
              builder: (context, _) => GrowingLoadingView(
                key: const Key('cycle-loading'),
                progress: growth.value,
                messages: const [
                  'Preparando tus parcelas...',
                  'Revisando los eventos elegidos...',
                  'Organizando los resultados y cuidados...',
                  'Tu informe está listo.',
                ],
                subtitle: 'Generando el informe de Smart-Cycle',
              ),
            )
          : error != null || report == null
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
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      key: const PageStorageKey('cycle-results-scroll'),
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                      children: [
                        SurfaceCard(
                          color: context.colors.softBlue,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${report.parcels.length} ${report.parcels.length == 1 ? 'parcela simulada' : 'parcelas simuladas'}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                report.parcels.first.eventsLabel,
                                key: const Key('cycle-result-events'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                SimulationReport.notice,
                                style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 11,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        for (final parcel in report.parcels) ...[
                          _parcelResult(
                            parcel,
                            single: report.parcels.length == 1,
                          ),
                          const SizedBox(height: 18),
                        ],
                        OutlinedButton.icon(
                          key: const Key('cycle-edit-scenario'),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.tune),
                          label: const Text('Cambiar escenario'),
                        ),
                      ],
                    ),
                  ),
                  if (saveMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 4,
                      ),
                      child: Text(
                        saveMessage!,
                        key: saved
                            ? const Key('cycle-save-success')
                            : const Key('cycle-save-message'),
                        style: TextStyle(
                          color: saveFailed
                              ? Theme.of(context).colorScheme.error
                              : context.colors.green,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('cycle-save-report'),
                        onPressed: saving ? null : _save,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(
                          saving
                              ? 'Guardando informe...'
                              : 'Guardar informe PDF',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _parcelResult(ParcelSimulationReport parcel, {required bool single}) {
    final id = parcel.scenario.source.id;
    final input = parcel.scenario.input;
    final result = parcel.result;
    final currentCare = expandedCare.contains(id)
        ? parcel.currentCare
        : parcel.currentCare.take(3);
    return SurfaceCard(
      key: ValueKey('cycle-result-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${parcel.scenario.source.name} · ${parcel.scenario.source.crop}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 5),
          Text(
            parcel.dataLabel,
            style: TextStyle(color: context.colors.muted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Text(
            'Intensidad: ${(input.intensity * 100).round()}% · Horizonte: ${input.days} días · Cosecha prevista: día ${input.daysToHarvest}',
            key: single
                ? const Key('cycle-result-settings')
                : ValueKey('cycle-result-settings-$id'),
            style: TextStyle(
              color: context.colors.muted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metric(
                  'Condición simulada',
                  '${result.finalHealth.round()}/100',
                  (constraints.maxWidth - 8) / 2,
                  context.colors.blue,
                ),
                _metric(
                  'Merma simulada',
                  '${result.finalLossPercent.toStringAsFixed(1)}%',
                  (constraints.maxWidth - 8) / 2,
                  context.colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'Planifica la cosecha',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            parcel.harvestAdvice,
            key: single
                ? const Key('cycle-window-result')
                : ValueKey('cycle-window-result-$id'),
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 19),
          Text(
            'Qué hacer en esta parcela',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 9),
          if (parcel.currentCare.isEmpty)
            Text(
              parcel.needsSoilData
                  ? 'Completa el análisis de suelo para precisar los aportes de agua y nutrientes.'
                  : 'Mantén el monitoreo de humedad y nutrientes.',
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          for (final action in currentCare)
            _advice(
              action.title,
              action.instruction,
              key: ValueKey('cycle-care-$id-${action.id}'),
            ),
          if (parcel.currentCare.length > 3)
            TextButton.icon(
              key: ValueKey('cycle-more-care-$id'),
              onPressed: () => setState(
                () => expandedCare.contains(id)
                    ? expandedCare.remove(id)
                    : expandedCare.add(id),
              ),
              icon: Icon(
                expandedCare.contains(id)
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                expandedCare.contains(id)
                    ? 'Ver solo lo prioritario'
                    : 'Ver ${parcel.currentCare.length - 3} cuidados más',
              ),
            ),
          if (parcel.needsSoilData && parcel.currentCare.isNotEmpty)
            Text(
              'Completa el análisis de suelo para afinar estos cuidados.',
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          if (parcel.scenarioCare.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              'Si ocurre el escenario',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 9),
            for (final action in parcel.scenarioCare)
              _advice(
                action.title,
                action.action,
                scenario: true,
                key: ValueKey('cycle-scenario-care-$id-${action.id}'),
              ),
          ],
          const SizedBox(height: 10),
          ExpansionTile(
            key: PageStorageKey('cycle-evolution-$id'),
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: single,
            title: const Text(
              'Ver evolución y estadísticas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            children: [
              Text(
                'Evolución de la condición',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  painter: _CycleChart(
                    result.points,
                    result.basePoints,
                    context.colors,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Día 0',
                    style: TextStyle(fontSize: 10, color: context.colors.muted),
                  ),
                  Text(
                    'Día ${input.days}',
                    style: TextStyle(fontSize: 10, color: context.colors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _Legend(color: context.colors.blue, text: 'Con eventos'),
                  _Legend(color: context.colors.green, text: 'Sin eventos'),
                ],
              ),
              const SizedBox(height: 18),
              _dailyTable(result),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, double width, Color color) =>
      Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.canvas,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: context.colors.muted, fontSize: 10),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Widget _advice(
    String title,
    String action, {
    bool scenario = false,
    Key? key,
  }) => Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: scenario ? context.colors.softBlue : context.colors.softGreen,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              scenario ? Icons.cloud_outlined : Icons.eco_outlined,
              size: 18,
              color: scenario ? context.colors.blue : context.colors.green,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(action, style: const TextStyle(fontSize: 12, height: 1.45)),
      ],
    ),
  );

  Widget _dailyTable(SimulationResult result) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Estadística por día',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 0,
          columns: const [
            DataColumn(label: Text('Día')),
            DataColumn(label: Text('Humedad /100')),
            DataColumn(label: Text('Condición /100')),
            DataColumn(label: Text('Merma simulada')),
          ],
          rows: [
            for (final point in result.points.where(
              (p) => p.day == 0 || p.day % 7 == 0 || p.day == result.input.days,
            ))
              DataRow(
                cells: [
                  DataCell(Text('${point.day}')),
                  DataCell(Text('${point.moisture.round()}')),
                  DataCell(Text('${point.health.round()}')),
                  DataCell(Text('${point.lossPercent.toStringAsFixed(1)}%')),
                ],
              ),
          ],
        ),
      ),
    ],
  );
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
  const _CycleChart(this.scenario, this.reference, this.colors);
  final AppColors colors;
  final List<SimulationPoint> scenario;
  final List<SimulationPoint> reference;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(30, 8, size.width - 36, size.height - 18);
    final grid = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    for (final tick in [0, 20, 40, 60, 80, 100]) {
      final y = area.bottom - area.height * tick / 100;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
      final text = TextPainter(
        text: TextSpan(
          text: '$tick',
          style: TextStyle(color: colors.muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, y - 6));
    }
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

    line(reference, colors.green);
    line(scenario, colors.blue);
  }

  @override
  bool shouldRepaint(covariant _CycleChart oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.scenario != scenario ||
      oldDelegate.reference != reference;
}
