import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terracrop/data/agronomy_catalog.dart';
import 'package:terracrop/data/crop_recommendations.dart';
import 'package:terracrop/data/models.dart';

void main() {
  late AgronomyCatalog catalog;
  late CropRecommendationEngine engine;
  late Parcel healthy;
  setUpAll(() {
    catalog = AgronomyCatalog.fromJson(
      jsonDecode(File('assets/data/agronomy.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    engine = CropRecommendationEngine(catalog);
  });
  setUp(() {
    healthy = demoParcels().first.copyWith(
      ph: 6.5,
      moisture: 68,
      nitrogen: 70,
      phosphorus: 70,
      potassium: 70,
    );
  });
  Set<String> ids(CropAssessment result) =>
      result.issues.map((i) => i.id).toSet();
  CropAssessment measured(SoilAnalysis analysis, {String crop = 'Maíz'}) =>
      engine.assess(healthy.copyWith(crop: crop, soilAnalysis: analysis));

  test('condiciones de demostración saludables no inventan déficits', () {
    final result = engine.assess(healthy);
    expect(result.isDemo, isTrue);
    expect(result.hasDeficits, isFalse);
    expect(result.missingData, contains(contains('historial')));
    expect(result.notes.join(' '), contains('no son concentraciones medidas'));
  });

  test('pH bajo y alto se diagnostican sin inventar nutrientes bajos', () {
    for (final ph in [5.3, 5.8, 7.5, 8.0, 8.5]) {
      final result = engine.assess(healthy.copyWith(ph: ph));
      expect(result.issues, isNotEmpty, reason: 'pH $ph');
      expect(ids(result).intersection({'S008', 'S009', 'S010'}), isEmpty);
    }
  });

  test('el rango de pH pertenece al cultivo, no a un intervalo universal', () {
    expect(ids(engine.assess(healthy.copyWith(ph: 5.8))), contains('crop-ph'));
    final potato = engine.assess(healthy.copyWith(crop: 'Papa', ph: 5.8));
    expect(ids(potato), isNot(contains('crop-ph')));
    expect(potato.hasDeficits, isFalse);
  });

  test('los límites de pH no duplican reglas globales contiguas', () {
    expect(ids(engine.assess(healthy.copyWith(ph: 7.5))), contains('S004'));
    final veryHigh = ids(engine.assess(healthy.copyWith(ph: 8.5)));
    expect(veryHigh, contains('S003'));
    expect(veryHigh, isNot(contains('S004')));
    expect(
      ids(engine.assess(healthy.copyWith(crop: 'Papa', ph: 5.5))),
      isNot(contains('S006')),
    );
    expect(
      ids(engine.assess(healthy.copyWith(crop: 'Papa', ph: 5.49))),
      contains('S006'),
    );
  });

  test('identifica N, P y K por separado y conserva la acción del Excel', () {
    final scenarios = [
      (healthy.copyWith(nitrogen: 20), 'S009', 'Nitrógeno'),
      (healthy.copyWith(phosphorus: 20), 'S008', 'Fósforo'),
      (healthy.copyWith(potassium: 20), 'S010', 'Potasio'),
    ];
    for (final (parcel, ruleId, nutrient) in scenarios) {
      final result = engine.assess(parcel);
      final issue = result.issues.singleWhere((i) => i.id == ruleId);
      expect(issue.title, contains(nutrient));
      expect(
        issue.action,
        catalog.soilRules.singleWhere((r) => r.id == ruleId).action,
      );
      expect(issue.isDemo, isTrue);
      expect(ids(result), isNot(contains('crop-ph')));
      expect(
        result.issues.map((i) => i.action).join(' '),
        isNot(contains('Corrige el pH')),
      );
    }
  });

  test('los índices de demostración en 40 no son déficits; debajo sí', () {
    expect(
      ids(engine.assess(healthy.copyWith(nitrogen: 40))),
      isNot(contains('S009')),
    );
    expect(
      ids(engine.assess(healthy.copyWith(nitrogen: 39.9))),
      contains('S009'),
    );
    final critical = engine.assess(healthy.copyWith(nitrogen: 24.9));
    expect(
      critical.issues.singleWhere((i) => i.id == 'S009').severity,
      RecommendationSeverity.critical,
    );
    final attention = engine.assess(healthy.copyWith(nitrogen: 25));
    expect(
      attention.issues.singleWhere((i) => i.id == 'S009').severity,
      RecommendationSeverity.warning,
    );
  });

  test(
    'informa todas las carencias simultáneas sin ocultarlas por prioridad',
    () {
      final result = engine.assess(
        healthy.copyWith(
          ph: 5.3,
          moisture: 20,
          nitrogen: 20,
          phosphorus: 20,
          potassium: 20,
        ),
      );
      expect(
        ids(result),
        containsAll({'S006', 'demo-moisture', 'S009', 'S008', 'S010'}),
      );
      expect(result.status, 'En riesgo');
    },
  );

  test('un análisis real incompleto no hereda lecturas demostrativas', () {
    final parcel = healthy.copyWith(
      ph: 3,
      moisture: 0,
      nitrogen: 0,
      phosphorus: 0,
      potassium: 0,
      soilAnalysis: const SoilAnalysis(),
    );
    final result = engine.assess(parcel);
    expect(result.isDemo, isFalse);
    expect(result.issues, isEmpty);
    expect(result.status, 'Datos por completar');
    final missing = result.missingData.join(' ');
    for (final parameter in [
      'pH',
      'nitrógeno',
      'fósforo',
      'potasio',
      'CE',
      'materia orgánica',
    ]) {
      expect(missing, contains(parameter));
    }
  });

  test('niveles de laboratorio bajos activan tres acciones independientes', () {
    final result = measured(
      const SoilAnalysis(
        ph: 6.5,
        nitrogen: NutrientLevel.low,
        phosphorus: NutrientLevel.low,
        potassium: NutrientLevel.low,
      ),
    );
    expect(ids(result), containsAll({'S009', 'S008', 'S010'}));
    expect(result.issues.every((i) => !i.isDemo), isTrue);
    expect(result.issues.any((i) => i.id == 'crop-ph'), isFalse);
  });

  test(
    'niveles altos no se tratan como carencias ni recomiendan micorrizas con P alto',
    () {
      final result = measured(
        const SoilAnalysis(
          ph: 6.5,
          organicMatter: 1,
          nitrogen: NutrientLevel.high,
          phosphorus: NutrientLevel.high,
          potassium: NutrientLevel.high,
        ),
      );
      expect(ids(result).intersection({'S009', 'S008', 'S010'}), isEmpty);
      expect(result.issues.where((i) => i.id.startsWith('high-')).length, 3);
      expect(
        result.issues.expand((i) => i.microorganismIds),
        isNot(contains('M006')),
      );
    },
  );

  test('salinidad respeta límites 2 y 4 sin duplicar los intervalos', () {
    expect(
      ids(measured(const SoilAnalysis(ec: 1.99))),
      isNot(contains('S002')),
    );
    expect(ids(measured(const SoilAnalysis(ec: 2))), contains('S002'));
    final high = ids(measured(const SoilAnalysis(ec: 4)));
    expect(high, contains('S001'));
    expect(high, isNot(contains('S002')));
  });

  test('detecta el umbral específico de un cultivo sensible antes de CE 2', () {
    final result = measured(const SoilAnalysis(ec: 1), crop: 'Frijol');
    expect(ids(result), contains('crop-ec'));
    expect(ids(result), isNot(contains('S002')));
    expect(
      result.issues.singleWhere((i) => i.id == 'crop-ec').warning,
      contains('agua de riego'),
    );
  });

  test('pH alto no diagnostica sodicidad y exige PSI/RAS antes de yeso', () {
    final result = measured(const SoilAnalysis(ph: 8.5));
    final issue = result.issues.singleWhere((i) => i.id == 'S003');
    expect(issue.explanation, contains('NO demuestra suelo sódico'));
    expect(
      issue.action,
      allOf(contains('PSI'), contains('RAS'), contains('antes')),
    );
    expect(issue.warning, contains('No recomendar yeso'));
  });

  test('materia orgánica menor de 2 activa S007; en 2 no', () {
    expect(
      ids(measured(const SoilAnalysis(organicMatter: 1.99))),
      contains('S007'),
    );
    expect(
      ids(measured(const SoilAnalysis(organicMatter: 2))),
      isNot(contains('S007')),
    );
  });

  test('S011 requiere humedad baja y textura arenosa confirmadas', () {
    expect(
      ids(measured(const SoilAnalysis(moistureLow: true, sandySoil: true))),
      contains('S011'),
    );
    final unknownTexture = measured(const SoilAnalysis(moistureLow: true));
    expect(ids(unknownTexture), isNot(contains('S011')));
    expect(ids(unknownTexture), contains('low-moisture'));
    expect(
      ids(measured(const SoilAnalysis(sandySoil: true, moistureLow: false))),
      isNot(contains('S011')),
    );
  });

  test('drenaje e historial sanitario producen reglas independientes', () {
    final result = measured(
      const SoilAnalysis(waterlogged: true, soilDiseaseHistory: true),
      crop: 'Papa',
    );
    expect(ids(result), containsAll({'S012', 'S013'}));
  });

  test(
    'rizobios no se recomiendan directamente a un cultivo no leguminoso',
    () {
      final maize = engine.assess(healthy.copyWith(nitrogen: 20));
      expect(
        maize.issues.expand((i) => i.microorganismIds),
        isNot(contains('M001')),
      );
      final bean = measured(
        const SoilAnalysis(ph: 6.5, ec: .5, nitrogen: NutrientLevel.low),
        crop: 'Frijol',
      );
      expect(
        bean.issues.singleWhere((i) => i.id == 'S009').microorganismIds,
        contains('M001'),
      );
      final acidicBean = measured(
        const SoilAnalysis(ph: 5.3, nitrogen: NutrientLevel.low),
        crop: 'Frijol',
      );
      expect(
        acidicBean.issues.expand((i) => i.microorganismIds),
        isNot(contains('M001')),
      );
    },
  );

  test('oxidantes de azufre requieren pH alto conocido', () {
    final high = measured(const SoilAnalysis(ph: 8));
    expect(high.issues.expand((i) => i.microorganismIds), contains('M007'));
    final normal = measured(
      const SoilAnalysis(ph: 6.5, nitrogen: NutrientLevel.low),
    );
    expect(
      normal.issues.expand((i) => i.microorganismIds),
      isNot(contains('M007')),
    );
  });

  test('M008 se limita a los cultivos descritos en el Excel', () {
    final maize = measured(const SoilAnalysis(ph: 6.5, ec: 3));
    expect(maize.issues.expand((i) => i.microorganismIds), contains('M008'));
    for (final crop in ['Frijol', 'Haba', 'Arveja', 'Café']) {
      final result = measured(const SoilAnalysis(ph: 6.5, ec: 3), crop: crop);
      expect(
        result.issues.expand((i) => i.microorganismIds),
        isNot(contains('M008')),
        reason: crop,
      );
    }
  });

  test(
    'rotaciones de los 13 cultivos nunca aceptan mismo cultivo o familia',
    () {
      for (final current in catalog.crops) {
        final result = engine.assess(
          healthy.copyWith(
            crop: current.name,
            ph: (current.phMin + current.phMax) / 2,
          ),
        );
        for (final candidate in result.rotations) {
          expect(candidate.crop.id, isNot(current.id));
          expect(candidate.crop.family, isNot(current.family));
          expect(candidate.crop.id, isNot('C013'));
          expect(
            candidate.score,
            catalog.compatibilityFor(current.id, candidate.crop.id)!.score,
          );
          expect(candidate.blockers, isEmpty);
        }
        expect(
          result.blockedRotations.any((c) => c.crop.id == current.id),
          isTrue,
        );
      }
    },
  );

  test(
    'Papa bloquea Tomate y Pimiento por familia y Arroz por pertinencia',
    () {
      final result = engine.assess(healthy.copyWith(crop: 'Papa'));
      expect(
        result.blockedRotations
            .where((c) => ['C006', 'C012', 'C013'].contains(c.crop.id))
            .length,
        3,
      );
      expect(result.rotations.any((c) => c.crop.id == 'C003'), isTrue);
    },
  );

  test(
    'familias recientes bloquean la repetición sin inventar un historial',
    () {
      final result = engine.assess(healthy.copyWith(cropHistory: ['Cebolla']));
      expect(
        result.blockedRotations
            .singleWhere((c) => c.crop.id == 'C007')
            .blockers
            .join(' '),
        contains('campañas anteriores'),
      );
      expect(result.rotations.any((c) => c.crop.id == 'C001'), isFalse);
      final missing = engine.assess(
        healthy.copyWith(cropHistory: ['Cultivo desconocido']),
      );
      expect(
        missing.missingData.join(' '),
        contains('familia del cultivo histórico'),
      );
    },
  );

  test(
    'la ventana conservadora del historial se limita a tres campañas previas',
    () {
      final result = engine.assess(
        healthy.copyWith(cropHistory: ['Cebolla', 'Papa', 'Frijol', 'Quinua']),
      );
      expect(result.rotations.any((c) => c.crop.id == 'C001'), isTrue);
      expect(result.notes.join(' '), contains('tres campañas'));
    },
  );

  test(
    'CE al umbral bloquea candidato y falta de umbral no se inventa tolerancia',
    () {
      final result = measured(const SoilAnalysis(ph: 6.5, ec: 1.7));
      expect(
        result.blockedRotations
            .singleWhere((c) => c.crop.id == 'C002')
            .blockers
            .join(' '),
        contains('CE'),
      );
      expect(
        result.blockedRotations
            .singleWhere((c) => c.crop.id == 'C011')
            .blockers
            .join(' '),
        contains('No hay umbral'),
      );
      expect(result.rotations.any((c) => c.crop.id == 'C005'), isTrue);
    },
  );

  test(
    'CE alta no convierte quinua sin umbral numérico en una opción segura',
    () {
      final result = measured(const SoilAnalysis(ph: 6.5, ec: 5));
      expect(result.rotations, isEmpty);
      expect(
        result.blockedRotations
            .singleWhere((c) => c.crop.id == 'C011')
            .crop
            .ecThreshold,
        isNull,
      );
    },
  );

  test(
    'S001 conserva la referencia pero aclara que CE 5 bloquea quinua y alfalfa',
    () {
      final result = measured(const SoilAnalysis(ph: 6.5, ec: 5));
      final issue = result.issues.singleWhere((i) => i.id == 'S001');
      expect(issue.action, contains('Referencia general del Excel'));
      expect(issue.action, contains(catalog.rule('S001')!.action));
      expect(
        issue.warning.toLowerCase(),
        allOf(
          contains('no confirma'),
          contains('quinua'),
          contains('alfalfa'),
          contains('5.0 ds/m'),
          contains('umbral'),
        ),
      );
      for (final cropId in ['C011', 'C004']) {
        expect(result.rotations.any((c) => c.crop.id == cropId), isFalse);
        expect(
          result.blockedRotations
              .singleWhere((c) => c.crop.id == cropId)
              .blockers,
          isNotEmpty,
        );
      }
      final light = measured(const SoilAnalysis(ph: 6.5, ec: 2.5));
      expect(
        light.issues.singleWhere((i) => i.id == 'S002').action,
        contains('Referencia general del Excel'),
      );
      expect(
        light.issues.singleWhere((i) => i.id == 'S002').warning,
        contains('opciones de rotación'),
      );
    },
  );

  test(
    'beneficio de leguminosas está condicionado y no modifica el puntaje Excel',
    () {
      final bean = engine.assess(healthy.copyWith(crop: 'Frijol'));
      final maize = bean.rotations.singleWhere((c) => c.crop.id == 'C003');
      expect(maize.score, 3);
      expect(
        maize.conditions.join(' '),
        allOf(contains('nodulación'), contains('no se garantiza ahorro')),
      );
      final poorPhosphorus = engine.assess(
        healthy.copyWith(nitrogen: 20, phosphorus: 20),
      );
      expect(poorPhosphorus.rotations.any((c) => c.crop.isLegume), isFalse);
      expect(
        poorPhosphorus.blockedRotations
            .where((c) => c.crop.isLegume)
            .every((c) => c.blockers.join(' ').contains('Fósforo')),
        isTrue,
      );
    },
  );

  test('cultivos potenciales y alfalfa conservan sus limitaciones', () {
    final result = engine.assess(healthy);
    final faba = result.rotations.singleWhere((c) => c.crop.id == 'C009');
    expect(faba.isPotential, isTrue);
    expect(
      faba.conditions.join(' '),
      contains('presencia local no confirmada'),
    );
    final alfalfa = result.rotations.singleWhere((c) => c.crop.id == 'C004');
    expect(
      alfalfa.conditions.join(' '),
      allOf(contains('anual'), contains('varios años')),
    );
    expect(alfalfa.crop.periodMean, isNull);
  });

  test(
    'un cultivo sin ficha conserva datos y pide información, sin inventar rotación',
    () {
      final result = engine.assess(healthy.copyWith(crop: 'Café'));
      expect(result.profile, isNull);
      expect(result.rotations, isEmpty);
      expect(result.missingData.join(' '), contains('no tiene ficha'));
    },
  );

  test('lecturas no finitas se señalan como faltantes y no producen dosis', () {
    final result = engine.assess(
      healthy.copyWith(ph: double.nan, nitrogen: double.infinity),
    );
    expect(result.missingData.join(' '), contains('valor inválido'));
    expect(ids(result), isNot(contains('S009')));
    expect(
      result.rotations.every(
        (r) => r.conditions.join(' ').contains('Falta medir pH'),
      ),
      isTrue,
    );
  });

  test(
    'evaluar no modifica parcela ni historial y protege listas resultantes',
    () {
      final parcel = healthy.copyWith(cropHistory: ['Cebolla']);
      final before = jsonEncode(parcel.toJson());
      final result = engine.assess(parcel);
      expect(jsonEncode(parcel.toJson()), before);
      expect(() => result.notes.clear(), throwsUnsupportedError);
      expect(() => result.rotations.clear(), throwsUnsupportedError);
      expect(
        () => result.blockedRotations.first.blockers.clear(),
        throwsUnsupportedError,
      );
    },
  );
}
