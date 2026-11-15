import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/agronomy_catalog.dart';
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
        eyebrow: 'Monitoreo y rotación',
        title: 'Cultivos',
        subtitle: 'Qué necesita tu suelo y qué cultivar después',
      ),
      Expanded(
        child: FutureBuilder<AgronomyCatalog>(
          future: catalogFuture,
          initialData: AgronomyCatalog.current,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudo cargar la base agronómica.'),
                      TextButton(
                        onPressed: () => setState(
                          () => catalogFuture = AgronomyCatalog.load(),
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
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
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2671E8), Color(0xFF4B98FF)],
                    ),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumen de tu campo',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${parcels.length} parcelas activas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              needingAttention == 0
                                  ? 'Revisa los datos y su origen antes de decidir'
                                  : '$needingAttention requieren revisión',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.spa_rounded,
                        size: 45,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SurfaceCard(
                  color: paleBlue,
                  child: Text(
                    'Base del Excel para La Joya, Arequipa. Las referencias de demanda y las opciones de rotación requieren validación local; no son una receta de fertilización.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tus parcelas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (parcels.isEmpty)
                  const SurfaceCard(
                    child: Text('Aún no hay parcelas. Crea una desde MAPA.'),
                  ),
                for (final parcel in parcels) ...[
                  _CropCard(
                    key: ValueKey(parcel.id),
                    parcel: parcel,
                    catalog: catalog,
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 8),
                _KnowledgeLibrary(catalog: catalog),
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
  bool expanded = false;
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
          '¿Ya sembraste ${crop.name} en ${widget.parcel.name}? Esta acción cambiará el cultivo actual y añadirá ${widget.parcel.crop} a las campañas anteriores. Usarla solo para comparar opciones no es necesario.',
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

  @override
  Widget build(BuildContext context) {
    final p = widget.parcel;
    final assessment = CropRecommendationEngine(widget.catalog).assess(p);
    final color = switch (assessment.severity) {
      RecommendationSeverity.critical => const Color(0xFFE57D45),
      RecommendationSeverity.warning => const Color(0xFFAD7A20),
      RecommendationSeverity.info =>
        assessment.missingData.isEmpty ? green : muted,
    };
    final analysis = p.soilAnalysis;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.eco_rounded, color: green, size: 28),
              const SizedBox(width: 10),
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
                      'Cultivo de ${p.crop}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _tag(assessment.status, color),
              _tag(
                assessment.isDemo
                    ? 'Datos de demostración'
                    : 'Análisis ingresado',
                blue,
              ),
              if (assessment.profile case final profile?)
                _tag(profile.classification, muted),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 15,
            runSpacing: 10,
            children: [
              _reading(
                'pH',
                analysis == null
                    ? p.ph.toStringAsFixed(1)
                    : analysis.ph?.toStringAsFixed(1) ?? 'Sin dato',
              ),
              _reading(
                'Humedad',
                analysis == null
                    ? '${p.moisture.round()}/100 · demo'
                    : analysis.moistureLow == null
                    ? 'Sin dato'
                    : analysis.moistureLow!
                    ? 'Baja observada'
                    : 'No baja observada',
              ),
              _reading(
                'Nitrógeno',
                analysis == null
                    ? '${p.nitrogen.round()}/100 · demo'
                    : nutrientLabel(analysis.nitrogen),
              ),
              _reading(
                'Fósforo',
                analysis == null
                    ? '${p.phosphorus.round()}/100 · demo'
                    : nutrientLabel(analysis.phosphorus),
              ),
              _reading(
                'Potasio',
                analysis == null
                    ? '${p.potassium.round()}/100 · demo'
                    : nutrientLabel(analysis.potassium),
              ),
              if (analysis != null)
                _reading(
                  'CE (dS/m)',
                  analysis.ec?.toStringAsFixed(2) ?? 'Sin dato',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            assessment.isDemo
                ? 'Los índices de N/P/K son simulados; no son una lectura de laboratorio ni se convierten a kg/ha.'
                : 'Datos transcritos por el usuario. Los campos sin dato se mantienen desconocidos.',
            style: const TextStyle(fontSize: 11, color: muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              OutlinedButton.icon(
                key: ValueKey('crop-analysis-${p.id}'),
                onPressed: busy ? null : _editAnalysis,
                icon: const Icon(Icons.science_outlined, size: 17),
                label: Text(
                  analysis == null ? 'Ingresar análisis' : 'Editar análisis',
                ),
              ),
              TextButton.icon(
                key: ValueKey('crop-history-${p.id}'),
                onPressed: busy ? null : _editHistory,
                icon: const Icon(Icons.history, size: 17),
                label: const Text('Historial'),
              ),
              if (analysis != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _save(
                          p.copyWith(clearSoilAnalysis: true),
                          'Vista de demostración restaurada',
                        ),
                  child: const Text('Volver a datos demo'),
                ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
          if (assessment.issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assessment.issues.map((i) => i.title).join(' · '),
                      key: ValueKey('crop-issue-summary-${p.id}'),
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: ValueKey('crop-recommendations-${p.id}'),
              onPressed: () => setState(() => expanded = !expanded),
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(expanded ? 'Ver menos' : 'Ver recomendaciones'),
            ),
          ),
          if (expanded) ...[
            const Divider(color: border),
            Text(
              'Diagnóstico y acciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (assessment.issues.isEmpty)
              const Text(
                'No se detectan alertas con los datos disponibles. Esto no reemplaza un análisis completo del suelo.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            for (final issue in assessment.issues) _issue(issue),
            if (assessment.missingData.isNotEmpty)
              _note('Datos por completar', assessment.missingData.join('\n')),
            for (final note in assessment.notes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  note,
                  style: const TextStyle(
                    fontSize: 11,
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              '¿Qué cultivar después?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              p.cropHistory.isEmpty
                  ? 'No hay campañas anteriores registradas. Las opciones usan el cultivo actual; completa el historial para detectar repeticiones recientes.'
                  : 'Campañas anteriores: ${p.cropHistory.join(' → ')} → ${p.crop} (actual)',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'Compatibilidad del Excel, condicionada al análisis de suelo, clima y validación local. No se aplica ningún cambio automáticamente.',
              style: TextStyle(fontSize: 11, color: muted, height: 1.5),
            ),
            const SizedBox(height: 10),
            if (assessment.rotations.isEmpty)
              const Text(
                'No hay una alternativa sin restricciones con estos datos. Revisa las razones de las opciones descartadas.',
                style: TextStyle(fontSize: 12),
              ),
            for (final candidate in assessment.rotations) _rotation(candidate),
            if (assessment.blockedRotations.isNotEmpty)
              ExpansionTile(
                key: PageStorageKey('blocked-rotations-${p.id}'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Opciones no recomendadas (${assessment.blockedRotations.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: [
                  for (final candidate in assessment.blockedRotations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _note(
                        candidate.crop.name,
                        candidate.blockers.join('\n'),
                      ),
                    ),
                ],
              ),
            if (assessment.profile case final profile?) _profile(profile),
          ],
        ],
      ),
    );
  }

  Widget _issue(SoilIssue issue) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      key: ValueKey('crop-issue-${widget.parcel.id}-${issue.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: canvas,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            issue.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            issue.explanation,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 7),
          Text(issue.action, style: const TextStyle(fontSize: 12, height: 1.5)),
          if (issue.warning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                issue.warning,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9F6225),
                  height: 1.4,
                ),
              ),
            ),
          if (issue.sourceRuleId != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Regla del Excel: ${issue.sourceRuleId}${issue.isDemo ? ' · activada por un índice demo' : ''}',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ),
          for (final id in issue.microorganismIds) _microorganism(id, issue.id),
        ],
      ),
    ),
  );

  Widget _microorganism(String id, String issueId) {
    final micro = widget.catalog.microorganisms
        .where((m) => m.id == id)
        .firstOrNull;
    if (micro == null) return const SizedBox.shrink();
    return ExpansionTile(
      key: PageStorageKey('micro-${widget.parcel.id}-$issueId-$id'),
      tilePadding: EdgeInsets.zero,
      title: Text(
        '${micro.id} · ${micro.group}',
        style: const TextStyle(fontSize: 12),
      ),
      children: [_microDetails(micro)],
    );
  }

  Widget _rotation(RotationCandidate candidate) => Container(
    key: ValueKey('rotation-${widget.parcel.id}-${candidate.crop.id}'),
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 11),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          candidate.crop.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _tag('${candidate.score}/3 · ${candidate.level}', green),
            _tag(candidate.crop.family, blue),
            if (candidate.isPotential)
              _tag('Presencia local por confirmar', const Color(0xFF9F6225)),
          ],
        ),
        const SizedBox(height: 8),
        for (final reason in candidate.reasons)
          Text('• $reason', style: const TextStyle(fontSize: 12, height: 1.5)),
        for (final condition in candidate.conditions)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              condition,
              style: const TextStyle(fontSize: 11, color: muted, height: 1.4),
            ),
          ),
        const SizedBox(height: 7),
        TextButton.icon(
          onPressed: busy ? null : () => _registerCrop(candidate.crop),
          icon: const Icon(Icons.event_available_outlined, size: 17),
          label: const Text('Registrar una nueva siembra'),
        ),
      ],
    ),
  );

  Widget _profile(CropProfile profile) => ExpansionTile(
    key: PageStorageKey('crop-profile-${widget.parcel.id}-${profile.id}'),
    tilePadding: EdgeInsets.zero,
    title: const Text(
      'Ficha del cultivo en el Excel',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Cultivo', '${profile.name} · ${profile.scientificName}'),
          _field(
            'Familia / presencia',
            '${profile.family} · ${profile.classification}',
          ),
          _field(
            'pH de referencia',
            '${_n(profile.phMin)}–${_n(profile.phMax)}',
          ),
          _field(
            'Temperatura óptima',
            '${_n(profile.temperatureMin)}–${_n(profile.temperatureMax)} °C',
          ),
          _field(
            'Periodo',
            profile.periodMean == null
                ? profile.periodDescription
                : '${_n(profile.periodMin)}–${_n(profile.periodMax)} días · ${profile.periodDescription}',
          ),
          _field(
            'Demanda hídrica del cultivo',
            '${_n(profile.waterMin)}–${_n(profile.waterMax)} ${profile.waterUnit}',
          ),
          const Text(
            'La demanda del cultivo no es el riego aplicado ni un ahorro de agua garantizado.',
            style: TextStyle(fontSize: 11, color: muted, height: 1.4),
          ),
          const SizedBox(height: 10),
          _field(
            'Referencias N / P₂O₅ / K₂O (kg/ha)',
            '${_n(profile.nMin)}–${_n(profile.nMax)} / ${_n(profile.pMin)}–${_n(profile.pMax)} / ${_n(profile.kMin)}–${_n(profile.kMax)}',
          ),
          const Text(
            'Rangos referenciales del archivo; no se calculan dosis ni se comparan con los índices N/P/K de demostración.',
            style: TextStyle(fontSize: 11, color: muted, height: 1.4),
          ),
          const SizedBox(height: 10),
          _field(
            'Salinidad',
            '${profile.salinityCategory} · ${profile.ecThreshold == null ? 'Sin umbral documentado' : '${_n(profile.ecThreshold)} dS/m de CE del extracto saturado'}',
          ),
          _field('Observaciones', profile.observations),
          _field('Estado de validación', profile.validation),
        ],
      ),
    ],
  );
}

class _KnowledgeLibrary extends StatelessWidget {
  const _KnowledgeLibrary({required this.catalog});
  final AgronomyCatalog catalog;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Base agronómica del Excel',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        Text(
          '${catalog.crops.length} cultivos · ${catalog.compatibility.length} pares de compatibilidad',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        ExpansionTile(
          key: const PageStorageKey('knowledge-sequences'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Secuencias de rotación de referencia'),
          children: [
            const Text(
              'Escenarios del archivo para La Joya. Sus periodos son distintos: compara también la demanda por día, no solo el total.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            for (final sequence in catalog.sequences)
              ExpansionTile(
                key: PageStorageKey('knowledge-sequence-${sequence.id}'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${sequence.id} · ${sequence.role}',
                  style: const TextStyle(fontSize: 13),
                ),
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Secuencia', sequence.sequence),
                      _field(
                        'Demanda y duración',
                        '${_n(sequence.totalWater)} m³/ha · ${_n(sequence.totalDays)} días · ${sequence.waterPerDay.toStringAsFixed(1)} m³/ha/día',
                      ),
                      _field(
                        'Cambio de demanda total frente a S00',
                        '${(sequence.demandDifference * 100).toStringAsFixed(1)}% · periodos distintos; no equivale a ahorro de riego',
                      ),
                      _field(
                        'Diversidad',
                        '${sequence.differentFamilies} familias · ${sequence.sensitiveCampaigns} campañas con cultivo sensible',
                      ),
                      _field('Beneficio y mecanismo', sequence.benefit),
                      _field('Condiciones', sequence.conditions),
                      _field('Limitaciones', sequence.limitations),
                      for (final step in catalog.stepsForSequence(sequence.id))
                        _field(
                          'Campaña ${step.campaign}',
                          '${step.cropName} · ${step.family} · ${step.classification}\n${_n(step.water)} m³/ha · ${_n(step.days)} días · ${step.salinityCategory}',
                        ),
                      if (sequence.microorganismIds.isNotEmpty)
                        _field(
                          'Microorganismos de referencia',
                          sequence.microorganismIds.join(', '),
                        ),
                    ],
                  ),
                ],
              ),
          ],
        ),
        ExpansionTile(
          key: const PageStorageKey('knowledge-microorganisms'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Microorganismos: fichas de consulta'),
          children: [
            const Text(
              'Las fichas no son una indicación universal de uso. Verifica la cepa, el cultivo, las condiciones y el registro del producto comercial.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            for (final micro in catalog.microorganisms)
              ExpansionTile(
                key: PageStorageKey('knowledge-micro-${micro.id}'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '${micro.id} · ${micro.group}',
                  style: const TextStyle(fontSize: 12),
                ),
                children: [_microDetails(micro)],
              ),
          ],
        ),
        ExpansionTile(
          key: const PageStorageKey('knowledge-sources'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Fuentes y validación del archivo'),
          children: [
            const Text(
              'Referencias incluidas en el Excel. La importación conserva su contenido; no implica haber verificado cada publicación ni completar sus datos faltantes.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            for (final source in catalog.sources)
              Padding(
                padding: const EdgeInsets.only(top: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${source.id} · ${source.reference}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.support,
                      style: const TextStyle(fontSize: 11, height: 1.4),
                    ),
                    if (source.url case final url?)
                      TextButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(url);
                          if (uri != null &&
                              (uri.scheme == 'https' || uri.scheme == 'http')) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Abrir referencia'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

Widget _microDetails(MicroorganismProfile micro) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    _field('Género / especie', micro.species),
    _field('Función', micro.function),
    _field('Problema', micro.problem),
    _field('Cultivos', micro.crops),
    _field('Condiciones de uso', micro.conditions),
    _field('Aplicación indicada en el archivo', micro.application),
    _field('Limitaciones y precauciones', micro.limitations),
  ],
);

Widget _field(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: muted)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontSize: 12, height: 1.5)),
    ],
  ),
);

Widget _note(String title, String message) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: paleBlue,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      Text(message, style: const TextStyle(fontSize: 12, height: 1.5)),
    ],
  ),
);

Widget _reading(String label, String value) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(label, style: const TextStyle(fontSize: 10, color: muted)),
    const SizedBox(height: 3),
    Text(
      value,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  ],
);
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
String _n(num? value) => value == null
    ? 'Sin dato'
    : value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
