import 'agronomy_catalog.dart';
import 'crop_care_plan.dart';
import 'crop_recommendations.dart';
import 'crop_simulation.dart';
import 'models.dart';

/// Captures both the field data and the independent simulation settings.
class SimulationScenario {
  SimulationScenario({required Parcel source, required this.input})
    : source = Parcel.fromJson(source.toJson()) {
    if (source.id != input.parcel.id) {
      throw ArgumentError('La parcela y la simulación no coinciden.');
    }
  }
  final Parcel source;
  final SimulationInput input;
}

class ScenarioCare {
  const ScenarioCare(this.id, this.title, this.action);
  final String id, title, action;
}

class ParcelSimulationReport {
  ParcelSimulationReport._({
    required this.scenario,
    required this.result,
    required this.assessment,
    required this.currentCare,
    required this.scenarioCare,
  });
  final SimulationScenario scenario;
  final SimulationResult result;
  final CropAssessment assessment;
  final List<CropCareAction> currentCare;
  final List<ScenarioCare> scenarioCare;

  String get harvestAdvice {
    final risk = result.firstRiskDay;
    if (risk == 0) {
      return 'El cultivo parte con deterioro en la simulación. Revisa la parcela antes de aplazar la cosecha.';
    }
    if (risk != null && risk <= scenario.input.daysToHarvest) {
      return 'El deterioro simulado aparece hacia el día $risk, antes o al llegar a la cosecha prevista. Revisa el cultivo y organiza la cosecha.';
    }
    if (risk != null) {
      return 'El deterioro simulado aparece hacia el día $risk. Organiza la cosecha y comprueba el estado del cultivo en campo.';
    }
    if (scenario.input.days < scenario.input.daysToHarvest) {
      return 'El periodo termina antes de la cosecha prevista. Amplíalo para revisar lo que ocurriría hasta la cosecha.';
    }
    return 'No aparece deterioro importante durante los ${scenario.input.days} días simulados. Revisa el cultivo antes de aplazar la cosecha.';
  }

  bool get needsSoilData =>
      assessment.isDemo ||
      assessment.missingData.any(
        (item) => !item.contains('historial') && !item.contains('histórico'),
      );

  String get dataLabel =>
      assessment.isDemo ? 'Datos de ejemplo' : 'Análisis de suelo ingresado';
  String get eventsLabel => scenario.input.events.isEmpty
      ? 'Sin eventos adicionales'
      : scenario.input.events.map((event) => event.label).join(' · ');

  static ParcelSimulationReport generate(
    SimulationScenario scenario,
    AgronomyCatalog catalog,
  ) {
    final result = CropSimulation.run(scenario.input);
    final assessment = CropRecommendationEngine(
      catalog,
    ).assess(scenario.source);
    final care = buildCropCarePlan(scenario.source, assessment);
    final events = scenario.input.events;
    final future = result.points.skip(1);
    final waterlogged = scenario.source.soilAnalysis?.waterlogged == true;
    final advice = <ScenarioCare>[];
    if (future.any((point) => point.moisture > 85) &&
        (events.contains(SimulationEvent.heavyRain) ||
            events.contains(SimulationEvent.irrigation))) {
      advice.add(
        const ScenarioCare(
          'excess-water',
          'Si se acumula agua',
          'Reduce el aporte de agua y revisa el drenaje si observas encharcamiento.',
        ),
      );
    }
    if (!waterlogged &&
        future.any((point) => point.moisture < 40) &&
        (events.contains(SimulationEvent.drought) ||
            events.contains(SimulationEvent.heat))) {
      advice.add(
        const ScenarioCare(
          'dry-weather',
          'Ante sequía o calor',
          'Comprueba la humedad con más frecuencia y ajusta el riego sin encharcar.',
        ),
      );
    }
    if (events.contains(SimulationEvent.frost)) {
      advice.add(
        const ScenarioCare(
          'frost',
          'Si se prevé una helada',
          'Revisa la protección disponible para tu cultivo y coordina el manejo local.',
        ),
      );
    }
    if (events.contains(SimulationEvent.pests)) {
      advice.add(
        const ScenarioCare(
          'pests',
          'Ante presencia de plagas',
          'Inspecciona el cultivo e identifica la plaga antes de elegir un tratamiento.',
        ),
      );
    }
    if (events.contains(SimulationEvent.fertilization)) {
      advice.add(
        const ScenarioCare(
          'fertilization',
          'Antes de volver a abonar',
          'Revisa el análisis de suelo y los aportes anteriores para evitar excesos.',
        ),
      );
    }
    return ParcelSimulationReport._(
      scenario: scenario,
      result: result,
      assessment: assessment,
      currentCare: care,
      scenarioCare: List.unmodifiable(advice),
    );
  }
}

class SimulationReport {
  SimulationReport._(this.createdAt, this.parcels);
  final DateTime createdAt;
  final List<ParcelSimulationReport> parcels;
  static const notice =
      'Simulación orientativa. Confirma las condiciones en campo antes de actuar; no garantiza una fecha segura de cosecha.';

  factory SimulationReport.generate({
    required List<SimulationScenario> scenarios,
    required AgronomyCatalog catalog,
    DateTime? createdAt,
  }) {
    if (scenarios.isEmpty) {
      throw ArgumentError('Selecciona al menos una parcela.');
    }
    if (scenarios.map((scenario) => scenario.source.id).toSet().length !=
        scenarios.length) {
      throw ArgumentError('Una parcela no puede repetirse en el informe.');
    }
    return SimulationReport._(
      createdAt ?? DateTime.now(),
      List.unmodifiable(
        scenarios.map(
          (scenario) => ParcelSimulationReport.generate(scenario, catalog),
        ),
      ),
    );
  }

  String get fileName {
    String two(int value) => value.toString().padLeft(2, '0');
    final d = createdAt;
    return 'TerraCrop-SmartCycle-${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}${two(d.second)}.pdf';
  }
}
