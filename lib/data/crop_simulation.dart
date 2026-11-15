import 'dart:math' as math;

import 'models.dart';

enum SimulationEvent {
  drought,
  heat,
  heavyRain,
  frost,
  irrigation,
  fertilization,
  pests;

  String get label => switch (this) {
    drought => 'Sequía',
    heat => 'Ola de calor',
    heavyRain => 'Lluvia intensa',
    frost => 'Helada',
    irrigation => 'Riego',
    fertilization => 'Fertilización',
    pests => 'Plagas',
  };

  bool get isClimate => switch (this) {
    drought || heat || heavyRain || frost => true,
    irrigation || fertilization || pests => false,
  };

  String get description => switch (this) {
    drought => 'Reduce la humedad y aumenta el estrés del escenario.',
    heat => 'Aumenta el consumo de agua y el estrés del escenario.',
    heavyRain => 'Añade agua; el exceso puede deteriorar el índice.',
    frost => 'Reduce el índice de condición del escenario.',
    irrigation => 'Añade agua; su efecto depende de la humedad inicial.',
    fertilization => 'Aumenta el índice de nutrientes disponible del modelo.',
    pests => 'Añade deterioro y merma potencial al escenario.',
  };
}

/// Inputs to a fictional comparison, never a field recommendation.
///
/// Selected events are assumed to act every day at a constant intensity. There
/// are no live weather measurements, plant growth stages or calibrated yields.
class SimulationInput {
  SimulationInput({
    required this.parcel,
    Set<SimulationEvent> events = const {},
    this.intensity = .5,
    this.days = 30,
    this.daysToHarvest = 15,
  }) : events = Set.unmodifiable(events) {
    RangeError.checkValueInInterval(days, 1, 60, 'days');
    RangeError.checkValueInInterval(daysToHarvest, 0, 60, 'daysToHarvest');
    if (!intensity.isFinite || intensity < 0 || intensity > 1) {
      throw ArgumentError.value(
        intensity,
        'intensity',
        'Debe estar entre 0 y 1',
      );
    }
    for (final reading in [
      parcel.ph,
      parcel.moisture,
      parcel.nitrogen,
      parcel.phosphorus,
      parcel.potassium,
    ]) {
      if (!reading.isFinite) {
        throw ArgumentError('La parcela contiene una lectura no finita.');
      }
    }
  }

  final Parcel parcel;
  final Set<SimulationEvent> events;
  final double intensity;
  final int days;

  /// Entered by the user, not inferred from sensor data or crop type.
  final int daysToHarvest;
}

class SimulationPoint {
  const SimulationPoint({
    required this.day,
    required this.moisture,
    required this.health,
    required this.lossPercent,
  });

  final int day;
  final double moisture;
  final double health;
  final double lossPercent;

  /// A synthetic index, not a calibrated probability.
  double get riskPercent => 100 - health;

  bool get isAtRisk =>
      health < CropSimulation.riskHealthThreshold ||
      lossPercent >= CropSimulation.riskLossThreshold;
}

class SimulationResult {
  SimulationResult._({
    required this.input,
    required List<SimulationPoint> points,
    required List<SimulationPoint> basePoints,
  }) : points = List.unmodifiable(points),
       basePoints = List.unmodifiable(basePoints);

  final SimulationInput input;
  final List<SimulationPoint> points;
  final List<SimulationPoint> basePoints;

  double get initialHealth => points.first.health;
  double get finalHealth => points.last.health;
  double get baselineFinalHealth => basePoints.last.health;
  double get finalLossPercent => points.last.lossPercent;
  double get baselineLossPercent => basePoints.last.lossPercent;
  double get lossDifference => finalLossPercent - baselineLossPercent;
  double get conditionDifference => finalHealth - baselineFinalHealth;
  int? get firstRiskDay => _firstRiskDay(points);
  int? get baselineFirstRiskDay => _firstRiskDay(basePoints);
  int get additionalDaysInParcel =>
      math.max(0, input.days - input.daysToHarvest);
  double get averageMoisture =>
      points.fold<double>(0, (sum, p) => sum + p.moisture) / points.length;
  double get peakRiskPercent =>
      points.map((p) => p.riskPercent).reduce(math.max);

  String get summary {
    final day = firstRiskDay;
    if (day == 0) {
      return 'La parcela parte en riesgo según el umbral del modelo. '
          'Los días simulados no representan una ventana de seguridad.';
    }
    if (day == null) {
      return 'No se supera el umbral del modelo en los ${input.days} días '
          'simulados. Esto no garantiza la conservación del cultivo.';
    }
    return 'El escenario alcanza el umbral del modelo en el día $day. '
        'Es una estimación de demostración, no una fecha segura de cosecha.';
  }

  static int? _firstRiskDay(List<SimulationPoint> points) {
    for (final point in points) {
      if (point.isAtRisk) return point.day;
    }
    return null;
  }
}

/// Deterministic demonstration model with deliberately illustrative weights.
///
/// No coefficient below is agronomically calibrated. Loss is a synthetic
/// cumulative percentage of potential deterioration, not an estimate of kg,
/// commercial yield, financial loss or the probability of a real outcome.
abstract final class CropSimulation {
  static const double riskHealthThreshold = 60;
  static const double riskLossThreshold = 15;
  static const methodology =
      'Modelo heurístico de demostración. Parte del pH, humedad y nutrientes '
      'de la parcela y compara dos escenarios con el mismo horizonte y fecha '
      'de cosecha introducida: uno sin eventos y otro con los eventos elegidos. '
      'Los eventos actúan diariamente con intensidad constante. La humedad '
      'desciende gradualmente, cambia con el clima y el riego, y el déficit o '
      'exceso genera estrés. El estrés, el pH y los nutrientes cambian un índice '
      'de condición de 0 a 100. La permanencia después de la cosecha prevista '
      'añade deterioro en ambos escenarios. Se acumula un porcentaje ficticio '
      'de merma potencial. Umbral: condición menor de 60/100 o merma de al '
      'menos 15%. Los perfiles de cultivo y todos los coeficientes son '
      'ilustrativos, sin calibración de campo. No usa clima real ni garantiza '
      'cuánto tiempo puede permanecer un cultivo sin malograrse.';

  static SimulationResult run(SimulationInput input) => SimulationResult._(
    input: input,
    points: _project(input, input.events),
    basePoints: _project(input, const {}),
  );

  static List<SimulationPoint> _project(
    SimulationInput input,
    Set<SimulationEvent> events,
  ) {
    final parcel = input.parcel;
    final profile = _profile(parcel.crop);
    final intensity = input.intensity;
    double effect(SimulationEvent event) =>
        events.contains(event) ? intensity : 0;

    var moisture = _bounded(parcel.moisture);
    var nutrients = _bounded(
      (parcel.nitrogen + parcel.phosphorus + parcel.potassium) / 3,
    );
    final ph = parcel.ph.clamp(0, 14).toDouble();
    var health = _bounded(
      100 -
          (ph - 6.5).abs() * 12 -
          math.max(0, 60 - nutrients) * .45 -
          math.max(0, 45 - moisture) * .65 -
          math.max(0, moisture - 85) * .5,
    );
    // Carry the app's existing sensor alarm into day zero; never silently call
    // an already critical parcel a new period of safe storage.
    if (parcel.critical) health = math.min(health, 55);
    if (parcel.warning) health = math.min(health, 75);
    var loss = 0.0;
    final points = [
      SimulationPoint(
        day: 0,
        moisture: moisture,
        health: health,
        lossPercent: 0,
      ),
    ];
    for (var day = 1; day <= input.days; day++) {
      moisture = _bounded(
        moisture -
            .7 * profile.water -
            effect(SimulationEvent.drought) * 2 -
            effect(SimulationEvent.heat) * profile.water +
            effect(SimulationEvent.heavyRain) * 4.5 +
            effect(SimulationEvent.irrigation) * 3,
      );
      nutrients = _bounded(
        nutrients - .15 + effect(SimulationEvent.fertilization) * 1.5,
      );
      final waterStress = moisture < 40
          ? (40 - moisture) / 40 * 2
          : moisture > 85
          ? (moisture - 85) / 15 * 2
          : 0.0;
      final phStress = math.max(0, (ph - 6.5).abs() - .7) * .45;
      final nutrientStress = math.max(0, 45 - nutrients) / 45 * .7;
      final heatStress = effect(SimulationEvent.heat) * .65 * profile.heat;
      final frostStress = effect(SimulationEvent.frost) * 1.8 * profile.cold;
      final pestStress = effect(SimulationEvent.pests) * 1.3;
      final overdue = math.max(0, day - input.daysToHarvest);
      final lateStress = overdue * .08 * profile.retention;
      final recovery = moisture >= 45 && moisture <= 80 && nutrients >= 45
          ? .16 + effect(SimulationEvent.fertilization) * .22
          : 0.0;
      health = _bounded(
        health +
            recovery -
            waterStress -
            phStress -
            nutrientStress -
            heatStress -
            frostStress -
            pestStress -
            lateStress -
            effect(SimulationEvent.drought) * .25 -
            effect(SimulationEvent.heavyRain) * .2,
      );
      loss = _bounded(
        loss +
            math.max(0, 72 - health) * .026 +
            lateStress * .35 +
            pestStress * .18 +
            frostStress * .14,
      );
      points.add(
        SimulationPoint(
          day: day,
          moisture: moisture,
          health: health,
          lossPercent: loss,
        ),
      );
    }
    return points;
  }

  static double _bounded(double value) => value.clamp(0, 100).toDouble();

  // Fictional profile weights give the demo distinguishable crop scenarios.
  // These must never be presented as published crop tolerance data.
  static _DemoProfile _profile(String crop) => switch (crop) {
    'Maíz' => const _DemoProfile(water: 1.05, heat: 1, cold: 1.1, retention: 1),
    'Papa' => const _DemoProfile(water: 1, heat: 1.15, cold: 1, retention: .9),
    'Quinua' => const _DemoProfile(
      water: .85,
      heat: .9,
      cold: .85,
      retention: 1,
    ),
    'Café' => const _DemoProfile(
      water: 1.1,
      heat: 1,
      cold: 1.2,
      retention: 1.1,
    ),
    'Arroz' => const _DemoProfile(
      water: 1.15,
      heat: 1,
      cold: 1.1,
      retention: 1,
    ),
    'Palta' => const _DemoProfile(
      water: 1.1,
      heat: 1.05,
      cold: 1.2,
      retention: 1.2,
    ),
    'Tomate' => const _DemoProfile(
      water: 1.05,
      heat: 1.1,
      cold: 1.15,
      retention: 1.3,
    ),
    _ => const _DemoProfile(water: 1, heat: 1, cold: 1, retention: 1),
  };
}

class _DemoProfile {
  const _DemoProfile({
    required this.water,
    required this.heat,
    required this.cold,
    required this.retention,
  });

  final double water;
  final double heat;
  final double cold;
  final double retention;
}
