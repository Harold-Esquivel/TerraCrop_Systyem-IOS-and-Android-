import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/agronomy_catalog.dart';
import '../data/crop_care_plan.dart';
import '../data/crop_recommendations.dart';
import '../data/models.dart';
import '../data/terra_store.dart';
import 'soil_analysis_editor.dart';

class CropsScreen extends StatefulWidget {
  const CropsScreen({super.key});
  @override
  State<CropsScreen> createState() => _CropsScreenState();
}

class _CropsScreenState extends State<CropsScreen> {
  late Future<AgronomyCatalog> catalogFuture = AgronomyCatalog.load();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const PageIntro(
        eyebrow: 'Cuida lo que cultivas',
        title: 'Cultivos',
        subtitle: 'Lo importante para cada parcela',
      ),
      Expanded(
        child: FutureBuilder<AgronomyCatalog>(
          future: catalogFuture,
          initialData: AgronomyCatalog.current,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudieron cargar los cuidados.'),
                    TextButton(
                      onPressed: () => setState(
                        () => catalogFuture = AgronomyCatalog.load(),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }
            final catalog = snapshot.data;
            if (catalog == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final parcels = context.watch<TerraStore>().parcels;
            final engine = CropRecommendationEngine(catalog);
            final needingAttention = parcels
                .where(
                  (p) =>
                      engine.assess(p).severity != RecommendationSeverity.info,
                )
                .length;
            return ListView(
              key: const PageStorageKey('crops-list'),
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 25),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1769D2), Color(0xFF127A5A)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TU CAMPO, AL DÍA',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              '${parcels.length} ${parcels.length == 1 ? 'parcela' : 'parcelas'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              needingAttention == 0
                                  ? 'Revisa tus datos y próximos cuidados'
                                  : '$needingAttention ${needingAttention == 1 ? 'necesita' : 'necesitan'} atención',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.eco_rounded,
                        size: 48,
                        color: Color(0xFFB6F4D6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 23),
                Text(
                  'Tus parcelas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (parcels.isEmpty)
                  const SurfaceCard(
                    child: Text(
                      'Crea tu primera parcela desde MAPA para ver sus cuidados.',
                    ),
                  ),
                for (final parcel in parcels) ...[
                  _CropCard(
                    key: ValueKey(parcel.id),
                    parcel: parcel,
                    catalog: catalog,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _CropCard extends StatefulWidget {
  const _CropCard({super.key, required this.parcel, required this.catalog});
  final Parcel parcel;
  final AgronomyCatalog catalog;
  @override
  State<_CropCard> createState() => _CropCardState();
}

class _CropCardState extends State<_CropCard> {
  bool showAllCare = false;
  bool busy = false;

  Future<void> _save(Parcel next, String message) async {
    final store = context.read<TerraStore>();
    setState(() => busy = true);
    try {
      await store.updateParcel(next);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar. Revisa los datos y vuelve a intentarlo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _editAnalysis() async {
    final result = await Navigator.of(context).push<SoilAnalysis>(
      MaterialPageRoute(
        builder: (_) => SoilAnalysisEditor(initial: widget.parcel.soilAnalysis),
      ),
    );
    if (!mounted || result == null) return;
    await _save(
      widget.parcel.copyWith(soilAnalysis: result),
      'Análisis de suelo guardado',
    );
  }

  Future<void> _editHistory() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => CropHistoryEditor(
          initial: widget.parcel.cropHistory,
          catalog: widget.catalog,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _save(
      widget.parcel.copyWith(cropHistory: result),
      'Historial de cultivos guardado',
    );
  }

  Future<void> _registerCrop(CropProfile crop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar nueva siembra'),
        content: Text(
          '¿Ya sembraste ${crop.name} en ${widget.parcel.name}? Se actualizará el cultivo y se guardará ${widget.parcel.crop} en el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Registrar siembra'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _save(
      widget.parcel.copyWith(crop: crop.name),
      'Nueva siembra registrada en el historial',
    );
  }

  Future<void> _showRotations(CropAssessment assessment) async {
    final crop = await showModalBottomSheet<CropProfile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _RotationSheet(parcel: widget.parcel, assessment: assessment),
    );
    if (!mounted || crop == null) return;
    await _registerCrop(crop);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parcel;
    final assessment = CropRecommendationEngine(widget.catalog).assess(p);
    final actions = buildCropCarePlan(p, assessment);
    final visible = showAllCare ? actions : actions.take(3);
    final analysis = p.soilAnalysis;
    final color = assessment.severity == RecommendationSeverity.info
        ? context.colors.green
        : context.colors.blue;
    final hasMissingSoilData = assessment.missingData.any(
      (data) => !data.contains('historial') && !data.contains('histórico'),
    );
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.grass_rounded, color: context.colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.crop,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _tag(assessment.status, color),
              _tag(
                assessment.isDemo ? 'Datos de ejemplo' : 'Análisis ingresado',
                context.colors.muted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReadingChip(
                icon: Icons.science_outlined,
                label: 'pH',
                value: analysis == null
                    ? p.ph.toStringAsFixed(1)
                    : analysis.ph?.toStringAsFixed(1) ?? 'Sin dato',
              ),
              _ReadingChip(
                icon: Icons.water_drop_outlined,
                label: 'Humedad',
                value: analysis == null
                    ? '${p.moisture.round()}/100'
                    : analysis.moistureLow == null
                    ? 'Sin dato'
                    : analysis.moistureLow!
                    ? 'Baja'
                    : 'No baja',
              ),
              if (analysis?.organicMatter case final organicMatter?)
                _ReadingChip(
                  icon: Icons.eco_outlined,
                  label: 'M. orgánica',
                  value: '${_n(organicMatter)}%',
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Cuidados prioritarios',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            actions.isEmpty
                ? (hasMissingSoilData
                      ? 'Completa los datos para afinar tus cuidados'
                      : 'Sin alertas con los datos disponibles')
                : '${actions.length} ${actions.length == 1 ? 'acción para' : 'acciones para'} esta parcela',
            key: ValueKey('crop-issue-summary-${p.id}'),
            style: TextStyle(color: context.colors.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (actions.isEmpty)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: context.colors.softGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hasMissingSoilData
                        ? Icons.fact_check_outlined
                        : Icons.check_circle_outline,
                    color: context.colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      hasMissingSoilData
                          ? 'Registra los datos que faltan antes de decidir qué aportar al suelo.'
                          : 'Mantén el monitoreo de humedad y nutrientes.',
                      style: const TextStyle(fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          for (final action in visible)
            _CareActionTile(
              key: ValueKey('crop-issue-${p.id}-${action.id}'),
              action: action,
            ),
          if (actions.length > 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('crop-recommendations-${p.id}'),
                onPressed: () => setState(() => showAllCare = !showAllCare),
                icon: Icon(
                  showAllCare ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  showAllCare
                      ? 'Ver solo lo prioritario'
                      : 'Ver ${actions.length - 3} cuidados más',
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            assessment.isDemo
                ? 'Datos de ejemplo. Ingresa un análisis para personalizar los cuidados.'
                : hasMissingSoilData
                ? 'Faltan datos del suelo. Completa el análisis para precisar los cuidados.'
                : 'Cuidados según el análisis ingresado.',
            style: TextStyle(
              color: context.colors.muted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              OutlinedButton.icon(
                key: ValueKey('crop-analysis-${p.id}'),
                onPressed: busy ? null : _editAnalysis,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: Text(
                  analysis == null ? 'Ingresar datos' : 'Actualizar datos',
                ),
              ),
              TextButton.icon(
                key: ValueKey('crop-history-${p.id}'),
                onPressed: busy ? null : _editHistory,
                icon: const Icon(Icons.history, size: 17),
                label: const Text('Historial'),
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 10),
          Material(
            color: context.colors.softGreen,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: ValueKey('crop-rotations-${p.id}'),
              borderRadius: BorderRadius.circular(14),
              onTap: busy ? null : () => _showRotations(assessment),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Icon(
                      Icons.autorenew_rounded,
                      color: context.colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Planificar próxima siembra',
                        style: TextStyle(
                          color: context.colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: context.colors.green,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareActionTile extends StatelessWidget {
  const _CareActionTile({super.key, required this.action});
  final CropCareAction action;

  @override
  Widget build(BuildContext context) {
    final water =
        action.topic == CropCareTopic.water ||
        action.topic == CropCareTopic.drainage ||
        action.topic == CropCareTopic.salinity;
    final color = water ? context.colors.blue : context.colors.green;
    final icon = switch (action.topic) {
      CropCareTopic.water => Icons.water_drop_outlined,
      CropCareTopic.drainage => Icons.water_outlined,
      CropCareTopic.salinity => Icons.waves_rounded,
      CropCareTopic.ph => Icons.science_outlined,
      CropCareTopic.organicMatter => Icons.compost_rounded,
      CropCareTopic.soilHealth => Icons.autorenew_rounded,
      CropCareTopic.nutrientExcess => Icons.remove_circle_outline,
      _ => Icons.eco_outlined,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: water ? context.colors.softBlue : context.colors.softGreen,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.reason,
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  action.instruction,
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
                if (action.severity == RecommendationSeverity.critical) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Atender primero',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingChip extends StatelessWidget {
  const _ReadingChip({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: context.colors.canvas,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: context.colors.blue, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label · $value',
            style: TextStyle(color: context.colors.muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _RotationSheet extends StatelessWidget {
  const _RotationSheet({required this.parcel, required this.assessment});
  final Parcel parcel;
  final CropAssessment assessment;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .83,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Próxima siembra',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              Text(
                '${parcel.name} · Después de ${parcel.crop}',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                parcel.cropHistory.isEmpty
                    ? 'Completa el historial para revisar las familias de campañas anteriores.'
                    : 'Se consideran el cultivo actual y las campañas registradas.',
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              22,
              0,
              22,
              22 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (assessment.rotations.isEmpty)
                SurfaceCard(
                  child: Text(
                    assessment.profile == null
                        ? 'Este cultivo aún no tiene una ficha de rotación.'
                        : 'No hay una alternativa compatible con los datos actuales. Revisa pH, salinidad e historial.',
                  ),
                ),
              for (final candidate in assessment.rotations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    key: ValueKey('rotation-${parcel.id}-${candidate.crop.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.crop.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _tag(candidate.level, context.colors.green),
                            _tag(candidate.crop.family, context.colors.blue),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          candidate.isPotential
                              ? 'Confirma su adaptación local antes de elegirlo.'
                              : 'Valida temporada, pH, salinidad y agua disponible antes de sembrar.',
                          style: const TextStyle(fontSize: 12, height: 1.45),
                        ),
                        if (candidate.crop.isLegume) ...[
                          const SizedBox(height: 6),
                          Text(
                            'El aporte de nitrógeno depende de nodulación, fósforo y salinidad.',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (candidate.crop.id == 'C004') ...[
                          const SizedBox(height: 6),
                          Text(
                            'Es perenne: planifica varios años y su demanda anual de agua.',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, candidate.crop),
                          icon: const Icon(
                            Icons.event_available_outlined,
                            size: 17,
                          ),
                          label: const Text('Registrar siembra'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (assessment.blockedRotations.isNotEmpty)
                ExpansionTile(
                  key: PageStorageKey('blocked-rotations-${parcel.id}'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Opciones no recomendadas (${assessment.blockedRotations.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    for (final blocked in assessment.blockedRotations)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          blocked.crop.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          blocked.blockers.first.replaceAll(
                            ' según el Excel',
                            '',
                          ),
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 11,
                          ),
                        ),
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

Widget _tag(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
  ),
);

String _n(num value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
