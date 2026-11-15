import 'agronomy_catalog.dart';
import 'models.dart';
import 'soil_rule_engine.dart';

enum RecommendationSeverity { info, warning, critical }

class SoilIssue {
  SoilIssue({
    required this.id,
    required this.title,
    required this.explanation,
    required this.action,
    this.warning = '',
    this.sourceRuleId,
    List<String> microorganismIds = const [],
    required this.isDemo,
    this.severity = RecommendationSeverity.warning,
  }) : microorganismIds = List.unmodifiable(microorganismIds);

  final String id, title, explanation, action, warning;
  final String? sourceRuleId;
  final List<String> microorganismIds;
  final bool isDemo;
  final RecommendationSeverity severity;
}

class RotationCandidate {
  RotationCandidate({
    required this.crop,
    required this.score,
    required this.level,
    required List<String> reasons,
    required List<String> conditions,
    required List<String> blockers,
  }) : reasons = List.unmodifiable(reasons),
       conditions = List.unmodifiable(conditions),
       blockers = List.unmodifiable(blockers);

  final CropProfile crop;
  final int score;
  final String level;
  final List<String> reasons, conditions, blockers;
  bool get isPotential =>
      crop.classification.toLowerCase().contains('potencial');
}

class CropAssessment {
  CropAssessment({
    required this.profile,
    required this.isDemo,
    required List<SoilIssue> issues,
    required List<RotationCandidate> rotations,
    required List<RotationCandidate> blockedRotations,
    required List<String> missingData,
    required List<String> notes,
  }) : issues = List.unmodifiable(issues),
       rotations = List.unmodifiable(rotations),
       blockedRotations = List.unmodifiable(blockedRotations),
       missingData = List.unmodifiable(missingData),
       notes = List.unmodifiable(notes);

  final CropProfile? profile;
  final bool isDemo;
  final List<SoilIssue> issues;
  final List<RotationCandidate> rotations, blockedRotations;
  final List<String> missingData, notes;
  bool get hasDeficits => issues.isNotEmpty;
  RecommendationSeverity get severity => issues.fold(
    RecommendationSeverity.info,
    (value, issue) =>
        issue.severity.index > value.index ? issue.severity : value,
  );
  String get status => switch (severity) {
    RecommendationSeverity.critical => 'En riesgo',
    RecommendationSeverity.warning => 'Atención',
    RecommendationSeverity.info =>
      missingData.isEmpty ? 'Sin alertas' : 'Datos por completar',
  };
}

/// Applies the supplied workbook as a reference, without turning campaign
/// fertilizer requirements (kg/ha) into measurements or prescribed doses.
class CropRecommendationEngine {
  const CropRecommendationEngine(this.catalog);
  final AgronomyCatalog catalog;

  CropAssessment assess(Parcel parcel) {
    final profile = catalog.findCrop(parcel.crop);
    final analysis = parcel.soilAnalysis;
    final demo = analysis == null;
    final missing = <String>{};
    final notes = <String>[
      'Base de referencia: TerraCrop_base para app.xlsx, La Joya, Arequipa. Las condiciones locales y el análisis de suelo deben validarse antes de aplicar tratamientos.',
      'Los rangos N, P₂O₅ y K₂O del catálogo son requerimientos de referencia en kg/ha; no son concentraciones medidas ni dosis calculadas para esta parcela.',
      'La demanda hídrica del cultivo no equivale al riego aplicado ni demuestra ahorro de agua.',
      'Los microorganismos son opciones condicionadas: verificar cepa, compatibilidad, condiciones del suelo y registro del producto comercial.',
    ];
    if (demo) {
      notes.add(
        'Modo demostración: pH, humedad y N/P/K provienen de los datos de prueba de la parcela. El umbral N/P/K < 40 es un índice de la app, no un umbral de laboratorio del Excel.',
      );
    }
    double? reading(double? value, String name, double min, double max) {
      if (value == null) {
        missing.add('Falta $name.');
        return null;
      }
      if (!value.isFinite || value < min || value > max) {
        missing.add('Revisar $name: valor inválido.');
        return null;
      }
      return value;
    }

    final ph = reading(demo ? parcel.ph : analysis.ph, 'pH del suelo', 0, 14);
    final ec = demo
        ? null
        : reading(
            analysis.ec,
            'CE del extracto saturado en dS/m',
            0,
            double.maxFinite,
          );
    final _ = demo
        ? null
        : reading(analysis.organicMatter, 'materia orgánica en %', 0, 100);
    NutrientLevel nutrient(NutrientLevel? measured, double index, String name) {
      if (!demo) {
        final value = measured ?? NutrientLevel.unknown;
        if (value == NutrientLevel.unknown) {
          missing.add('Falta diagnóstico de $name según análisis de suelo.');
        }
        return value;
      }
      final value = reading(index, 'índice de demostración de $name', 0, 100);
      if (value == null) return NutrientLevel.unknown;
      return value < 40 ? NutrientLevel.low : NutrientLevel.adequate;
    }

    final nitrogen = nutrient(analysis?.nitrogen, parcel.nitrogen, 'nitrógeno');
    final phosphorus = nutrient(
      analysis?.phosphorus,
      parcel.phosphorus,
      'fósforo',
    );
    final potassium = nutrient(
      analysis?.potassium,
      parcel.potassium,
      'potasio',
    );
    final moisture = demo
        ? reading(parcel.moisture, 'humedad de demostración', 0, 100)
        : null;
    final evaluatedRules = SoilRuleEngine(catalog).evaluate(
      demo
          ? SoilAnalysis(
              ph: ph,
              nitrogen: nitrogen,
              phosphorus: phosphorus,
              potassium: potassium,
            )
          : analysis,
    );
    final triggered = evaluatedRules
        .where((e) => e.state == RuleState.triggered)
        .map((e) => e.rule.id)
        .toSet();
    final issues = <SoilIssue>[];
    List<String> microbes(List<String> ids) => ids.where((id) {
      if (!catalog.microorganisms.any((m) => m.id == id)) return false;
      if (id == 'M001') {
        if (profile?.isLegume != true) return false;
        if (ph != null && (ph < 6 || ph > 8)) return false;
        if (nitrogen == NutrientLevel.high) return false;
        if (ec != null &&
            profile?.ecThreshold != null &&
            ec >= profile!.ecThreshold!) {
          return false;
        }
      }
      if (id == 'M007' && (ph == null || ph <= 7)) return false;
      if (id == 'M006') {
        if (phosphorus == NutrientLevel.high) return false;
        // The workbook explicitly marks quinoa colonisation as unverified.
        if (profile == null ||
            !{
              'C001',
              'C002',
              'C003',
              'C005',
              'C006',
              'C007',
              'C012',
            }.contains(profile.id)) {
          return false;
        }
      }
      if (id == 'M002' || id == 'M004' || id == 'M005') {
        final allowed = id == 'M005'
            ? {'C001', 'C002', 'C005', 'C006', 'C007', 'C012'}
            : {'C001', 'C002', 'C003', 'C005', 'C006', 'C007', 'C012'};
        if (profile == null || !allowed.contains(profile.id)) return false;
      }
      if (id == 'M008') {
        const allowed = {
          'C001',
          'C002',
          'C003',
          'C004',
          'C005',
          'C006',
          'C007',
          'C011',
          'C012',
        };
        if (profile == null || !allowed.contains(profile.id)) return false;
      }
      return true;
    }).toList();
    void rule(
      String id,
      String title, {
      RecommendationSeverity severity = RecommendationSeverity.warning,
      String? explanation,
    }) {
      final source = catalog.soilRules.where((r) => r.id == id).firstOrNull;
      if (source == null) {
        missing.add('No se encontró la regla $id en el catálogo.');
        return;
      }
      final warnings = <String>[
        if (source.warning.isNotEmpty && source.warning != '-') source.warning,
      ];
      var action = source.action;
      if (id == 'S001' || id == 'S002') {
        action =
            'Referencia general del Excel, sujeta a la evaluación de esta parcela: ${source.action}';
        warnings.add(
          'La referencia general a cultivos tolerantes no confirma que quinua o alfalfa sean compatibles con la CE medida ($ec dS/m). Para elegir un cultivo deben respetarse los umbrales y datos faltantes de su ficha y las restricciones mostradas en las opciones de rotación.',
        );
        for (final cropId in ['C011', 'C004']) {
          final crop = catalog.findCrop(cropId);
          if (crop == null) continue;
          if (crop.ecThreshold == null) {
            warnings.add(
              '${crop.name}: sin umbral de CE documentado; no se confirma su compatibilidad con esta medición.',
            );
          } else if (ec != null && ec >= crop.ecThreshold!) {
            warnings.add(
              '${crop.name}: la CE medida alcanza o supera su umbral de ${crop.ecThreshold} dS/m; permanece descartada para estas condiciones.',
            );
          }
        }
      }
      issues.add(
        SoilIssue(
          id: id,
          title: title,
          explanation: explanation ?? source.interpretation,
          action: action,
          warning: warnings.join(' '),
          sourceRuleId: id,
          microorganismIds: microbes(source.microorganismIds),
          isDemo: demo,
          severity: severity,
        ),
      );
    }

    if (ph != null) {
      if (triggered.contains('S003')) {
        rule('S003', 'pH muy alto', severity: RecommendationSeverity.critical);
      } else if (triggered.contains('S004')) {
        rule('S004', 'pH alcalino o en el límite alcalino');
        notes.add(
          'Convención de límites: a pH 7.5 se muestra S004; a pH 8.5 se muestra S003. Los intervalos contiguos del Excel se solapan en esos puntos.',
        );
      } else if (triggered.contains('S006')) {
        rule(
          'S006',
          'pH bajo: suelo ácido',
          severity: RecommendationSeverity.critical,
        );
      }
      if (profile != null && (ph < profile.phMin || ph > profile.phMax)) {
        issues.add(
          SoilIssue(
            id: 'crop-ph',
            title: 'pH fuera del rango de ${profile.name}',
            explanation:
                'pH ${ph.toStringAsFixed(1)}; referencia del cultivo: ${profile.phMin}–${profile.phMax}.',
            action:
                'Confirmar el análisis de suelo y evaluar el manejo para este cultivo. No calcular enmiendas a partir del pH aislado.',
            warning:
                'El pH por sí solo no demuestra sodicidad ni una carencia de N/P/K.',
            isDemo: demo,
          ),
        );
      } else if (triggered.contains('S005')) {
        final adequate = catalog.soilRules
            .where((r) => r.id == 'S005')
            .firstOrNull;
        if (adequate != null) {
          notes.add('S005: ${adequate.interpretation}. ${adequate.action}');
        }
      }
    }
    if (ec != null) {
      if (triggered.contains('S001')) {
        rule(
          'S001',
          'Salinidad del suelo alta',
          severity: RecommendationSeverity.critical,
        );
      } else if (triggered.contains('S002')) {
        rule('S002', 'Salinidad ligera');
      }
      if (profile?.ecThreshold != null && ec >= profile!.ecThreshold!) {
        issues.add(
          SoilIssue(
            id: 'crop-ec',
            title: 'CE alcanza el umbral de ${profile.name}',
            explanation:
                'CE del extracto saturado: $ec dS/m; umbral de referencia del cultivo: ${profile.ecThreshold} dS/m.',
            action:
                'Revisar drenaje, análisis y selección del siguiente cultivo antes de intervenir.',
            warning:
                'No comparar con CE del agua de riego o de otro método de extracción.',
            isDemo: false,
          ),
        );
      }
    }
    if (triggered.contains('S007')) {
      rule('S007', 'Materia orgánica baja');
    }
    if (triggered.contains('S009')) {
      rule(
        'S009',
        'Nitrógeno bajo',
        severity: demo && parcel.nitrogen < 25
            ? RecommendationSeverity.critical
            : RecommendationSeverity.warning,
      );
    }
    if (triggered.contains('S008')) {
      rule(
        'S008',
        'Fósforo disponible bajo',
        severity: demo && parcel.phosphorus < 25
            ? RecommendationSeverity.critical
            : RecommendationSeverity.warning,
      );
    }
    if (triggered.contains('S010')) {
      rule(
        'S010',
        'Potasio bajo',
        severity: demo && parcel.potassium < 25
            ? RecommendationSeverity.critical
            : RecommendationSeverity.warning,
      );
    }
    for (final item in [
      ('nitrógeno', nitrogen),
      ('fósforo', phosphorus),
      ('potasio', potassium),
    ]) {
      if (item.$2 == NutrientLevel.high) {
        issues.add(
          SoilIssue(
            id: 'high-${item.$1}',
            title:
                '${item.$1[0].toUpperCase()}${item.$1.substring(1)} alto según el análisis',
            explanation:
                'El nivel fue registrado como alto; no corresponde una recomendación para corregir un déficit.',
            action:
                'Revisar el informe y el manejo con asesoría local antes de añadir más nutrientes.',
            isDemo: false,
          ),
        );
      }
    }
    if (demo && moisture != null && moisture < 40) {
      issues.add(
        SoilIssue(
          id: 'demo-moisture',
          title: 'Humedad baja en la demostración',
          explanation:
              'Índice de humedad ${moisture.round()}%, bajo el umbral demostrativo de 40%. El Excel no define ese porcentaje como umbral agronómico.',
          action:
              'Revisar la medición de humedad y la textura del suelo. Si es arenoso y se confirma humedad baja, consultar la regla S011.',
          sourceRuleId: 'S011',
          isDemo: true,
          severity: moisture < 25
              ? RecommendationSeverity.critical
              : RecommendationSeverity.warning,
        ),
      );
    }
    if (!demo) {
      if (triggered.contains('S011')) {
        rule('S011', 'Humedad baja en suelo arenoso');
      } else if (analysis.moistureLow == true) {
        issues.add(
          SoilIssue(
            id: 'low-moisture',
            title: 'Humedad baja registrada',
            explanation:
                'Se indicó humedad baja, pero no se confirmó suelo arenoso.',
            action:
                'Confirmar la textura y la medición antes de elegir frecuencia y lámina de riego.',
            sourceRuleId: 'S011',
            isDemo: false,
          ),
        );
      }
      if (analysis.moistureLow == null) {
        missing.add('Falta confirmar si la humedad del suelo es baja.');
      }
      if (analysis.sandySoil == null) {
        missing.add('Falta confirmar la textura arenosa del suelo.');
      }
      if (triggered.contains('S012')) {
        rule('S012', 'Encharcamiento o napa superficial');
      }
      if (analysis.waterlogged == null) {
        missing.add('Falta confirmar el drenaje o encharcamiento.');
      }
      if (triggered.contains('S013')) {
        rule('S013', 'Antecedentes de enfermedades de suelo');
      }
      if (analysis.soilDiseaseHistory == null) {
        missing.add(
          'Falta confirmar antecedentes de enfermedades de suelo en Allium o papa.',
        );
      }
    }
    if (profile == null) {
      missing.add(
        'El cultivo ${parcel.crop} no tiene ficha en esta base. No se inventa una rotación ni rangos para él.',
      );
    }
    if (profile != null &&
        profile.classification.toLowerCase().contains('potencial')) {
      notes.add(
        '${profile.name}: presencia local por confirmar según el Excel.',
      );
    }
    if (profile != null &&
        profile.classification.toLowerCase().contains('no prioritaria')) {
      notes.add(
        '${profile.name} está fuera de la selección prioritaria del piloto de La Joya.',
      );
    }
    final rotations = <RotationCandidate>[];
    final blocked = <RotationCandidate>[];
    if (parcel.cropHistory.isEmpty) {
      missing.add(
        'Falta historial de campañas anteriores; solo se conoce el cultivo actual.',
      );
    }
    final recentHistory = parcel.cropHistory.reversed.take(3).toList();
    if (recentHistory.isNotEmpty) {
      notes.add(
        'Regla conservadora de la app: se revisan las familias de las tres campañas anteriores registradas, además del cultivo actual. No es un plazo de saneamiento validado para una enfermedad concreta.',
      );
    }
    final priorFamilies = <String>{};
    for (final name in recentHistory) {
      final crop = catalog.findCrop(name);
      if (crop == null) {
        missing.add('No se conoce la familia del cultivo histórico $name.');
      } else {
        priorFamilies.add(crop.family);
      }
    }
    if (profile != null) {
      for (final next in catalog.crops) {
        final pair = catalog.compatibilityFor(profile.id, next.id);
        final blockers = <String>[];
        final conditions = <String>[
          'Validar época, clima, agua disponible, análisis y manejo local antes de sembrar.',
          next.validation,
        ];
        final reasons = <String>[if (pair != null) pair.condition];
        if (pair == null) {
          blockers.add(
            'No existe un par de compatibilidad documentado para esta transición.',
          );
        }
        if (next.id == profile.id) {
          blockers.add('Es el mismo cultivo actual; no es una rotación.');
        } else if (next.family == profile.family) {
          blockers.add(
            'Comparte la familia ${profile.family} con el cultivo actual.',
          );
        }
        if (pair != null && pair.score == 0 && blockers.isEmpty) {
          blockers.add(pair.condition);
        }
        if (next.classification.toLowerCase().contains('no prioritaria')) {
          blockers.add(
            'No prioritaria: excluida del piloto de La Joya según el Excel.',
          );
        }
        if (priorFamilies.contains(next.family)) {
          blockers.add(
            'La familia ${next.family} aparece en las tres campañas anteriores registradas.',
          );
        }
        if (ph != null && (ph < next.phMin || ph > next.phMax)) {
          blockers.add(
            'pH ${ph.toStringAsFixed(1)} fuera del rango ${next.phMin}–${next.phMax} de ${next.name}.',
          );
        }
        if (ph == null) {
          conditions.add(
            'Falta medir pH para contrastar el rango ${next.phMin}–${next.phMax}.',
          );
        }
        if (ec != null) {
          if (next.ecThreshold == null) {
            blockers.add(
              'No hay umbral de CE documentado para comprobar compatibilidad con la CE medida ($ec dS/m).',
            );
          } else if (ec >= next.ecThreshold!) {
            blockers.add(
              'CE $ec dS/m alcanza o supera el umbral ${next.ecThreshold} dS/m del cultivo.',
            );
          }
        } else {
          conditions.add(
            'Falta CE del extracto saturado para verificar salinidad; no se confirma tolerancia con datos ausentes.',
          );
          if (next.ecThreshold == null) {
            conditions.add(
              'El Excel no aporta un umbral de CE para este cultivo.',
            );
          }
        }
        if (next.isLegume || profile.isLegume) {
          conditions.add(
            'El posible beneficio de nitrógeno depende de nodulación efectiva, fósforo suficiente, salinidad y manejo de los residuos; no se garantiza ahorro de fertilizante.',
          );
        }
        if (next.isLegume && phosphorus == NutrientLevel.low) {
          blockers.add(
            'Fósforo bajo: resolver y validar disponibilidad antes de esperar fijación eficaz de nitrógeno.',
          );
        }
        if (next.id == 'C004') {
          conditions.add(
            'Alfalfa es una fase perenne de varios años. Su demanda de agua es anual y no se suma como una campaña corta.',
          );
        }
        if (next.classification.toLowerCase().contains('potencial')) {
          conditions.add('Cultivo potencial: presencia local no confirmada.');
        }
        if (parcel.cropHistory.isEmpty) {
          conditions.add(
            'Sin historial, falta revisar familias y enfermedades de campañas anteriores.',
          );
        }
        if (pair != null && pair.observation.isNotEmpty) {
          conditions.add(pair.observation);
        }
        final candidate = RotationCandidate(
          crop: next,
          score: pair?.score ?? 0,
          level: pair?.level ?? 'Sin dato',
          reasons: reasons,
          conditions: conditions,
          blockers: blockers,
        );
        if (blockers.isEmpty) {
          rotations.add(candidate);
        } else {
          blocked.add(candidate);
        }
      }
    }
    rotations.sort((a, b) {
      var order = b.score.compareTo(a.score);
      if (order != 0) return order;
      order = a.isPotential == b.isPotential ? 0 : (a.isPotential ? 1 : -1);
      if (order != 0) return order;
      if (nitrogen == NutrientLevel.low && a.crop.isLegume != b.crop.isLegume) {
        return a.crop.isLegume ? -1 : 1;
      }
      return a.crop.name.compareTo(b.crop.name);
    });
    issues.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return CropAssessment(
      profile: profile,
      isDemo: demo,
      issues: issues,
      rotations: rotations,
      blockedRotations: blocked,
      missingData: missing.toList(),
      notes: notes,
    );
  }
}
