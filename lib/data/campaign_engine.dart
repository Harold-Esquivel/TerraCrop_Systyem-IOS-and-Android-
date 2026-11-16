import 'agronomy_catalog.dart';
import 'crop_recommendations.dart';
import 'environment_repository.dart';
import 'models.dart';
import 'soil_rule_engine.dart';

enum CampaignCategory {
  compatible('Compatible según los criterios disponibles'),
  review('Requiere revisión'),
  restricted('Presenta restricciones importantes'),
  insufficient('Información insuficiente');

  const CampaignCategory(this.label);
  final String label;
}

enum AttentionLevel { information, review, restriction }

class DecisionAlert {
  const DecisionAlert({
    required this.id,
    required this.title,
    required this.parcelName,
    required this.cropName,
    required this.variable,
    required this.value,
    required this.unit,
    required this.date,
    required this.origin,
    required this.criterion,
    required this.explanation,
    required this.level,
    required this.actions,
    required this.verification,
    required this.missingData,
    required this.references,
  });
  final String id,
      title,
      parcelName,
      cropName,
      variable,
      unit,
      origin,
      criterion,
      explanation,
      verification;
  final String? value;
  final DateTime? date;
  final AttentionLevel level;
  final List<String> actions, missingData, references;
}

class CampaignInput {
  CampaignInput({
    required this.parcel,
    required this.previousCrop,
    required this.cropId,
    required DateTime start,
    required this.availableDays,
    this.irrigationAvailable,
    this.effectiveIrrigationM3Ha,
    this.useRegionalClimateReference = false,
  }) : start = DateTime.utc(start.year, start.month, start.day) {
    if (availableDays < 1 ||
        availableDays > 3660 ||
        (effectiveIrrigationM3Ha != null &&
            (!effectiveIrrigationM3Ha!.isFinite ||
                effectiveIrrigationM3Ha! < 0)) ||
        (irrigationAvailable == false &&
            effectiveIrrigationM3Ha != null &&
            effectiveIrrigationM3Ha! > 0)) {
      throw const FormatException('Plazo o disponibilidad de agua inválidos');
    }
  }
  final Parcel parcel;
  final String previousCrop, cropId;
  final DateTime start;
  final int availableDays;
  final bool? irrigationAvailable;
  final bool useRegionalClimateReference;

  /// Effective irrigation reaching the crop, not withdrawal or gross supply.
  final double? effectiveIrrigationM3Ha;
}

class CampaignEvaluation {
  CampaignEvaluation({
    required this.input,
    required this.crop,
    required this.category,
    required this.earliestHarvest,
    required this.latestHarvest,
    required this.months,
    required this.alerts,
    required this.missingData,
    required this.advantages,
    required this.climate,
    required this.soilAssessment,
    required this.soilRules,
    required this.forecasts,
    required this.sources,
  });
  final CampaignInput input;
  final CropProfile crop;
  final CampaignCategory category;
  final DateTime? earliestHarvest, latestHarvest;
  final List<DateTime> months;
  final List<DecisionAlert> alerts;
  final List<String> missingData, advantages, sources;
  final List<MonthlyClimate> climate;
  final CropAssessment soilAssessment;
  final List<SoilRuleEvaluation> soilRules;
  final List<SeasonalOutlook> forecasts;
  String get forecastMessage => forecasts.isEmpty
      ? EnvironmentRepository.forecastUnavailable
      : 'Boletín estacional oficial disponible para todo el periodo evaluado; no garantiza las condiciones de la parcela.';
  static const nutritionLimitation =
      'No se dispone de información suficiente para calcular una necesidad específica de fertilización';
  String get nutrition =>
      'Referencias de campaña: N ${crop.nMin.round()}–${crop.nMax.round()}, P₂O₅ ${crop.pMin.round()}–${crop.pMax.round()}, K₂O ${crop.kMin.round()}–${crop.kMax.round()} kg/ha. $nutritionLimitation. No son dosis ni diferencias con el análisis cualitativo.';
  String get water =>
      '${crop.waterMin.round()}–${crop.waterMax.round()} ${crop.waterUnit}. Demanda del cultivo; no riego aplicado.';
}

class SequenceEvaluation {
  const SequenceEvaluation({
    required this.sequence,
    required this.steps,
    required this.minimumDays,
    required this.maximumDays,
    required this.waterMin,
    required this.waterMax,
  });
  final RotationSequence sequence;
  final List<CampaignEvaluation> steps;
  final int? minimumDays, maximumDays;
  final double? waterMin, waterMax;
}

class CampaignEngine {
  const CampaignEngine(this.catalog, this.environment);
  final AgronomyCatalog catalog;
  final EnvironmentRepository environment;

  CampaignEvaluation evaluate(CampaignInput input, {DateTime? asOf}) {
    final crop = catalog.findCrop(input.cropId);
    if (crop == null) throw const FormatException('Cultivo sin ficha');
    final previous = catalog.findCrop(input.previousCrop);
    final start = input.start;
    final minDays = crop.periodMin?.ceil(), maxDays = crop.periodMax?.ceil();
    final earliest = minDays == null
        ? null
        : start.add(Duration(days: minDays));
    final latest = maxDays == null ? null : start.add(Duration(days: maxDays));
    final months = <DateTime>[];
    // Unknown perennial duration does not borrow the available campaign length.
    if (latest != null) {
      for (
        var m = DateTime.utc(start.year, start.month);
        !m.isAfter(latest);
        m = DateTime.utc(m.year, m.month + 1)
      ) {
        months.add(m);
      }
    }
    final measured = input.parcel.copyWith(
      crop: crop.name,
      soilAnalysis: input.parcel.soilAnalysis ?? const SoilAnalysis(),
    );
    final assessment = CropRecommendationEngine(catalog).assess(measured);
    final soilRules = SoilRuleEngine(
      catalog,
    ).evaluate(input.parcel.soilAnalysis);
    final alerts = <DecisionAlert>[];
    final missing = <String>{};
    final advantages = <String>[];
    void add(
      String id,
      String title,
      String variable,
      String? value,
      String unit,
      String criterion,
      String explanation,
      List<String> actions, {
      AttentionLevel level = AttentionLevel.review,
      String origin = 'Base agronómica de TerraCrop, La Joya',
      DateTime? date,
      List<String> references = const ['Cultivos', 'F17'],
      List<String> gaps = const [],
      String verification =
          'Confirmar con análisis y asesoría agronómica local.',
    }) {
      alerts.add(
        DecisionAlert(
          id: id,
          title: title,
          parcelName: input.parcel.name,
          cropName: crop.name,
          variable: variable,
          value: value,
          unit: unit,
          date: date,
          origin: origin,
          criterion: criterion,
          explanation: explanation,
          level: level,
          actions: List.unmodifiable(actions),
          verification: verification,
          missingData: List.unmodifiable(gaps),
          references: List.unmodifiable(references),
        ),
      );
    }

    final pair = previous == null
        ? null
        : catalog.compatibilityFor(previous.id, crop.id);
    if (pair == null) {
      missing.add('Cultivo anterior o transición sin ficha de compatibilidad.');
    } else {
      final blocked = pair.score == 0 || previous!.family == crop.family;
      add(
        'rotation',
        'Rotación: ${pair.level}',
        'cultivo anterior',
        previous!.name,
        '',
        pair.level,
        '${pair.condition}. ${pair.observation}',
        [
          if (blocked)
            'Comparar cultivos de otra familia con compatibilidad documentada.'
          else
            'Validar clima, suelo, agua e historial antes de elegir.',
          if (previous.isLegume || crop.isLegume)
            'El beneficio de N depende de nodulación, fósforo, salinidad y residuos; no se garantiza aporte.',
        ],
        level: blocked
            ? AttentionLevel.restriction
            : AttentionLevel.information,
        references: ['Compatibilidad ${pair.previousId} → ${pair.nextId}'],
      );
      if (!blocked) {
        advantages.add(
          'Transición ${pair.level.toLowerCase()} en la matriz; sujeta a los demás criterios.',
        );
      }
    }
    final recent = input.parcel.cropHistory.reversed.take(3).toList();
    if (recent.isEmpty) {
      missing.add('Historial de campañas anteriores incompleto.');
    }
    for (final name in recent) {
      final old = catalog.findCrop(name);
      if (old == null) {
        missing.add('Familia histórica desconocida: $name.');
        continue;
      }
      if (old.family == crop.family) {
        add(
          'history-${old.id}',
          'Familia repetida en el historial',
          'familia',
          crop.family,
          '',
          'Regla conservadora de la app: tres campañas anteriores',
          '${old.name} pertenece a la misma familia. Esta ventana no es un plazo de saneamiento validado.',
          ['Revisar enfermedades y elegir una familia diferente.'],
          level: AttentionLevel.restriction,
          references: ['Historial declarado; criterio de la app'],
        );
      }
    }
    if (latest == null || earliest == null) {
      missing.add(
        'Duración numérica no documentada: ${crop.periodDescription}.',
      );
    } else if (minDays! > input.availableDays) {
      add(
        'duration',
        'El ciclo no cabe en el plazo',
        'duración mínima',
        '$minDays',
        'días',
        '<= ${input.availableDays} días disponibles',
        'Incluso la duración mínima supera el tiempo disponible.',
        ['Comparar alternativas de ciclo más corto o ampliar el plazo.'],
        level: AttentionLevel.restriction,
      );
    } else if (maxDays! > input.availableDays) {
      add(
        'duration',
        'Solo cabe el extremo corto del ciclo',
        'duración máxima',
        '$maxDays',
        'días',
        '<= ${input.availableDays} días disponibles',
        'El ciclo completo no queda cubierto por el plazo. La variedad y el manejo pueden cambiar la cosecha.',
        ['Confirmar variedad y considerar un plazo mayor.'],
      );
    } else {
      advantages.add('El intervalo documentado de duración cabe en el plazo.');
    }
    final calendar = catalog.calendarFor(crop.id);
    if (calendar == null || calendar.sowingMonths.isEmpty) {
      missing.add('Ventana local de siembra de ${crop.name} por confirmar.');
    } else {
      final withinWindow = calendar.sowingMonths.contains(start.month);
      add(
        'sowing-window',
        withinWindow
            ? 'Inicio dentro de la ventana local de referencia'
            : 'Inicio fuera de la ventana local de referencia',
        'mes de siembra o trasplante',
        '${start.month}',
        'mes',
        'Meses de referencia: ${calendar.sowingMonths.join(', ')}',
        '${calendar.evidence} Confianza declarada: ${calendar.confidence}. La ventana no garantiza aptitud de la campaña.',
        [
          'Confirmar variedad, clima reciente y fecha de siembra o trasplante con asesoría local.',
        ],
        level: withinWindow
            ? AttentionLevel.information
            : AttentionLevel.review,
        origin: 'Calendario La Joya; ${catalog.source['fileName']}',
        references: ['Calendario La Joya ${crop.id}'],
      );
    }
    missing.add(
      'Falta calendario de etapas críticas por variedad; la temporada no queda confirmada.',
    );
    for (final review in catalog.dataReviews.where(
      (r) =>
          r['estado'] == 'Pendiente del equipo' &&
          RegExp('\\b${crop.id}\\b').hasMatch(r['hoja_dato'] as String),
    )) {
      add(
        'data-review-${review['id']}',
        'Datos del cultivo pendientes de revisión',
        review['hoja_dato'] as String,
        review['valor_en_la_base'] as String,
        '',
        'Revisión ${review['id']} pendiente del equipo',
        review['lo_que_dicen_las_fuentes'] as String,
        [review['accion_propuesta'] as String],
        references: ['Revisión de datos ${review['id']}'],
      );
    }
    if (crop.periodDescription.toLowerCase().contains('trasplante')) {
      missing.add(
        'La duración de ${crop.name} comienza en trasplante; el semillero previo no está incluido.',
      );
    }
    if (!crop.isPriority) {
      add(
        'pilot',
        'Cultivo fuera de la selección piloto',
        'pertinencia',
        crop.classification,
        '',
        'Presencia local documentada',
        crop.evidence,
        ['Comparar cultivos prioritarios de La Joya.'],
        level: AttentionLevel.restriction,
      );
    } else if (crop.isPotential) {
      missing.add(
        'Presencia de ${crop.name} en La Joya por confirmar: ${crop.evidence}',
      );
    }

    for (final e in soilRules) {
      if (e.state == RuleState.unavailable) {
        missing.addAll(e.missingData);
        continue;
      }
      if (e.state != RuleState.triggered) continue;
      final issue = assessment.issues
          .where((i) => i.id == e.rule.id)
          .firstOrNull;
      add(
        e.rule.id,
        e.rule.interpretation,
        e.rule.parameter,
        e.value,
        e.unit,
        e.operator,
        '${e.rule.interpretation}. Método: ${e.method}.',
        [
          issue?.action ?? e.rule.action,
          if (e.rule.warning.isNotEmpty && e.rule.warning != '-')
            e.rule.warning,
        ],
        level: e.rule.id == 'S005'
            ? AttentionLevel.information
            : AttentionLevel.review,
        origin:
            'Análisis u observación local ingresada; sin verificación independiente',
        date: e.sampledAt,
        references: ['Suelo Reglas ${e.rule.id}', ...e.sourceIds],
        gaps: e.missingData,
        verification:
            'Consultar el informe original, método y fecha; ${e.rule.warning}',
      );
    }
    for (final issue in assessment.issues.where(
      (i) => i.id == 'crop-ph' || i.id == 'crop-ec' || i.id.startsWith('high-'),
    )) {
      add(
        issue.id,
        issue.title,
        issue.id == 'crop-ec'
            ? 'CE'
            : issue.id == 'crop-ph'
            ? 'pH'
            : 'nutriente',
        issue.id == 'crop-ec'
            ? measured.soilAnalysis?.ec?.toString()
            : issue.id == 'crop-ph'
            ? measured.soilAnalysis?.ph?.toString()
            : 'alto',
        issue.id == 'crop-ec' ? 'dS/m' : '',
        'Rango de ${crop.name}',
        issue.explanation,
        [issue.action, issue.warning],
        level: issue.id.startsWith('high-')
            ? AttentionLevel.review
            : AttentionLevel.restriction,
        date: measured.soilAnalysis?.sampledAt,
        origin: 'Análisis ingresado y perfil agronómico',
        references: ['Cultivos ${crop.id}', if (issue.id == 'crop-ec') 'F02'],
      );
    }
    if (measured.soilAnalysis?.ec == null || crop.ecThreshold == null) {
      missing.add(
        'Salinidad sin contraste completo: falta CE del extracto saturado o umbral de ${crop.name}.',
      );
    }
    if (crop.isLegume &&
        measured.soilAnalysis?.phosphorus == NutrientLevel.low) {
      add(
        'legume-p',
        'Verificar fósforo antes de esperar fijación de N',
        'fósforo',
        'bajo',
        'categoría',
        'P suficiente para nodulación',
        'Una leguminosa no garantiza un aporte de nitrógeno con P limitado.',
        ['Resolver y validar disponibilidad de P; comprobar nodulación.'],
      );
    }
    final climate = <MonthlyClimate>[];
    for (final m in months) {
      for (final spec in [
        ('gpm', 'mm/month'),
        ('smap', 'm³/m³'),
        ('power_T2M', '°C'),
        ('power_T2M_MIN', '°C'),
        ('power_T2M_MAX', '°C'),
        ('power_PRECTOTCORR', 'mm/month'),
        ('power_RH2M', '%'),
        ('power_ALLSKY_SFC_SW_DWN', 'kWh/m²/day'),
        ('power_WS2M', 'm/s'),
      ]) {
        final source = environment.sources
            .where((s) => s.id == spec.$1 && s.unit == spec.$2)
            .firstOrNull;
        if (source == null) continue;
        if (source.isRegionalReference
            ? !input.useRegionalClimateReference
            : !source.covers(input.parcel)) {
          continue;
        }
        final stat = environment.monthly(source.id, m.month);
        if (stat != null) climate.add(stat);
      }
      final temp = climate
          .where((v) => v.month == m.month && v.source.id == 'power_T2M')
          .firstOrNull;
      if (temp == null) {
        missing.add(
          'Sin temperatura POWER aplicable para ${m.month}/${m.year}; no se confirma adecuación térmica.',
        );
      } else if (temp.mean < crop.temperatureMin ||
          temp.mean > crop.temperatureMax) {
        add(
          'thermal-${m.year}-${m.month}',
          'Condición térmica histórica fuera de referencia',
          'T2M',
          temp.mean.toStringAsFixed(1),
          '°C',
          '${crop.temperatureMin}–${crop.temperatureMax} °C',
          'Media histórica de ${m.month}, periodo ${temp.period}; no predice la temperatura futura ni identifica una helada diaria.',
          [
            'Revisar fecha de inicio, variedad y cultivos con otro rango térmico.',
          ],
          origin: '${temp.source.product}; histórico estimado',
          references: [temp.source.file, 'Cultivos ${crop.id}'],
          verification:
              'Consultar años, variabilidad y resolución; contrastar con estación local.',
        );
      }
    }
    if (climate.any((c) => c.source.isRegionalReference)) {
      add(
        'regional-climate-reference',
        'Referencia histórica de La Joya seleccionada',
        'ámbito climático',
        'Referencia regional',
        '',
        'Pertinencia local por confirmar',
        'Los datos proceden de puntos de consulta con coordenadas omitidas. La selección permite compararlos como contexto; no confirma que representen esta parcela.',
        [
          'Contrastar con ubicación, estación meteorológica y observaciones locales.',
        ],
        origin:
            'Referencias históricas proporcionadas; sin geolocalización exacta publicada',
        references: [
          'NASA POWER',
          if (climate.any((c) => c.source.id == 'smap')) 'SMAP',
        ],
      );
    }
    final rain = climate.where((v) => v.source.id == 'gpm').toList();
    if (rain.length != months.length || months.isEmpty) {
      missing.add(
        'Precipitación GPM ausente, fuera del ámbito local o incompleta para el periodo.',
      );
    }
    if (!climate.any((v) => v.source.id == 'smap')) {
      missing.add(
        'Sin contexto SMAP aplicable a la ubicación y meses seleccionados.',
      );
    }
    if (climate.any((v) => v.source.id == 'smap')) {
      missing.add(
        'SMAP sin banderas de calidad, producto ni resolución verificables; no mide la zona radicular de la parcela.',
      );
    }
    if (input.irrigationAvailable == null) {
      missing.add('Disponibilidad de riego desconocida.');
    }
    if (input.effectiveIrrigationM3Ha == null) {
      missing.add(
        'Volumen efectivo de riego y eficiencia no documentados; no se calcula una dosis de riego.',
      );
    }
    if (input.irrigationAvailable == false ||
        (input.effectiveIrrigationM3Ha != null &&
            !crop.isAnnualWater &&
            input.effectiveIrrigationM3Ha! < crop.waterMin)) {
      add(
        'water',
        'Revisar disponibilidad de agua',
        'riego efectivo',
        input.effectiveIrrigationM3Ha?.toString(),
        'm³/ha por campaña',
        'Demanda de referencia ${crop.waterMin}–${crop.waterMax} ${crop.waterUnit}',
        'El riego declarado no cubre por sí solo la demanda mínima o no está disponible. La lluvia satelital no equivale a lluvia efectiva.',
        [
          'Confirmar suministro, eficiencia, lluvia efectiva y balance hídrico con ETo local.',
        ],
        references: ['Cultivos ${crop.id}', 'F01'],
        verification:
            'Verificar turnos y caudal de riego; no sumar POWER y GPM ni asumir toda la lluvia aprovechable.',
      );
    }
    final outlooks = latest == null
        ? <SeasonalOutlook>[]
        : environment.forecasts
              .where(
                (f) => f.applies(
                  input.parcel,
                  start,
                  latest,
                  asOf ?? DateTime.now(),
                ),
              )
              .toList();
    final category = alerts.any((a) => a.level == AttentionLevel.restriction)
        ? CampaignCategory.restricted
        : (latest == null ||
              (pair == null && !climate.any((c) => c.source.id == 'power_T2M')))
        ? CampaignCategory.insufficient
        : missing.isNotEmpty ||
              alerts.any((a) => a.level == AttentionLevel.review)
        ? CampaignCategory.review
        : CampaignCategory.compatible;
    return CampaignEvaluation(
      input: input,
      crop: crop,
      category: category,
      earliestHarvest: earliest,
      latestHarvest: latest,
      months: List.unmodifiable(months),
      alerts: List.unmodifiable(alerts),
      missingData: List.unmodifiable(missing),
      advantages: List.unmodifiable(advantages),
      climate: List.unmodifiable(climate),
      soilAssessment: assessment,
      soilRules: soilRules,
      forecasts: List.unmodifiable(outlooks),
      sources: [
        'Cultivos ${crop.id}',
        'Compatibilidad',
        'Suelo Reglas',
        ...climate
            .map((c) => '${c.source.product} · ${c.source.file} · ${c.period}')
            .toSet(),
        ...outlooks.map((o) => o.url.toString()),
      ],
    );
  }

  List<CampaignEvaluation> alternatives(CampaignInput input) {
    final results = catalog.crops
        .where((c) => c.isPriority)
        .map(
          (crop) => evaluate(
            CampaignInput(
              parcel: input.parcel,
              previousCrop: input.previousCrop,
              cropId: crop.id,
              start: input.start,
              availableDays: input.availableDays,
              irrigationAvailable: input.irrigationAvailable,
              effectiveIrrigationM3Ha: input.effectiveIrrigationM3Ha,
              useRegionalClimateReference: input.useRegionalClimateReference,
            ),
          ),
        )
        .toList();
    results.sort((a, b) {
      int rank(CampaignCategory c) => switch (c) {
        CampaignCategory.compatible => 0,
        CampaignCategory.review => 1,
        CampaignCategory.insufficient => 2,
        CampaignCategory.restricted => 3,
      };
      final order = rank(a.category).compareTo(rank(b.category));
      return order != 0
          ? order
          : (a.crop.periodMax ?? double.infinity).compareTo(
              b.crop.periodMax ?? double.infinity,
            );
    });
    return List.unmodifiable(results);
  }

  List<SequenceEvaluation> compareSequences(CampaignInput input) =>
      catalog.sequences.map((s) {
        var start = input.start, previous = input.previousCrop;
        var min = 0, max = 0;
        double waterMin = 0, waterMax = 0;
        var knownDuration = true, knownWater = true;
        final results = <CampaignEvaluation>[];
        for (final step in catalog.stepsForSequence(s.id)) {
          final result = evaluate(
            CampaignInput(
              parcel: input.parcel,
              previousCrop: previous,
              cropId: step.cropId,
              start: start,
              availableDays: (input.availableDays - max).clamp(1, 3660),
              irrigationAvailable: input.irrigationAvailable,
              useRegionalClimateReference: input.useRegionalClimateReference,
            ),
          );
          results.add(result);
          if (result.crop.periodMin == null || result.crop.periodMax == null) {
            knownDuration = false;
          } else {
            min += result.crop.periodMin!.ceil();
            max += result.crop.periodMax!.ceil();
            start = start.add(Duration(days: result.crop.periodMax!.ceil()));
          }
          if (result.crop.isAnnualWater) {
            knownWater = false;
          } else {
            waterMin += result.crop.waterMin;
            waterMax += result.crop.waterMax;
          }
          previous = result.crop.id;
        }
        return SequenceEvaluation(
          sequence: s,
          steps: List.unmodifiable(results),
          minimumDays: knownDuration ? min : null,
          maximumDays: knownDuration ? max : null,
          waterMin: knownWater ? waterMin : null,
          waterMax: knownWater ? waterMax : null,
        );
      }).toList();
}
