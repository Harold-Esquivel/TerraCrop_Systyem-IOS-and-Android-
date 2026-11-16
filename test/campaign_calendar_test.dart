import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/campaign_engine.dart';
import 'package:terracrop/data/environment_repository.dart';
import 'package:terracrop/data/models.dart';

void main() {
  final catalog = AgronomyCatalog.fromJson(
    jsonDecode(File('assets/data/agronomy.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final environment = EnvironmentRepository.fromJson(
    jsonDecode(File('assets/data/environment.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final engine = CampaignEngine(catalog, environment);

  CampaignEvaluation evaluate(String crop, int month) => engine.evaluate(
    CampaignInput(
      parcel: demoParcels().first,
      previousCrop: 'Papa',
      cropId: crop,
      start: DateTime.utc(2027, month),
      availableDays: 200,
    ),
  );

  test('el calendario cambia el aviso según el mes sin prometer aptitud', () {
    final inside = evaluate(
      'C014',
      8,
    ).alerts.singleWhere((a) => a.id == 'sowing-window');
    final outside = evaluate(
      'C014',
      2,
    ).alerts.singleWhere((a) => a.id == 'sowing-window');
    expect(inside.level, AttentionLevel.information);
    expect(outside.level, AttentionLevel.review);
    expect(inside.explanation, contains('no garantiza'));
    expect(inside.references, contains('Calendario La Joya C014'));
  });

  test('una ventana por confirmar permanece desconocida', () {
    final result = evaluate('C005', 8);
    expect(result.alerts.any((a) => a.id == 'sowing-window'), isFalse);
    expect(
      result.missingData,
      contains(contains('Ventana local de siembra de Zapallo por confirmar')),
    );
  });

  test('muestra la revisión pendiente del ciclo sin sustituir su duración', () {
    final result = evaluate('C001', 2);
    expect(result.alerts.any((a) => a.id == 'data-review-R01'), isTrue);
    expect(result.crop.periodMin, 150);
    expect(
      result.alerts.singleWhere((a) => a.id == 'data-review-R01').level,
      AttentionLevel.review,
    );
  });
}
