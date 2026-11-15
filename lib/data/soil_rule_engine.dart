import 'agronomy_catalog.dart';
import 'models.dart';

enum RuleState { triggered, notTriggered, unavailable }

class SoilRuleEvaluation {
  const SoilRuleEvaluation({
    required this.rule,
    required this.state,
    required this.operator,
    required this.unit,
    required this.method,
    required this.value,
    required this.sourceIds,
    required this.missingData,
    required this.sampledAt,
  });
  final SoilRule rule;
  final RuleState state;
  final String operator, unit, method;
  final String? value;
  final List<String> sourceIds, missingData;
  final DateTime? sampledAt;
}

/// Explicit predicates transcribed from Suelo Reglas. Missing measurements
/// remain unavailable; demo indices never enter this engine.
class SoilRuleEngine {
  const SoilRuleEngine(this.catalog);
  final AgronomyCatalog catalog;

  List<SoilRuleEvaluation> evaluate(SoilAnalysis? analysis) {
    final a = analysis ?? const SoilAnalysis();
    double? valid(double? v, double max) =>
        v != null && v.isFinite && v >= 0 && v <= max ? v : null;
    final ph = valid(a.ph, 14),
        ec = valid(a.ec, 1000),
        mo = valid(a.organicMatter, 100);
    return List.unmodifiable(
      catalog.soilRules.map((rule) {
        bool? condition;
        String? value;
        var unit = '', method = '', operator = rule.condition;
        var sources = <String>['F17'];
        switch (rule.id) {
          case 'S001':
          case 'S002':
            condition = ec == null
                ? null
                : rule.id == 'S001'
                ? ec >= 4
                : ec >= 2 && ec < 4;
            value = ec?.toString();
            unit = 'dS/m';
            method = 'CE del extracto saturado';
            sources = ['F02', 'F16'];
            operator = rule.id == 'S001' ? '>= 4' : '>= 2 y < 4';
          case 'S003':
          case 'S004':
          case 'S005':
          case 'S006':
            condition = ph == null
                ? null
                : switch (rule.id) {
                    'S003' => ph >= 8.5,
                    'S004' => ph >= 7.5 && ph < 8.5,
                    'S005' => ph >= 6 && ph < 7.5,
                    _ => ph < 5.5,
                  };
            value = ph?.toString();
            method = 'pH del análisis ingresado; protocolo no registrado';
            operator = switch (rule.id) {
              'S003' => '>= 8.5',
              'S004' => '>= 7.5 y < 8.5',
              'S005' => '>= 6 y < 7.5',
              _ => '< 5.5',
            };
          case 'S007':
            condition = mo == null ? null : mo < 2;
            value = mo?.toString();
            unit = '%';
            method = 'Materia orgánica según análisis';
          case 'S008':
          case 'S009':
          case 'S010':
            final level = switch (rule.id) {
              'S008' => a.phosphorus,
              'S009' => a.nitrogen,
              _ => a.potassium,
            };
            condition = level == NutrientLevel.unknown
                ? null
                : level == NutrientLevel.low;
            value = level == NutrientLevel.unknown ? null : level.name;
            unit = 'categoría';
            method =
                'Interpretación del laboratorio ingresada, no concentración';
          case 'S011':
            condition = a.moistureLow == false || a.sandySoil == false
                ? false
                : a.moistureLow == null || a.sandySoil == null
                ? null
                : true;
            value = condition == null
                ? null
                : 'Humedad baja: ${a.moistureLow}; suelo arenoso: ${a.sandySoil}';
            method = 'Observación local y textura declaradas';
            sources = ['F01', 'F17'];
          case 'S012':
            condition = a.waterlogged;
            value = condition?.toString();
            method = 'Observación local: encharcamiento o napa';
          case 'S013':
            condition = a.soilDiseaseHistory;
            value = condition?.toString();
            method =
                'Antecedente declarado de enfermedad de suelo en Allium o papa';
        }
        return SoilRuleEvaluation(
          rule: rule,
          state: condition == null
              ? RuleState.unavailable
              : condition
              ? RuleState.triggered
              : RuleState.notTriggered,
          operator: operator,
          unit: unit,
          method: method,
          value: value,
          sourceIds: sources,
          missingData: [
            if (condition == null)
              'Falta ${rule.parameter}: ${rule.condition}.',
            if (a.sampledAt == null)
              'Fecha de análisis u observación no registrada.',
          ],
          sampledAt: a.sampledAt,
        );
      }),
    );
  }
}
