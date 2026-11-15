import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/crop_simulation.dart';
import '../data/models.dart';
import '../data/simulation_report.dart';
import '../data/terra_store.dart';
import 'smart_cycle_results_screen.dart';
import 'campaign_screen.dart';

export 'smart_cycle_results_screen.dart' show SmartCycleResultsScreen;

class SmartCycleScreen extends StatefulWidget {
  const SmartCycleScreen({super.key, this.onOpenMarket});
  final VoidCallback? onOpenMarket;
  @override
  State<SmartCycleScreen> createState() => _SmartCycleScreenState();
}

class _SmartCycleScreenState extends State<SmartCycleScreen> {
  Set<String>? selection;
  String? editingId;
  final drafts = <String, Parcel>{};
  final harvestDays = <String, int>{};
  Set<SimulationEvent> events = {SimulationEvent.drought};
  double intensity = .5;
  int days = 30;
  bool showingResults = false;

  Future<void> _showResults(List<Parcel> parcels) async {
    if (showingResults || parcels.isEmpty) return;
    final scenarios = [
      for (final source in parcels)
        SimulationScenario(
          source: source,
          input: SimulationInput(
            parcel: (drafts[source.id] ?? source).copyWith(
              clearSoilAnalysis: true,
            ),
            events: events,
            intensity: intensity,
            days: days,
            daysToHarvest: harvestDays[source.id] ?? 15,
          ),
        ),
    ];
    setState(() => showingResults = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SmartCycleResultsScreen(scenarios: scenarios),
        ),
      );
    } finally {
      if (mounted) setState(() => showingResults = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcels = context.watch<TerraStore>().parcels;
    final ids = selection ?? {if (parcels.isNotEmpty) parcels.first.id};
    final chosen = parcels.where((parcel) => ids.contains(parcel.id)).toList();
    final editing =
        chosen.where((p) => p.id == editingId).firstOrNull ??
        chosen.firstOrNull;
    final current = editing == null ? null : drafts[editing.id] ?? editing;
    final allSelected = parcels.isNotEmpty && chosen.length == parcels.length;
    return Column(
      children: [
        const PageIntro(
          eyebrow: 'Explora antes de decidir',
          title: 'Smart-Cycle',
          subtitle: 'Simula escenarios y planifica tus cuidados',
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey('smart-cycle-scroll'),
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 25),
            children: [
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planifica tu próxima campaña',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Compara cultivos, fechas, suelo y clima histórico de La Joya con criterios explicables.',
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: const Key('cycle-plan-campaign'),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              CampaignScreen(onOpenMarket: widget.onOpenMarket),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Planificar campaña'),
                    ),
                    const Text(
                      'El simulador de eventos y sus informes siguen disponibles debajo.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                color: context.colors.softBlue,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.insights_rounded, color: context.colors.blue),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Compara tus parcelas y guarda sus resultados y cuidados en un informe PDF.',
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (parcels.isEmpty)
                const SurfaceCard(
                  child: Text(
                    'Crea una parcela en MAPA para comenzar la simulación.',
                  ),
                )
              else ...[
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Elige tus parcelas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Puedes elegir una, varias o todas.',
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 12,
                        ),
                      ),
                      CheckboxListTile(
                        key: const Key('cycle-select-all'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Todas las parcelas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${chosen.length} de ${parcels.length} seleccionadas',
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: allSelected
                            ? true
                            : chosen.isEmpty
                            ? false
                            : null,
                        tristate: true,
                        onChanged: (_) => setState(
                          () => selection = allSelected
                              ? <String>{}
                              : parcels.map((p) => p.id).toSet(),
                        ),
                      ),
                      Divider(color: context.colors.border),
                      for (final parcel in parcels)
                        CheckboxListTile(
                          key: ValueKey('cycle-select-${parcel.id}'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            parcel.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${parcel.crop} · ${parcel.soilAnalysis == null ? 'Datos de ejemplo' : 'Análisis ingresado'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.muted,
                            ),
                          ),
                          value: ids.contains(parcel.id),
                          onChanged: (checked) => setState(() {
                            selection = {...ids};
                            if (checked == true) {
                              selection!.add(parcel.id);
                            } else {
                              selection!.remove(parcel.id);
                            }
                          }),
                        ),
                      if (chosen.isEmpty)
                        Text(
                          'Selecciona al menos una parcela.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.blue,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. Define el escenario',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Los eventos se aplican a las parcelas elegidas.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.muted,
                        ),
                      ),
                      const SizedBox(height: 14),
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
                    ],
                  ),
                ),
                if (current != null) ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '3. Ajusta cada parcela',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'La fecha de cosecha y las condiciones pueden ser distintas en cada parcela.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.muted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          key: ValueKey('cycle-parcel-${editing!.id}'),
                          initialValue: editing.id,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ajustar parcela',
                          ),
                          items: [
                            for (final p in chosen)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  '${p.name} · ${p.crop}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) => setState(() => editingId = id),
                        ),
                        _control(
                          'Días que faltan para cosechar',
                          '${harvestDays[current.id] ?? 15} días',
                          (harvestDays[current.id] ?? 15).toDouble(),
                          0,
                          60,
                          (v) => setState(
                            () => harvestDays[current.id] = v.round(),
                          ),
                          key: 'cycle-harvest',
                        ),
                        Text(
                          'Usa 0 si este cultivo ya está listo para cosechar.',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 11,
                          ),
                        ),
                        ExpansionTile(
                          key: const PageStorageKey('cycle-initial-conditions'),
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'Condiciones a simular',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Solo cambian este escenario',
                            style: TextStyle(fontSize: 11),
                          ),
                          children: [
                            _control(
                              'pH del suelo',
                              current.ph.toStringAsFixed(1),
                              current.ph,
                              3,
                              9,
                              (v) => setState(
                                () => drafts[current.id] = current.copyWith(
                                  ph: v,
                                ),
                              ),
                              key: 'cycle-ph',
                            ),
                            _control(
                              'Humedad',
                              '${current.moisture.round()}/100',
                              current.moisture,
                              0,
                              100,
                              (v) => setState(
                                () => drafts[current.id] = current.copyWith(
                                  moisture: v,
                                ),
                              ),
                              key: 'cycle-moisture',
                            ),
                            _control(
                              'Nitrógeno',
                              '${current.nitrogen.round()}/100',
                              current.nitrogen,
                              0,
                              100,
                              (v) => setState(
                                () => drafts[current.id] = current.copyWith(
                                  nitrogen: v,
                                ),
                              ),
                              key: 'cycle-nitrogen',
                            ),
                            _control(
                              'Fósforo',
                              '${current.phosphorus.round()}/100',
                              current.phosphorus,
                              0,
                              100,
                              (v) => setState(
                                () => drafts[current.id] = current.copyWith(
                                  phosphorus: v,
                                ),
                              ),
                              key: 'cycle-phosphorus',
                            ),
                            _control(
                              'Potasio',
                              '${current.potassium.round()}/100',
                              current.potassium,
                              0,
                              100,
                              (v) => setState(
                                () => drafts[current.id] = current.copyWith(
                                  potassium: v,
                                ),
                              ),
                              key: 'cycle-potassium',
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => drafts.remove(current.id)),
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Restablecer condiciones'),
                            ),
                          ],
                        ),
                        Text(
                          'Los cuidados usan los datos registrados en Cultivos. Estos ajustes solo cambian la simulación.',
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  SimulationReport.notice,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.muted,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (parcels.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('cycle-show-results'),
                  onPressed: showingResults || chosen.isEmpty
                      ? null
                      : () => _showResults(chosen),
                  icon: const Icon(Icons.analytics_outlined),
                  label: Text(
                    chosen.length > 1
                        ? 'Ver resultados (${chosen.length})'
                        : 'Ver el resultado',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

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
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.colors.blue,
              ),
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
