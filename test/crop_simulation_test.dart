import 'package:flutter_test/flutter_test.dart';
import 'package:terracrop/data/crop_simulation.dart';
import 'package:terracrop/data/models.dart';

void main() {
  final healthy = demoParcels().first;

  test('sin eventos se obtiene exactamente la comparación de control', () {
    final result = CropSimulation.run(SimulationInput(parcel: healthy));
    expect(result.points, hasLength(31));
    expect(result.points.first.day, 0);
    expect(result.points.last.day, 30);
    for (var i = 0; i < result.points.length; i++) {
      expect(result.points[i].health, result.basePoints[i].health);
      expect(result.points[i].moisture, result.basePoints[i].moisture);
      expect(result.points[i].lossPercent, result.basePoints[i].lossPercent);
    }
    expect(result.lossDifference, 0);
    expect(result.conditionDifference, 0);
  });

  test('sequía y calor aumentan el deterioro frente al control', () {
    final result = CropSimulation.run(
      SimulationInput(
        parcel: healthy,
        events: {SimulationEvent.drought, SimulationEvent.heat},
        intensity: .8,
        days: 30,
        daysToHarvest: 30,
      ),
    );
    expect(
      result.points.last.moisture,
      lessThan(result.basePoints.last.moisture),
    );
    expect(result.finalHealth, lessThan(result.baselineFinalHealth));
    expect(result.lossDifference, greaterThan(0));
    expect(result.firstRiskDay, isNotNull);
  });

  test('el riego mitiga un escenario de sequía sin cambiar la parcela', () {
    final original = healthy.toJson().toString();
    SimulationResult run(Set<SimulationEvent> events) => CropSimulation.run(
      SimulationInput(
        parcel: healthy,
        events: events,
        intensity: .6,
        days: 45,
        daysToHarvest: 45,
      ),
    );
    final drought = run({SimulationEvent.drought});
    final irrigated = run({
      SimulationEvent.drought,
      SimulationEvent.irrigation,
    });
    expect(irrigated.averageMoisture, greaterThan(drought.averageMoisture));
    expect(irrigated.finalHealth, greaterThan(drought.finalHealth));
    expect(irrigated.finalLossPercent, lessThan(drought.finalLossPercent));
    expect(healthy.toJson().toString(), original);
  });

  test('dejar más días tras la cosecha prevista eleva la merma del modelo', () {
    SimulationResult run(int harvest) => CropSimulation.run(
      SimulationInput(parcel: healthy, days: 40, daysToHarvest: harvest),
    );
    final waiting = run(0);
    final notReady = run(40);
    expect(waiting.additionalDaysInParcel, 40);
    expect(notReady.additionalDaysInParcel, 0);
    expect(waiting.finalHealth, lessThan(notReady.finalHealth));
    expect(waiting.finalLossPercent, greaterThan(notReady.finalLossPercent));
  });

  test('una parcela crítica ya supera el umbral en el día cero', () {
    final result = CropSimulation.run(
      SimulationInput(parcel: demoParcels()[1], daysToHarvest: 0),
    );
    expect(result.firstRiskDay, 0);
    expect(result.baselineFirstRiskDay, 0);
    expect(result.summary, contains('no representan una ventana de seguridad'));
  });

  test('los límites y la merma acumulada se conservan en eventos extremos', () {
    final result = CropSimulation.run(
      SimulationInput(
        parcel: healthy.copyWith(moisture: 100, ph: 2, nitrogen: 0),
        events: SimulationEvent.values.toSet(),
        intensity: 1,
        days: 60,
        daysToHarvest: 0,
      ),
    );
    expect(result.points, hasLength(61));
    var previousLoss = 0.0;
    for (final point in [...result.basePoints, ...result.points]) {
      expect(point.health.isFinite, isTrue);
      expect(point.health, inInclusiveRange(0, 100));
      expect(point.moisture, inInclusiveRange(0, 100));
      expect(point.lossPercent, inInclusiveRange(0, 100));
      expect(point.riskPercent, inInclusiveRange(0, 100));
    }
    for (final point in result.points) {
      expect(point.lossPercent, greaterThanOrEqualTo(previousLoss));
      previousLoss = point.lossPercent;
    }
  });

  test(
    'intensidad cero neutraliza los eventos y los resultados son inmutables',
    () {
      final events = {SimulationEvent.pests, SimulationEvent.frost};
      final input = SimulationInput(
        parcel: healthy,
        events: events,
        intensity: 0,
      );
      events.clear();
      final result = CropSimulation.run(input);
      expect(input.events, hasLength(2));
      expect(result.finalHealth, result.baselineFinalHealth);
      expect(result.lossDifference, 0);
      expect(() => input.events.clear(), throwsUnsupportedError);
      expect(() => result.points.clear(), throwsUnsupportedError);
      expect(() => result.basePoints.clear(), throwsUnsupportedError);
    },
  );

  test('más intensidad de plagas no mejora el resultado de la comparación', () {
    SimulationResult run(double intensity) => CropSimulation.run(
      SimulationInput(
        parcel: healthy,
        events: {SimulationEvent.pests},
        intensity: intensity,
        daysToHarvest: 30,
      ),
    );
    final mild = run(.2);
    final severe = run(.9);
    expect(severe.finalHealth, lessThan(mild.finalHealth));
    expect(severe.finalLossPercent, greaterThan(mild.finalLossPercent));
  });

  test(
    'lluvia excesiva y helada deterioran sus escenarios frente al control',
    () {
      for (final event in [SimulationEvent.heavyRain, SimulationEvent.frost]) {
        final result = CropSimulation.run(
          SimulationInput(
            parcel: healthy.copyWith(moisture: 80),
            events: {event},
            intensity: .9,
            daysToHarvest: 30,
          ),
        );
        expect(
          result.finalHealth,
          lessThan(result.baselineFinalHealth),
          reason: event.label,
        );
        expect(
          result.finalLossPercent,
          greaterThan(result.baselineLossPercent),
          reason: event.label,
        );
      }
    },
  );

  test('fertilización mejora la comparación con nutrientes bajos', () {
    final result = CropSimulation.run(
      SimulationInput(
        parcel: healthy.copyWith(nitrogen: 20, phosphorus: 20, potassium: 20),
        events: {SimulationEvent.fertilization},
        intensity: .9,
        daysToHarvest: 30,
      ),
    );
    expect(result.finalHealth, greaterThan(result.baselineFinalHealth));
    expect(result.finalLossPercent, lessThan(result.baselineLossPercent));
    // Recovery does not erase that this parcel was already at risk on day zero.
    expect(result.firstRiskDay, 0);
  });

  test('rechaza horizontes, fechas, intensidades y sensores no válidos', () {
    expect(() => SimulationInput(parcel: healthy, days: 0), throwsRangeError);
    expect(() => SimulationInput(parcel: healthy, days: 61), throwsRangeError);
    expect(
      () => SimulationInput(parcel: healthy, daysToHarvest: -1),
      throwsRangeError,
    );
    expect(
      () => SimulationInput(parcel: healthy, daysToHarvest: 61),
      throwsRangeError,
    );
    for (final intensity in [-.1, 1.1, double.nan, double.infinity]) {
      expect(
        () => SimulationInput(parcel: healthy, intensity: intensity),
        throwsArgumentError,
      );
    }
    expect(
      () => SimulationInput(parcel: healthy.copyWith(moisture: double.nan)),
      throwsArgumentError,
    );
  });
}
