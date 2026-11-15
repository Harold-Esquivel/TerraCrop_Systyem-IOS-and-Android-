import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terracrop/data/agronomy_catalog.dart';

class CatalogBundle extends CachingAssetBundle {
  CatalogBundle(this.contents);
  final String contents;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    expect(key, AgronomyCatalog.assetPath);
    return contents;
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

void main() {
  final contents = File('assets/data/agronomy.json').readAsStringSync();
  Map<String, dynamic> sourceJson() =>
      jsonDecode(contents) as Map<String, dynamic>;
  final catalog = AgronomyCatalog.fromJson(sourceJson());

  test('conserva todas las tablas y las 169 parejas del Excel', () {
    expect(catalog.crops, hasLength(13));
    expect(catalog.compatibility, hasLength(169));
    expect(catalog.sequences, hasLength(3));
    expect(catalog.sequenceDetails, hasLength(12));
    expect(catalog.soilRules, hasLength(13));
    expect(catalog.microorganisms, hasLength(9));
    expect(catalog.sources, hasLength(16));
    expect(catalog.rawTables, hasLength(8));
    for (final previous in catalog.crops) {
      for (final next in catalog.crops) {
        final pair = catalog.compatibilityFor(previous.id, next.id);
        expect(pair, isNotNull, reason: '${previous.id} → ${next.id}');
        if (previous.id == next.id) expect(pair!.score, 0);
      }
    }
    expect(catalog.source['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test(
    'resuelve IDs, tildes, espacios y nombres largos sin inventar fichas',
    () {
      expect(catalog.findCrop('  MAÍZ  ')!.id, 'C003');
      expect(catalog.findCrop('Maíz (amiláceo / choclo / chala)')!.id, 'C003');
      expect(catalog.findCrop('Zea mays')!.id, 'C003');
      expect(catalog.findCrop('Pimiento/ají')!.id, 'C006');
      expect(catalog.findCrop('AJI')!.id, 'C006');
      expect(catalog.findCrop('c002')!.name, 'Papa');
      expect(catalog.findCrop('Café'), isNull);
      expect(catalog.findCrop('Palta'), isNull);
    },
  );

  test(
    'no convierte la CE desconocida en cero ni inventa ciclos de alfalfa',
    () {
      expect(catalog.findCrop('Ajo')!.ecThreshold, isNull);
      expect(catalog.findCrop('Quinua')!.ecThreshold, isNull);
      final alfalfa = catalog.findCrop('Alfalfa')!;
      expect(alfalfa.isAnnualWater, isTrue);
      expect(alfalfa.waterUnit, 'm³/ha por año');
      expect(alfalfa.periodMin, isNull);
      expect(alfalfa.periodMax, isNull);
      expect(alfalfa.periodMean, isNull);
      expect(alfalfa.periodDescription, contains('Perenne'));
      expect(catalog.findCrop('Papa')!.waterUnit, 'm³/ha por campaña');
    },
  );

  test(
    'mantiene los estados locales y distingue demanda de agua del riego',
    () {
      expect(catalog.findCrop('Cebolla')!.isConfirmed, isTrue);
      expect(catalog.findCrop('Haba')!.isPotential, isTrue);
      expect(catalog.findCrop('Arroz')!.isPriority, isFalse);
      expect(catalog.source['waterMeaning'], contains('no riego aplicado'));
      expect(catalog.notes, contains(contains('NO es el riego aplicado')));
      expect(catalog.source['nutrientUnit'], contains('P2O5'));
      expect(
        catalog.source['nutrientUnit'],
        contains('no concentraciones medidas'),
      );
      final alternative = catalog.sequences.singleWhere((s) => s.id == 'S01');
      expect(alternative.demandDifference, closeTo(-.0943396226415094, 1e-12));
      expect(alternative.limitations, contains('No incluye leguminosa'));
    },
  );

  test(
    'todas las referencias de microorganismos y campañas son resolubles',
    () {
      for (final rule in catalog.soilRules) {
        for (final id in rule.microorganismIds) {
          expect(catalog.microorganism(id), isNotNull);
        }
      }
      for (final sequence in catalog.sequences) {
        final steps = catalog.stepsForSequence(sequence.id);
        expect(steps.map((s) => s.campaign), [1, 2, 3, 4]);
        for (final step in steps) {
          expect(catalog.findCrop(step.cropId), isNotNull);
        }
        expect(
          steps.fold<double>(0, (sum, step) => sum + step.water),
          sequence.totalWater,
        );
        expect(
          steps.fold<double>(0, (sum, step) => sum + step.days),
          sequence.totalDays,
        );
      }
      expect(
        catalog.sourceById('F17')!.url,
        'https://repositorio.inia.gob.pe/',
      );
      expect(catalog.rule('S003')!.warning, contains('No recomendar yeso'));
      expect(
        catalog.microorganism('M001')!.limitations,
        contains('no sirve a cultivos no leguminosos'),
      );
    },
  );

  test(
    'rechaza una matriz incompleta o duplicada y referencias desconocidas',
    () {
      final missing = sourceJson();
      (missing['compatibility'] as List).removeLast();
      expect(() => AgronomyCatalog.fromJson(missing), throwsFormatException);
      final duplicated = sourceJson();
      final pairs = duplicated['compatibility'] as List;
      pairs[1] = pairs.first;
      expect(() => AgronomyCatalog.fromJson(duplicated), throwsFormatException);
      final unknownMicro = sourceJson();
      (unknownMicro['soilRules'] as List).first['microorganismIds'] = ['M999'];
      expect(
        () => AgronomyCatalog.fromJson(unknownMicro),
        throwsFormatException,
      );
    },
  );

  test(
    'la carga de assets prepara el catálogo compartido y conserva listas inmutables',
    () async {
      final loaded = await AgronomyCatalog.load(
        bundle: CatalogBundle(contents),
      );
      expect(identical(AgronomyCatalog.current, loaded), isTrue);
      expect(() => loaded.crops.clear(), throwsUnsupportedError);
      expect(
        () => loaded.rule('S001')!.microorganismIds.clear(),
        throwsUnsupportedError,
      );
    },
  );
}
