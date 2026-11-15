import 'dart:convert';

import 'package:flutter/services.dart';

/// Reference knowledge supplied by the user for La Joya, Arequipa.
/// Classification and validation notes describe the workbook's assertions;
/// they are not a claim of independent verification or current local stock.
class AgronomyCatalog {
  AgronomyCatalog._({
    required this.source,
    required this.crops,
    required this.compatibility,
    required this.sequences,
    required this.sequenceDetails,
    required this.soilRules,
    required this.microorganisms,
    required this.sources,
    required this.notes,
    required this.sequenceNotes,
    required this.rawTables,
  });

  static AgronomyCatalog? _current;
  static AgronomyCatalog? get current => _current;
  static const assetPath = 'assets/data/agronomy.json';

  static Future<AgronomyCatalog> load({AssetBundle? bundle}) async {
    if (bundle == null && _current != null) return _current!;
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    final catalog = AgronomyCatalog.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _current = catalog;
    return catalog;
  }

  factory AgronomyCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Versión de base agronómica no compatible');
    }
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) parse) =>
        List.unmodifiable(
          (json[key] as List).map(
            (item) => parse(Map<String, dynamic>.from(item as Map)),
          ),
        );
    final catalog = AgronomyCatalog._(
      source: Map.unmodifiable(
        Map<String, dynamic>.from(json['source'] as Map),
      ),
      crops: rows('crops', CropProfile.fromJson),
      compatibility: rows('compatibility', CropCompatibility.fromJson),
      sequences: rows('sequences', RotationSequence.fromJson),
      sequenceDetails: rows('sequenceDetails', RotationStep.fromJson),
      soilRules: rows('soilRules', SoilRule.fromJson),
      microorganisms: rows('microorganisms', MicroorganismProfile.fromJson),
      sources: rows('sources', AgronomySource.fromJson),
      notes: List.unmodifiable((json['notes'] as List).cast<String>()),
      sequenceNotes: List.unmodifiable(
        (json['sequenceNotes'] as List).cast<String>(),
      ),
      rawTables: List.unmodifiable(
        (json['rawTables'] as List).map(
          (row) => Map<String, dynamic>.unmodifiable(
            Map<String, dynamic>.from(row as Map),
          ),
        ),
      ),
    );
    catalog._validate();
    return catalog;
  }

  final Map<String, dynamic> source;
  final List<CropProfile> crops;
  final List<CropCompatibility> compatibility;
  final List<RotationSequence> sequences;
  final List<RotationStep> sequenceDetails;
  final List<SoilRule> soilRules;
  final List<MicroorganismProfile> microorganisms;
  final List<AgronomySource> sources;
  final List<String> notes;
  final List<String> sequenceNotes;
  final List<Map<String, dynamic>> rawTables;

  CropProfile? findCrop(String nameOrId) {
    final name = normalizeName(nameOrId);
    const aliases = <String, String>{
      'maiz amilaceo choclo chala': 'C003',
      'maiz amilaceo': 'C003',
      'maiz choclo': 'C003',
      'maiz chala': 'C003',
      'choclo': 'C003',
      'pimiento': 'C006',
      'aji': 'C006',
      'pimiento aji': 'C006',
    };
    final alias = aliases[name];
    for (final crop in crops) {
      if (normalizeName(crop.id) == name ||
          normalizeName(crop.name) == name ||
          normalizeName(crop.scientificName) == name ||
          crop.id == alias) {
        return crop;
      }
    }
    return null;
  }

  CropCompatibility? compatibilityFor(String previousId, String nextId) {
    final previous = findCrop(previousId)?.id ?? previousId;
    final next = findCrop(nextId)?.id ?? nextId;
    for (final pair in compatibility) {
      if (pair.previousId == previous && pair.nextId == next) return pair;
    }
    return null;
  }

  SoilRule? rule(String id) => soilRules.where((r) => r.id == id).firstOrNull;
  MicroorganismProfile? microorganism(String id) =>
      microorganisms.where((r) => r.id == id).firstOrNull;
  AgronomySource? sourceById(String id) =>
      sources.where((r) => r.id == id).firstOrNull;
  List<RotationStep> stepsForSequence(String id) => List.unmodifiable(
    sequenceDetails.where((r) => r.sequenceId == id).toList()
      ..sort((a, b) => a.campaign.compareTo(b.campaign)),
  );

  static String normalizeName(String value) {
    var result = value.trim().toLowerCase();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    for (final entry in accents.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result
        .replaceAll(RegExp(r'[/()–-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _validate() {
    if (crops.length != 13 ||
        compatibility.length != 169 ||
        sequences.length != 3 ||
        sequenceDetails.length != 12 ||
        soilRules.length != 13 ||
        microorganisms.length != 9 ||
        sources.length != 16) {
      throw const FormatException('Base agronómica incompleta');
    }
    final ids = crops.map((c) => c.id).toSet();
    if (ids.length != crops.length) {
      throw const FormatException('ID de cultivo duplicado');
    }
    final pairs = <String>{};
    for (final pair in compatibility) {
      if (!ids.contains(pair.previousId) ||
          !ids.contains(pair.nextId) ||
          pair.score < 0 ||
          pair.score > 3 ||
          !pairs.add('${pair.previousId}:${pair.nextId}')) {
        throw const FormatException('Matriz de compatibilidad inválida');
      }
    }
    final microIds = microorganisms.map((m) => m.id).toSet();
    for (final rule in soilRules) {
      if (!rule.microorganismIds.every(microIds.contains)) {
        throw const FormatException('Microorganismo desconocido en regla');
      }
    }
    for (final sequence in sequences) {
      if (!sequence.microorganismIds.every(microIds.contains)) {
        throw const FormatException('Microorganismo desconocido en secuencia');
      }
      final steps = stepsForSequence(sequence.id);
      if (steps.length != 4 || steps.any((s) => !ids.contains(s.cropId))) {
        throw const FormatException('Secuencia incompleta');
      }
    }
  }
}

class CropProfile {
  const CropProfile({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.family,
    required this.type,
    required this.isLegume,
    required this.classification,
    required this.evidence,
    required this.waterMin,
    required this.waterMax,
    required this.waterMean,
    required this.waterUnit,
    required this.periodMin,
    required this.periodMax,
    required this.periodMean,
    required this.periodDescription,
    required this.temperatureMin,
    required this.temperatureMax,
    required this.phMin,
    required this.phMax,
    required this.nMin,
    required this.nMax,
    required this.pMin,
    required this.pMax,
    required this.kMin,
    required this.kMax,
    required this.salinityCategory,
    required this.ecThreshold,
    required this.salinityNote,
    required this.observations,
    required this.validation,
  });

  final String id;
  final String name;
  final String scientificName;
  final String family;
  final String type;
  final bool isLegume;
  final String classification;
  final String evidence;

  /// Crop water demand, not applied irrigation. Interpret with [waterUnit];
  /// alfalfa is annual and must not be compared directly with campaign crops.
  final double waterMin;
  final double waterMax;
  final double waterMean;
  final String waterUnit;
  final double? periodMin;
  final double? periodMax;
  final double? periodMean;
  final String periodDescription;
  final double temperatureMin;
  final double temperatureMax;
  final double phMin;
  final double phMax;

  /// Workbook fertilizer references in kg/ha of N, P2O5 and K2O respectively.
  /// They are not measured soil concentrations or automatically applied doses.
  final double nMin;
  final double nMax;
  final double pMin;
  final double pMax;
  final double kMin;
  final double kMax;
  final String salinityCategory;

  /// Saturated-soil-extract EC threshold (dS/m), when supplied in the workbook.
  /// A missing threshold must remain unknown, never zero.
  final double? ecThreshold;
  final String salinityNote;
  final String observations;
  final String validation;

  bool get isConfirmed => classification == 'Confirmada';
  bool get isPotential => classification == 'Potencial';
  bool get isPriority => classification != 'No prioritaria';
  bool get isAnnualWater => waterUnit.contains('año');

  factory CropProfile.fromJson(Map<String, dynamic> json) => CropProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    scientificName: json['scientificName'] as String,
    family: json['family'] as String,
    type: json['type'] as String,
    isLegume: json['isLegume'] as bool,
    classification: json['classification'] as String,
    evidence: json['evidence'] as String,
    waterMin: (json['waterMin'] as num).toDouble(),
    waterMax: (json['waterMax'] as num).toDouble(),
    waterMean: (json['waterMean'] as num).toDouble(),
    waterUnit: json['waterUnit'] as String,
    periodMin: (json['periodMin'] as num?)?.toDouble(),
    periodMax: (json['periodMax'] as num?)?.toDouble(),
    periodMean: (json['periodMean'] as num?)?.toDouble(),
    periodDescription: json['periodDescription'] as String,
    temperatureMin: (json['temperatureMin'] as num).toDouble(),
    temperatureMax: (json['temperatureMax'] as num).toDouble(),
    phMin: (json['phMin'] as num).toDouble(),
    phMax: (json['phMax'] as num).toDouble(),
    nMin: (json['nMin'] as num).toDouble(),
    nMax: (json['nMax'] as num).toDouble(),
    pMin: (json['pMin'] as num).toDouble(),
    pMax: (json['pMax'] as num).toDouble(),
    kMin: (json['kMin'] as num).toDouble(),
    kMax: (json['kMax'] as num).toDouble(),
    salinityCategory: json['salinityCategory'] as String,
    ecThreshold: (json['ecThreshold'] as num?)?.toDouble(),
    salinityNote: json['salinityNote'] as String,
    observations: json['observations'] as String,
    validation: json['validation'] as String,
  );
}

class CropCompatibility {
  const CropCompatibility({
    required this.previousId,
    required this.previousName,
    required this.nextId,
    required this.nextName,
    required this.level,
    required this.score,
    required this.condition,
    required this.observation,
  });

  final String previousId;
  final String previousName;
  final String nextId;
  final String nextName;
  final String level;
  final int score;
  final String condition;
  final String observation;

  factory CropCompatibility.fromJson(Map<String, dynamic> json) =>
      CropCompatibility(
        previousId: json['previousId'] as String,
        previousName: json['previousName'] as String,
        nextId: json['nextId'] as String,
        nextName: json['nextName'] as String,
        level: json['level'] as String,
        score: (json['score'] as num).toInt(),
        condition: json['condition'] as String,
        observation: json['observation'] as String,
      );
}

class RotationSequence {
  const RotationSequence({
    required this.id,
    required this.role,
    required this.sequence,
    required this.totalWater,
    required this.totalDays,
    required this.waterPerDay,
    required this.demandDifference,
    required this.sensitiveCampaigns,
    required this.differentFamilies,
    required this.benefit,
    required this.conditions,
    required this.limitations,
    required this.microorganismIds,
  });

  final String id;
  final String role;
  final String sequence;
  final double totalWater;
  final double totalDays;
  final double waterPerDay;
  final double demandDifference;
  final int sensitiveCampaigns;
  final int differentFamilies;
  final String benefit;
  final String conditions;
  final String limitations;
  final List<String> microorganismIds;

  factory RotationSequence.fromJson(Map<String, dynamic> json) =>
      RotationSequence(
        id: json['id'] as String,
        role: json['role'] as String,
        sequence: json['sequence'] as String,
        totalWater: (json['totalWater'] as num).toDouble(),
        totalDays: (json['totalDays'] as num).toDouble(),
        waterPerDay: (json['waterPerDay'] as num).toDouble(),
        demandDifference: (json['demandDifference'] as num).toDouble(),
        sensitiveCampaigns: (json['sensitiveCampaigns'] as num).toInt(),
        differentFamilies: (json['differentFamilies'] as num).toInt(),
        benefit: json['benefit'] as String,
        conditions: json['conditions'] as String,
        limitations: json['limitations'] as String,
        microorganismIds: List.unmodifiable(
          (json['microorganismIds'] as List).cast<String>(),
        ),
      );
}

class RotationStep {
  const RotationStep({
    required this.sequenceId,
    required this.campaign,
    required this.cropId,
    required this.cropName,
    required this.family,
    required this.classification,
    required this.water,
    required this.days,
    required this.salinityCategory,
  });

  final String sequenceId;
  final int campaign;
  final String cropId;
  final String cropName;
  final String family;
  final String classification;
  final double water;
  final double days;
  final String salinityCategory;

  factory RotationStep.fromJson(Map<String, dynamic> json) => RotationStep(
    sequenceId: json['sequenceId'] as String,
    campaign: (json['campaign'] as num).toInt(),
    cropId: json['cropId'] as String,
    cropName: json['cropName'] as String,
    family: json['family'] as String,
    classification: json['classification'] as String,
    water: (json['water'] as num).toDouble(),
    days: (json['days'] as num).toDouble(),
    salinityCategory: json['salinityCategory'] as String,
  );
}

class MicroorganismProfile {
  const MicroorganismProfile({
    required this.id,
    required this.group,
    required this.species,
    required this.function,
    required this.problem,
    required this.crops,
    required this.conditions,
    required this.application,
    required this.limitations,
  });

  final String id;
  final String group;
  final String species;
  final String function;
  final String problem;
  final String crops;
  final String conditions;
  final String application;
  final String limitations;

  factory MicroorganismProfile.fromJson(Map<String, dynamic> json) =>
      MicroorganismProfile(
        id: json['id'] as String,
        group: json['group'] as String,
        species: json['species'] as String,
        function: json['function'] as String,
        problem: json['problem'] as String,
        crops: json['crops'] as String,
        conditions: json['conditions'] as String,
        application: json['application'] as String,
        limitations: json['limitations'] as String,
      );
}

class SoilRule {
  const SoilRule({
    required this.id,
    required this.parameter,
    required this.condition,
    required this.interpretation,
    required this.action,
    required this.microorganismIds,
    required this.warning,
  });

  final String id;
  final String parameter;
  final String condition;
  final String interpretation;
  final String action;
  final List<String> microorganismIds;
  final String warning;

  factory SoilRule.fromJson(Map<String, dynamic> json) => SoilRule(
    id: json['id'] as String,
    parameter: json['parameter'] as String,
    condition: json['condition'] as String,
    interpretation: json['interpretation'] as String,
    action: json['action'] as String,
    microorganismIds: List.unmodifiable(
      (json['microorganismIds'] as List).cast<String>(),
    ),
    warning: json['warning'] as String,
  );
}

class AgronomySource {
  const AgronomySource({
    required this.id,
    required this.reference,
    required this.support,
    required this.url,
  });

  final String id;
  final String reference;
  final String support;
  final String? url;

  factory AgronomySource.fromJson(Map<String, dynamic> json) => AgronomySource(
    id: json['id'] as String,
    reference: json['reference'] as String,
    support: json['support'] as String,
    url: json['url'] as String?,
  );
}
