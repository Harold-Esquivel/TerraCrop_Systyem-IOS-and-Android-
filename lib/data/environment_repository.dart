import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'models.dart';

class EnvironmentalSource {
  EnvironmentalSource.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      institution = json['institution'] as String,
      product = json['product'] as String,
      variable = json['variable'] as String,
      unit = json['unit'] as String,
      temporalResolution = json['temporalResolution'] as String,
      spatialResolution = json['spatialResolution'] as String,
      quality = json['quality'] as String,
      state = json['state'] as String,
      latitude = (json['latitude'] as num).toDouble(),
      longitude = (json['longitude'] as num).toDouble(),
      bounds = (json['bounds'] as List?)
          ?.map((v) => (v as num).toDouble())
          .toList(),
      file = json['file'] as String,
      sha256 = json['sha256'] as String {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        (bounds != null &&
            (bounds!.length != 4 || bounds!.any((v) => !v.isFinite)))) {
      throw const FormatException('Coordenadas ambientales inválidas');
    }
  }
  final String id, institution, product, variable, unit;
  final String temporalResolution,
      spatialResolution,
      quality,
      state,
      file,
      sha256;
  final double latitude, longitude;
  final List<double>? bounds;

  /// Geographic eligibility is an explicit pilot-context gate, not a claim
  /// that a satellite pixel resolves an individual parcel. Point files use a
  /// conservative ±0.05° association window, documented in the methodology.
  bool covers(Parcel parcel) =>
      parcel.points.isNotEmpty &&
      parcel.points.every((p) {
        final b = bounds;
        if (b != null)
          return p.longitude >= b[0] &&
              p.longitude <= b[2] &&
              p.latitude >= b[1] &&
              p.latitude <= b[3];
        return (p.latitude - latitude).abs() <= .05 &&
            (p.longitude - longitude).abs() <= .05;
      });
}

class EnvironmentalObservation {
  EnvironmentalObservation.fromJson(Map<String, dynamic> json)
    : sourceId = json['source'] as String,
      date = DateTime.parse(json['date'] as String),
      value = (json['value'] as num?)?.toDouble(),
      quality = json['quality'] as String,
      samples = json['samples'] as int,
      rejected = json['rejected'] as int;
  final String sourceId, quality;
  final DateTime date;
  final double? value;
  final int samples, rejected;
}

class MonthlyClimate {
  const MonthlyClimate({
    required this.source,
    required this.month,
    required this.mean,
    required this.minimum,
    required this.maximum,
    required this.standardDeviation,
    required this.years,
    required this.samples,
    required this.missing,
    required this.period,
  });
  final EnvironmentalSource source;
  final int month, years, samples, missing;
  final double mean, minimum, maximum, standardDeviation;
  final String period;
}

/// Optional official prospective bulletin; never synthesized from history.
class SeasonalOutlook {
  SeasonalOutlook.fromJson(Map<String, dynamic> json)
    : institution = json['institution'] as String,
      issuedAt = DateTime.parse(json['issuedAt'] as String),
      validFrom = DateTime.parse(json['validFrom'] as String),
      validUntil = DateTime.parse(json['validUntil'] as String),
      region = json['region'] as String,
      variable = json['variable'] as String,
      statement = json['statement'] as String,
      limitations = json['limitations'] as String,
      url = Uri.parse(json['url'] as String),
      bounds = (json['bounds'] as List)
          .map((v) => (v as num).toDouble())
          .toList(),
      probabilities = Map<String, double>.from(
        (json['probabilities'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ) {
    const officialHosts = {
      'www.senamhi.gob.pe',
      'senamhi.gob.pe',
      'www.cpc.ncep.noaa.gov',
      'www.climate.gov',
      'www.noaa.gov',
    };
    if (url.scheme != 'https' ||
        !officialHosts.contains(url.host) ||
        validUntil.isBefore(validFrom) ||
        issuedAt.isAfter(validUntil) ||
        bounds.length != 4 ||
        bounds.any((v) => !v.isFinite) ||
        bounds[0] > bounds[2] ||
        bounds[1] > bounds[3] ||
        probabilities.values.any((v) => !v.isFinite || v < 0 || v > 1) ||
        (probabilities.isNotEmpty &&
            (probabilities.values.fold<double>(0, (a, b) => a + b) - 1).abs() >
                .01)) {
      throw const FormatException('Boletín prospectivo inválido');
    }
  }
  final String institution, region, variable, statement, limitations;
  final DateTime issuedAt, validFrom, validUntil;
  final Uri url;
  final List<double> bounds;
  final Map<String, double> probabilities;
  bool applies(Parcel p, DateTime start, DateTime end, DateTime asOf) =>
      !issuedAt.isAfter(asOf) &&
      !asOf.isAfter(validUntil) &&
      !start.isBefore(validFrom) &&
      !end.isAfter(validUntil) &&
      p.points.isNotEmpty &&
      p.points.every(
        (v) =>
            v.longitude >= bounds[0] &&
            v.longitude <= bounds[2] &&
            v.latitude >= bounds[1] &&
            v.latitude <= bounds[3],
      );
}

class EnvironmentRepository {
  EnvironmentRepository({
    required List<EnvironmentalSource> sources,
    required List<EnvironmentalObservation> observations,
    List<SeasonalOutlook> forecasts = const [],
    this.limitations = const [],
  }) : sources = List.unmodifiable(sources),
       observations = List.unmodifiable(observations),
       forecasts = List.unmodifiable(forecasts) {
    if (sources.map((s) => s.id).toSet().length != sources.length)
      throw const FormatException('Fuente ambiental duplicada');
    final keys = <String>{};
    for (final o in observations) {
      final s = sources.where((s) => s.id == o.sourceId).firstOrNull;
      if (s == null ||
          !keys.add('${o.sourceId}:${o.date.toIso8601String()}') ||
          o.samples < 0 ||
          o.rejected < 0 ||
          (o.value != null &&
              (!o.value!.isFinite ||
                  (s.variable == 'surface_soil_moisture' &&
                      (o.value! < 0 || o.value! > 1)) ||
                  ((s.variable == 'precipitation' ||
                          s.variable == 'PRECTOTCORR') &&
                      o.value! < 0)))) {
        throw const FormatException('Observación ambiental inválida');
      }
    }
  }
  factory EnvironmentRepository.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1)
      throw const FormatException('Versión ambiental desconocida');
    return EnvironmentRepository(
      sources: (json['sources'] as List)
          .map(
            (v) => EnvironmentalSource.fromJson(
              Map<String, dynamic>.from(v as Map),
            ),
          )
          .toList(),
      observations: (json['observations'] as List)
          .map(
            (v) => EnvironmentalObservation.fromJson(
              Map<String, dynamic>.from(v as Map),
            ),
          )
          .toList(),
      forecasts: (json['forecasts'] as List? ?? [])
          .map(
            (v) =>
                SeasonalOutlook.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
      limitations: (json['limitations'] as List).cast<String>(),
    );
  }
  static Future<EnvironmentRepository> load({AssetBundle? bundle}) async =>
      EnvironmentRepository.fromJson(
        jsonDecode(
              await (bundle ?? rootBundle).loadString(
                'assets/data/environment.json',
              ),
            )
            as Map<String, dynamic>,
      );
  final List<EnvironmentalSource> sources;
  final List<EnvironmentalObservation> observations;
  final List<SeasonalOutlook> forecasts;
  final List<String> limitations;
  static const forecastUnavailable =
      'Pronóstico estacional no disponible. La evaluación se basa en condiciones climáticas históricas';
  static const ensoUnavailable =
      'Sin boletín ENSO regional verificable incorporado. No puede determinarse un impacto local concreto en La Joya.';

  MonthlyClimate? monthly(
    String sourceId,
    int month, {
    int? excludeYear,
    int firstYear = 2015,
    int lastYear = 2024,
  }) {
    final source = sources.where((s) => s.id == sourceId).firstOrNull;
    if (source == null) return null;
    final relevant = observations
        .where(
          (o) =>
              o.sourceId == sourceId &&
              o.date.month == month &&
              o.date.year >= firstYear &&
              o.date.year <= lastYear &&
              o.date.year != excludeYear,
        )
        .toList();
    final groups = <int, List<EnvironmentalObservation>>{};
    for (final o in relevant) {
      groups.putIfAbsent(o.date.year, () => []).add(o);
    }
    // Equal weight per year, so irregular SMAP sampling does not overweight a year.
    final means = <double>[];
    var samples = 0;
    for (final group in groups.values) {
      final valid = group
          .where(
            (o) =>
                o.value != null &&
                o.quality != 'invalid' &&
                o.quality != 'incomplete',
          )
          .toList();
      if (valid.isEmpty) continue;
      means.add(valid.fold<double>(0, (a, o) => a + o.value!) / valid.length);
      samples += valid.fold<int>(0, (a, o) => a + o.samples);
    }
    // Minimum 5 distinct years is a software coverage rule, not WMO normal.
    if (means.length < 5) return null;
    final mean = means.reduce((a, b) => a + b) / means.length;
    return MonthlyClimate(
      source: source,
      month: month,
      mean: mean,
      minimum: means.reduce(math.min),
      maximum: means.reduce(math.max),
      standardDeviation: math.sqrt(
        means.fold<double>(0, (a, v) => a + math.pow(v - mean, 2)) /
            (means.length - 1),
      ),
      years: means.length,
      samples: samples,
      missing:
          lastYear -
          firstYear +
          1 -
          (excludeYear != null &&
                  excludeYear >= firstYear &&
                  excludeYear <= lastYear
              ? 1
              : 0) -
          means.length,
      period:
          '$firstYear–$lastYear${excludeYear == null ? '' : ' (excluye $excludeYear)'}',
    );
  }

  /// Anomaly is a retrospective mm difference, never a forecast or drought diagnosis.
  double? precipitationAnomaly(int year, int month) {
    final actual = observations
        .where(
          (o) =>
              o.sourceId == 'gpm' &&
              o.date.year == year &&
              o.date.month == month,
        )
        .firstOrNull
        ?.value;
    final reference = monthly('gpm', month, excludeYear: year);
    return actual == null || reference == null ? null : actual - reference.mean;
  }
}
