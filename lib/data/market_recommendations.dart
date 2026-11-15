import 'agronomy_catalog.dart';
import 'campaign_engine.dart';
import 'market_catalog.dart';
import 'models.dart';
import 'soil_rule_engine.dart';

class MeasurementRecommendation {
  const MeasurementRecommendation({
    required this.id,
    required this.title,
    required this.reason,
    required this.method,
    required this.limitations,
    required this.calibration,
    required this.products,
    required this.references,
  });
  final String id, title, reason, method, limitations, calibration;
  final List<MarketProduct> products;
  final List<String> references;
}

class MicrobialRecommendation {
  const MicrobialRecommendation({
    required this.profile,
    required this.ruleIds,
    required this.pending,
    required this.blockers,
    required this.references,
  });
  final MicroorganismProfile profile;
  final List<String> ruleIds, pending, blockers, references;
  bool get canConsider => pending.isEmpty && blockers.isEmpty;
}

class MarketAdvice {
  const MarketAdvice({
    required this.measurements,
    required this.microorganisms,
  });
  final List<MeasurementRecommendation> measurements;
  final List<MicrobialRecommendation> microorganisms;
}

class MarketRecommendationService {
  const MarketRecommendationService(this.catalog);
  final AgronomyCatalog catalog;

  MarketAdvice recommend(CampaignEvaluation evaluation) {
    final analysis = evaluation.input.parcel.soilAnalysis;
    final active = evaluation.soilRules
        .where((r) => r.state == RuleState.triggered)
        .map((r) => r.rule.id)
        .toSet();
    final measurements = <MeasurementRecommendation>[];
    void measure(
      String id,
      String title,
      String reason,
      String method,
      String limitations,
      String calibration,
      List<String> ids,
    ) {
      measurements.add(
        MeasurementRecommendation(
          id: id,
          title: title,
          reason: reason,
          method: method,
          limitations: limitations,
          calibration: calibration,
          products: marketCatalog.where((p) => ids.contains(p.id)).toList(),
          references: [
            'Ficha técnica del catálogo de sensores',
            if (id == 'ec') 'F02',
            if (id == 'nutrition') 'F17',
          ],
        ),
      );
    }

    if (analysis?.moistureLow == null ||
        active.contains('S011') ||
        active.contains('S012')) {
      measure(
        'moisture',
        'Verificar humedad del suelo',
        'Humedad local desconocida, baja o drenaje por revisar.',
        'Medir a profundidad representativa y contrastar con textura y método gravimétrico.',
        'SMAP y la humedad relativa del aire no sustituyen esta medición. Un índice analógico no es directamente m³/m³.',
        'Calibrar para el suelo, profundidad y salinidad de la parcela; verificar instalación.',
        ['sen0193', 'sen0604'],
      );
    }
    if (analysis?.ec == null ||
        active.contains('S001') ||
        active.contains('S002') ||
        evaluation.alerts.any((a) => a.id == 'crop-ec')) {
      measure(
        'ec',
        'Confirmar salinidad mediante CE',
        'Falta CE comparable o hay una limitación por salinidad.',
        'Priorizar CE de extracto saturado de suelo en laboratorio para comparar los umbrales.',
        'CE del agua, extracto 1:5 y CE aparente de una sonda no equivalen a CE del extracto saturado.',
        'Usar patrones de conductividad y compensación de temperatura; confirmar método y rango con el fabricante.',
        ['dfr0300', 'sen0604'],
      );
    }
    if (analysis?.ph == null ||
        active.any((id) => {'S003', 'S004', 'S006'}.contains(id)) ||
        evaluation.alerts.any((a) => a.id == 'crop-ph')) {
      measure(
        'ph',
        'Verificar pH del suelo',
        'pH ausente o fuera de referencia.',
        'Análisis de suelo o medidor en suspensión con protocolo documentado.',
        'El pH aislado no confirma sodicidad ni permite dosificar yeso o cal. Compatibilidad con el móvil no documentada.',
        'Calibrar con soluciones tampón y registrar método, fecha y condiciones.',
        ['sen0161-v2', 'sen0604'],
      );
    }
    if (!evaluation.climate.any((c) => c.source.id == 'power_T2M') ||
        evaluation.alerts.any((a) => a.id.startsWith('thermal-'))) {
      measure(
        'temperature',
        'Contrastar temperatura del aire',
        'Evaluación térmica ausente o históricamente desfavorable.',
        'Consultar estación meteorológica local y medir aire con protección adecuada.',
        'DS18B20 mide la sonda/suelo, no reemplaza temperatura del aire a 2 m ni un pronóstico.',
        'SHT31 requiere protección solar, lluvia y condensación; verificar altura y calibración.',
        ['sht31'],
      );
    }
    if (analysis == null ||
        [
          analysis.nitrogen,
          analysis.phosphorus,
          analysis.potassium,
        ].any((v) => v != NutrientLevel.adequate)) {
      measure(
        'nutrition',
        'Consultar análisis nutricional',
        'Diagnóstico de nutrientes ausente o con niveles por revisar.',
        'Laboratorio con método, unidades, profundidad y criterio para el cultivo.',
        '${CampaignEvaluation.nutritionLimitation}. Los sensores NPK económicos no sustituyen un método validado.',
        'Revisar muestreo representativo y control de calidad del laboratorio.',
        [],
      );
    }
    final related = <String, List<String>>{};
    for (final rule in evaluation.soilRules.where(
      (r) => r.state == RuleState.triggered && r.rule.id != 'S005',
    )) {
      for (final id in rule.rule.microorganismIds) {
        related.putIfAbsent(id, () => []).add(rule.rule.id);
      }
    }
    final microbes = <MicrobialRecommendation>[];
    for (final entry in related.entries) {
      final m = catalog.microorganism(entry.key);
      if (m == null) continue;
      final pending = <String>[], blockers = <String>[];
      final id = m.id, crop = evaluation.crop;
      final allowed = switch (id) {
        'M001' => {'C004', 'C008', 'C009', 'C010'},
        'M002' ||
        'M004' => {'C001', 'C002', 'C003', 'C005', 'C006', 'C007', 'C012'},
        'M005' => {'C001', 'C002', 'C005', 'C006', 'C007', 'C012'},
        'M006' => {'C001', 'C002', 'C003', 'C005', 'C006', 'C007', 'C012'},
        'M008' => {
          'C001',
          'C002',
          'C003',
          'C004',
          'C005',
          'C006',
          'C007',
          'C011',
          'C012',
        },
        _ => catalog.crops.map((c) => c.id).toSet(),
      };
      if (!allowed.contains(crop.id))
        blockers.add('Asociación con ${crop.name} no documentada en la ficha.');
      if (analysis?.waterlogged != false) {
        if (analysis?.waterlogged == true) {
          blockers.add(
            'Resolver el encharcamiento antes de considerar aplicación.',
          );
        } else {
          pending.add('Confirmar drenaje.');
        }
      }
      if (id != 'M009') {
        if (analysis?.ec == null) {
          pending.add('Confirmar CE del extracto saturado.');
        } else if (analysis!.ec! >= 4 && id != 'M008') {
          blockers.add(
            'Salinidad alta: falta evidencia de cepa y respuesta en estas condiciones.',
          );
        }
      }
      if ({'M001', 'M007'}.contains(id)) {
        if (analysis?.ph == null) {
          pending.add('Confirmar pH.');
        } else if (id == 'M001' && (analysis!.ph! < 6 || analysis.ph! > 8)) {
          blockers.add('Rizobios: pH fuera de 6–8.');
        } else if (id == 'M007' && (analysis!.ph! <= 7 || crop.phMax > 7)) {
          blockers.add(
            'No se cumple pH alto y cultivo con referencia de pH 6–7.',
          );
        }
      }
      if (id == 'M001') {
        if (analysis?.nitrogen == NutrientLevel.high)
          blockers.add('No combinar con N mineral alto.');
        if (analysis?.phosphorus == NutrientLevel.unknown || analysis == null)
          pending.add('Confirmar disponibilidad de P para nodulación.');
        if (analysis?.phosphorus == NutrientLevel.low)
          blockers.add('P bajo: revisar antes de esperar nodulación efectiva.');
        if (analysis?.ec != null &&
            crop.ecThreshold != null &&
            analysis!.ec! >= crop.ecThreshold!)
          blockers.add('CE alcanza el umbral de la leguminosa.');
      }
      if ({'M002', 'M004', 'M005', 'M009'}.contains(id) &&
          analysis?.organicMatter == null)
        pending.add('Confirmar materia orgánica y condiciones del compost.');
      if ({'M001', 'M002', 'M004', 'M007', 'M009'}.contains(id) &&
          analysis?.moistureLow != false) {
        if (analysis?.moistureLow == true) {
          blockers.add('Corregir o verificar humedad baja.');
        } else {
          pending.add('Verificar humedad adecuada.');
        }
      }
      if (id == 'M006') {
        if (analysis?.phosphorus == NutrientLevel.high)
          blockers.add('P alto limita colonización micorrízica.');
        if (analysis?.phosphorus == NutrientLevel.unknown || analysis == null)
          pending.add('Descartar exceso de P.');
      }
      if (id == 'M008' && (analysis?.ec == null || analysis!.ec! < 2))
        blockers.add(
          'No se confirmó salinidad ligera a moderada; no recomendar por humedad baja aislada.',
        );
      // Even with compatible measurements the strain, registration, application
      // conditions and product interactions remain a necessary human check.
      pending.add(
        'Validar cepa, evidencia para ${crop.name}, registro y condiciones: ${m.conditions}.',
      );
      microbes.add(
        MicrobialRecommendation(
          profile: m,
          ruleIds: List.unmodifiable(entry.value),
          pending: List.unmodifiable(pending),
          blockers: List.unmodifiable(blockers),
          references: [
            ...{
              'Microorganismos ${m.id}',
              if ({'M003', 'M005', 'M008'}.contains(id)) ...[
                'F09',
                'F10',
                'F11',
              ],
              'La ficha no identifica ensayo ni producto de cepa específica.',
            },
          ],
        ),
      );
    }
    return MarketAdvice(
      measurements: List.unmodifiable(measurements),
      microorganisms: List.unmodifiable(microbes),
    );
  }
}
