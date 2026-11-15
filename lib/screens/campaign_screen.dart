import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/agronomy_catalog.dart';
import '../data/campaign_engine.dart';
import '../data/environment_repository.dart';
import '../data/models.dart';
import '../data/terra_store.dart';
import 'soil_analysis_editor.dart';

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key, this.onOpenMarket});
  final VoidCallback? onOpenMarket;
  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  final environment = EnvironmentRepository.load();
  final available = TextEditingController(text: '120');
  final water = TextEditingController();
  String? parcelId, previousId;
  String cropId = 'C008';
  late int month = DateTime.now().month % 12 + 1;
  late int year = DateTime.now().year + (DateTime.now().month == 12 ? 1 : 0);
  bool? irrigation;
  CampaignEvaluation? result;
  List<CampaignEvaluation> alternatives = [];
  List<SequenceEvaluation> sequences = [];
  String? error;
  bool loading = false;

  @override
  void dispose() {
    available.dispose();
    water.dispose();
    super.dispose();
  }

  Future<void> evaluate(EnvironmentRepository repository, Parcel parcel) async {
    final days = int.tryParse(available.text);
    final volume = water.text.trim().isEmpty
        ? null
        : double.tryParse(water.text.replaceAll(',', '.'));
    if (days == null ||
        days < 1 ||
        days > 3660 ||
        (water.text.trim().isNotEmpty &&
            (volume == null || !volume.isFinite || volume < 0)) ||
        (irrigation == false && volume != null && volume > 0)) {
      setState(
        () => error =
            'Revisa el plazo (1–3660 días) y el volumen de agua. Sin riego no puede indicarse un volumen positivo.',
      );
      return;
    }
    final catalog = AgronomyCatalog.current ?? await AgronomyCatalog.load();
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    // Same deliberate 3-second preparation as the existing results flow.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final input = CampaignInput(
      parcel: parcel,
      previousCrop: previousId ?? parcel.crop,
      cropId: cropId,
      start: DateTime.utc(year, month),
      availableDays: days,
      irrigationAvailable: irrigation,
      effectiveIrrigationM3Ha: volume,
    );
    final engine = CampaignEngine(catalog, repository);
    setState(() {
      result = engine.evaluate(input);
      alternatives = engine.alternatives(input);
      sequences = engine.compareSequences(input);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TerraStore>();
    final catalog = AgronomyCatalog.current;
    final parcel =
        store.parcels.where((p) => p.id == parcelId).firstOrNull ??
        store.parcels.firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Planificar campaña')),
      body: catalog == null
          ? const Center(child: Text('Base agronómica no disponible.'))
          : FutureBuilder<EnvironmentRepository>(
              future: environment,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron leer los datos ambientales. ${snapshot.error}',
                      ),
                    ),
                  );
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final repository = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'La Joya · planificación con datos históricos',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Evalúa alternativas sin cambiar el cultivo ni las mediciones de tu parcela. La decisión de siembra es tuya.',
                    ),
                    const SizedBox(height: 16),
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (parcel != null)
                            DropdownButtonFormField<String>(
                              key: ValueKey('campaign-parcel-${parcel.id}'),
                              initialValue: parcel.id,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Parcela',
                              ),
                              items: store.parcels
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: loading
                                  ? null
                                  : (v) => setState(() {
                                      parcelId = v;
                                      previousId = null;
                                      result = null;
                                    }),
                            ),
                          TextButton.icon(
                            key: const Key('campaign-add-pilot'),
                            onPressed: loading
                                ? null
                                : () {
                                    final existing = store.parcels
                                        .where(
                                          (p) => p.name == 'La Joya · ejemplo',
                                        )
                                        .firstOrNull;
                                    if (existing != null) {
                                      setState(() => parcelId = existing.id);
                                      return;
                                    }
                                    store.addParcel(
                                      name: 'La Joya · ejemplo',
                                      crop: 'Maíz',
                                      points: const [
                                        LatLng(-16.7505, -71.8755),
                                        LatLng(-16.7505, -71.8745),
                                        LatLng(-16.7515, -71.8745),
                                        LatLng(-16.7515, -71.8755),
                                      ],
                                    );
                                    setState(() {
                                      parcelId = store.parcels.last.id;
                                      previousId = null;
                                      result = null;
                                    });
                                  },
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Añadir ejemplo de La Joya'),
                          ),
                          const Text(
                            'El ejemplo solo aporta una geometría ficticia en la zona piloto; no contiene análisis ni mediciones reales.',
                            style: TextStyle(fontSize: 11),
                          ),
                          if (parcel != null) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey('campaign-previous-${parcel.id}'),
                              initialValue:
                                  previousId ??
                                  catalog.findCrop(parcel.crop)?.id,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Cultivo anterior',
                              ),
                              items: catalog.crops
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: loading
                                  ? null
                                  : (v) => setState(() {
                                      previousId = v;
                                      result = null;
                                    }),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: const Key('campaign-crop'),
                              initialValue: cropId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Cultivo propuesto',
                              ),
                              items: catalog.crops
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: loading
                                  ? null
                                  : (v) => setState(() {
                                      cropId = v!;
                                      result = null;
                                    }),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Inicio previsto: siembra o trasplante según la ficha. Se evalúa desde el primer día del mes.',
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    key: const Key('campaign-month'),
                                    initialValue: month,
                                    decoration: const InputDecoration(
                                      labelText: 'Mes',
                                    ),
                                    items: List.generate(
                                      12,
                                      (i) => DropdownMenuItem(
                                        value: i + 1,
                                        child: Text('${i + 1}'),
                                      ),
                                    ),
                                    onChanged: loading
                                        ? null
                                        : (v) => setState(() {
                                            month = v!;
                                            result = null;
                                          }),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    key: const Key('campaign-year'),
                                    initialValue: year,
                                    decoration: const InputDecoration(
                                      labelText: 'Año',
                                    ),
                                    items: List.generate(
                                      7,
                                      (i) => DropdownMenuItem(
                                        value: DateTime.now().year + i,
                                        child: Text(
                                          '${DateTime.now().year + i}',
                                        ),
                                      ),
                                    ),
                                    onChanged: loading
                                        ? null
                                        : (v) => setState(() {
                                            year = v!;
                                            result = null;
                                          }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const Key('campaign-days'),
                              controller: available,
                              enabled: !loading,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Tiempo disponible (días)',
                              ),
                              onChanged: (_) => setState(() => result = null),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: 'unknown',
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Disponibilidad de riego',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'unknown',
                                  child: Text('No conocida'),
                                ),
                                DropdownMenuItem(
                                  value: 'yes',
                                  child: Text('Disponible'),
                                ),
                                DropdownMenuItem(
                                  value: 'no',
                                  child: Text('Sin riego'),
                                ),
                              ],
                              onChanged: loading
                                  ? null
                                  : (v) => setState(() {
                                      irrigation = v == 'unknown'
                                          ? null
                                          : v == 'yes';
                                      result = null;
                                    }),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: water,
                              enabled: !loading,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Riego efectivo (m³/ha por campaña)',
                                helperText:
                                    'Opcional; volumen que llega al cultivo',
                                helperMaxLines: 2,
                              ),
                              onChanged: (_) => setState(() => result = null),
                            ),
                            TextButton.icon(
                              onPressed: loading
                                  ? null
                                  : () async {
                                      final edited =
                                          await showModalBottomSheet<
                                            SoilAnalysis
                                          >(
                                            context: context,
                                            isScrollControlled: true,
                                            useSafeArea: true,
                                            builder: (_) => SoilAnalysisEditor(
                                              initial: parcel.soilAnalysis,
                                            ),
                                          );
                                      if (edited != null)
                                        await store.updateParcel(
                                          parcel.copyWith(soilAnalysis: edited),
                                        );
                                      if (mounted)
                                        setState(() => result = null);
                                    },
                              icon: const Icon(Icons.science_outlined),
                              label: const Text('Revisar análisis del suelo'),
                            ),
                            if (error != null)
                              Text(
                                error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const Key('campaign-evaluate'),
                              onPressed: loading
                                  ? null
                                  : () => evaluate(repository, parcel),
                              icon: loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.event_available),
                              label: Text(
                                loading
                                    ? 'Evaluando campaña…'
                                    : 'Evaluar campaña',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 20),
                      CampaignResultCard(
                        evaluation: result!,
                        onMarket: () {
                          store.useCampaignContext(result!);
                          Navigator.of(context).pop();
                          widget.onOpenMarket?.call();
                        },
                      ),
                      const SizedBox(height: 16),
                      SurfaceCard(
                        child: ExpansionTile(
                          title: const Text('Comparar alternativas'),
                          tilePadding: EdgeInsets.zero,
                          children: [
                            for (final e in alternatives)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${e.crop.name} · ${e.crop.periodMin?.round() ?? '—'}–${e.crop.periodMax?.round() ?? '—'} días',
                                ),
                                subtitle: Text(
                                  '${e.category.label}\n${e.water}',
                                ),
                                onTap: () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (_) => DraggableScrollableSheet(
                                    expand: false,
                                    initialChildSize: .85,
                                    builder: (_, controller) =>
                                        SingleChildScrollView(
                                          controller: controller,
                                          padding: const EdgeInsets.all(20),
                                          child: CampaignResultCard(
                                            evaluation: e,
                                            onMarket: () {
                                              store.useCampaignContext(e);
                                              Navigator.of(context).pop();
                                              Navigator.of(context).pop();
                                              widget.onOpenMarket?.call();
                                            },
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SurfaceCard(
                        child: ExpansionTile(
                          title: const Text('Comparar secuencias de rotación'),
                          tilePadding: EdgeInsets.zero,
                          children: [
                            const Text(
                              'Escenarios ilustrativos del archivo. Fechas encadenadas por el ciclo máximo; no representan prácticas observadas ni incluyen descansos/semilleros. Los totales de agua son demanda, no ahorro.',
                            ),
                            for (final s in sequences)
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(s.sequence.sequence),
                                subtitle: Text(
                                  '${s.minimumDays}–${s.maximumDays} días · ${s.waterMin?.round()}–${s.waterMax?.round()} m³/ha',
                                ),
                                children: [
                                  Text(
                                    '${s.sequence.role}\n${s.sequence.benefit}\n${s.sequence.conditions}\n${s.sequence.limitations}',
                                  ),
                                  Text(
                                    'Referencia original: ${s.sequence.totalDays.round()} días y ${s.sequence.totalWater.round()} m³/ha; duraciones diferentes entre escenarios.',
                                  ),
                                  for (final e in s.steps)
                                    ListTile(
                                      title: Text(e.crop.name),
                                      subtitle: Text(
                                        '${e.category.label}\n${e.nutrition}',
                                      ),
                                      onTap: () => showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        builder: (_) =>
                                            DraggableScrollableSheet(
                                              expand: false,
                                              initialChildSize: .85,
                                              builder: (_, controller) =>
                                                  SingleChildScrollView(
                                                    controller: controller,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          20,
                                                        ),
                                                    child: CampaignResultCard(
                                                      evaluation: e,
                                                    ),
                                                  ),
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class CampaignResultCard extends StatelessWidget {
  const CampaignResultCard({
    super.key,
    required this.evaluation,
    this.onMarket,
  });
  final CampaignEvaluation evaluation;
  final VoidCallback? onMarket;
  String date(DateTime? d) =>
      d == null ? 'Sin fecha documentada' : '${d.day}/${d.month}/${d.year}';
  @override
  Widget build(BuildContext context) {
    final e = evaluation;
    return SurfaceCard(
      key: ValueKey('campaign-result-${e.crop.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${e.input.parcel.name} · ${e.crop.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            e.category.label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.colors.blue,
            ),
          ),
          Text(
            'Inicio: ${date(e.input.start)}\nCosecha de referencia: ${date(e.earliestHarvest)} – ${date(e.latestHarvest)}\n${e.crop.periodDescription}',
          ),
          Text(
            'Meses evaluados: ${e.months.map((m) => '${m.month}/${m.year}').join(', ')}',
          ),
          const SizedBox(height: 12),
          Text(
            e.forecastMessage,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Text(EnvironmentRepository.ensoUnavailable),
          Text(e.water),
          Text(e.nutrition),
          for (final advantage in e.advantages)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('• $advantage'),
            ),
          const SizedBox(height: 12),
          const Text(
            'Riesgos, causas y acciones',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final alert in e.alerts)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(alert.title, style: const TextStyle(fontSize: 14)),
              subtitle: Text(alert.explanation),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    [
                      'Parcela: ${alert.parcelName} · Cultivo: ${alert.cropName}',
                      'Atención: ${switch (alert.level) {
                        AttentionLevel.information => 'Información',
                        AttentionLevel.review => 'Revisión',
                        AttentionLevel.restriction => 'Restricción',
                      }}',
                      '${alert.variable}: ${alert.value ?? 'sin valor numérico'} ${alert.unit}',
                      'Criterio: ${alert.criterion}',
                      'Origen: ${alert.origin}',
                      'Fecha del dato: ${alert.date == null ? 'No registrada o serie histórica (ver periodo)' : date(alert.date)}',
                      ...alert.actions,
                      'Verificación: ${alert.verification}',
                      ...alert.missingData,
                      'Referencias: ${alert.references.join(', ')}',
                    ].join('\n'),
                  ),
                ),
              ],
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Datos climáticos y procedencia'),
            children: [
              const Text(
                'Histórico 2015–2024, mínimo 5 años por mes. No es una normal climática de 30 años ni pronóstico. Media y variabilidad interanual; SMAP pondera cada año por igual. Lluvia en meses completos, sin estimar lluvia efectiva ni estrés radicular.',
              ),
              for (final c in e.climate)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Mes ${c.month} · ${c.source.variable}: ${c.mean.toStringAsFixed(3)} ${c.source.unit}',
                  ),
                  subtitle: Text(
                    'Rango de medias anuales ${c.minimum.toStringAsFixed(3)}–${c.maximum.toStringAsFixed(3)}; desviación ${c.standardDeviation.toStringAsFixed(3)}\n${c.years} años, ${c.samples} observaciones, ${c.missing} años sin dato; ${c.period}\n${c.source.product}\n${c.source.spatialResolution}\n${c.source.quality}\n${c.source.file} · SHA-256 ${c.source.sha256}',
                  ),
                ),
              for (final f in e.forecasts)
                Text(
                  '${f.institution} · emisión ${date(f.issuedAt)} · validez ${date(f.validFrom)}–${date(f.validUntil)}\n${f.region} · ${f.variable}\n${f.statement}\n${f.probabilities}\n${f.limitations}\n${f.url}',
                ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Limitaciones y datos pendientes (${e.missingData.length})',
            ),
            children: [
              for (final m in e.missingData)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('• $m'),
                  ),
                ),
              Text(
                '${e.crop.observations}\n${e.crop.validation}\n${e.crop.salinityNote}',
              ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Fuentes agronómicas'),
            children: [
              Text(e.sources.join('\n')),
              for (final s
                  in AgronomyCatalog.current?.sources ?? <AgronomySource>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${s.id}: ${s.reference}\n${s.support}\n${s.url ?? 'Enlace no proporcionado'}',
                  ),
                ),
            ],
          ),
          if (onMarket != null)
            FilledButton.icon(
              key: const Key('campaign-market'),
              onPressed: onMarket,
              icon: const Icon(Icons.sensors),
              label: const Text('Ver qué conviene verificar'),
            ),
        ],
      ),
    );
  }
}
