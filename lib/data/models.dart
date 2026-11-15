import 'package:latlong2/latlong.dart';

import 'agronomy_catalog.dart';

enum NutrientLevel { unknown, low, adequate, high }

/// Laboratory interpretation. N/P/K are deliberately categorical: campaign
/// fertilizer requirements (kg/ha) cannot be compared with the demo indices.
class SoilAnalysis {
  const SoilAnalysis({
    this.ph,
    this.ec,
    this.organicMatter,
    this.nitrogen = NutrientLevel.unknown,
    this.phosphorus = NutrientLevel.unknown,
    this.potassium = NutrientLevel.unknown,
    this.sandySoil,
    this.moistureLow,
    this.waterlogged,
    this.soilDiseaseHistory,
    this.sampledAt,
  });

  final double? ph;

  /// Electrical conductivity of a saturated soil extract, in dS/m.
  final double? ec;
  final double? organicMatter;
  final NutrientLevel nitrogen, phosphorus, potassium;
  final bool? sandySoil, moistureLow, waterlogged, soilDiseaseHistory;
  final DateTime? sampledAt;

  Map<String, dynamic> toJson() => {
    'ph': ph,
    'ec': ec,
    'organicMatter': organicMatter,
    'nitrogen': nitrogen.name,
    'phosphorus': phosphorus.name,
    'potassium': potassium.name,
    'sandySoil': sandySoil,
    'moistureLow': moistureLow,
    'waterlogged': waterlogged,
    'soilDiseaseHistory': soilDiseaseHistory,
    'sampledAt': sampledAt?.toIso8601String(),
  };

  factory SoilAnalysis.fromJson(Map<String, dynamic> json) {
    double? number(String key, double max) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < 0 || value > max) {
        return null;
      }
      return value.toDouble();
    }

    NutrientLevel level(String key) =>
        NutrientLevel.values.where((v) => v.name == json[key]).firstOrNull ??
        NutrientLevel.unknown;
    return SoilAnalysis(
      ph: number('ph', 14),
      ec: number('ec', 1000),
      organicMatter: number('organicMatter', 100),
      nitrogen: level('nitrogen'),
      phosphorus: level('phosphorus'),
      potassium: level('potassium'),
      sandySoil: json['sandySoil'] is bool ? json['sandySoil'] as bool : null,
      moistureLow: json['moistureLow'] is bool
          ? json['moistureLow'] as bool
          : null,
      waterlogged: json['waterlogged'] is bool
          ? json['waterlogged'] as bool
          : null,
      soilDiseaseHistory: json['soilDiseaseHistory'] is bool
          ? json['soilDiseaseHistory'] as bool
          : null,
      sampledAt: DateTime.tryParse(json['sampledAt'] as String? ?? ''),
    );
  }
}

class Parcel {
  const Parcel({
    required this.id,
    required this.name,
    required this.crop,
    required this.points,
    this.ph = 6.5,
    this.nitrogen = 70,
    this.phosphorus = 65,
    this.potassium = 75,
    this.moisture = 68,
    this.devices = const [],
    this.soilAnalysis,
    this.cropHistory = const [],
  });

  final String id;
  final String name;
  final String crop;
  final List<LatLng> points;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double moisture;
  final List<FarmDevice> devices;
  final SoilAnalysis? soilAnalysis;

  /// Previous campaigns in chronological order; excludes the current crop.
  final List<String> cropHistory;

  bool get critical {
    final analysis = soilAnalysis;
    if (analysis != null) {
      return (analysis.ph != null &&
              (analysis.ph! < 5.5 || analysis.ph! >= 8.5)) ||
          (analysis.ec != null && analysis.ec! >= 4);
    }
    return ph < 5.5 ||
        ph >= 8.5 ||
        moisture < 25 ||
        nitrogen < 25 ||
        phosphorus < 25 ||
        potassium < 25;
  }

  bool get hasIncompleteSoilAnalysis {
    final a = soilAnalysis;
    return a != null &&
        (a.ph == null ||
            a.ec == null ||
            a.organicMatter == null ||
            a.nitrogen == NutrientLevel.unknown ||
            a.phosphorus == NutrientLevel.unknown ||
            a.potassium == NutrientLevel.unknown ||
            a.sandySoil == null ||
            a.moistureLow == null ||
            a.waterlogged == null ||
            a.soilDiseaseHistory == null);
  }

  bool get _knownSoilWarning {
    final profile = AgronomyCatalog.current?.findCrop(crop);
    final analysis = soilAnalysis;
    if (analysis != null) {
      final value = analysis.ph;
      return critical ||
          (value != null &&
              (value >= 7.5 ||
                  value < (profile?.phMin ?? 6) ||
                  value > (profile?.phMax ?? 7.5))) ||
          (analysis.ec != null &&
              profile?.ecThreshold != null &&
              analysis.ec! >= profile!.ecThreshold!) ||
          (analysis.organicMatter != null && analysis.organicMatter! < 2) ||
          [
            analysis.nitrogen,
            analysis.phosphorus,
            analysis.potassium,
          ].any((v) => v == NutrientLevel.low || v == NutrientLevel.high) ||
          analysis.soilDiseaseHistory == true ||
          analysis.waterlogged == true ||
          analysis.moistureLow == true;
    }
    return false;
  }

  bool get warning {
    if (soilAnalysis != null) {
      return critical || _knownSoilWarning || hasIncompleteSoilAnalysis;
    }
    final profile = AgronomyCatalog.current?.findCrop(crop);
    return critical ||
        ph >= 7.5 ||
        ph < (profile?.phMin ?? 6) ||
        ph > (profile?.phMax ?? 7.2) ||
        moisture < 40 ||
        nitrogen < 40 ||
        phosphorus < 40 ||
        potassium < 40;
  }

  String get status {
    if (critical) return 'En riesgo';
    if (hasOnlyMissingSoilData) return 'Datos por completar';
    return warning ? 'Atención' : 'Saludable';
  }

  bool get hasOnlyMissingSoilData =>
      hasIncompleteSoilAnalysis && !_knownSoilWarning;

  Parcel copyWith({
    String? name,
    String? crop,
    List<LatLng>? points,
    double? ph,
    double? nitrogen,
    double? phosphorus,
    double? potassium,
    double? moisture,
    List<FarmDevice>? devices,
    SoilAnalysis? soilAnalysis,
    bool clearSoilAnalysis = false,
    List<String>? cropHistory,
  }) => Parcel(
    id: id,
    name: name ?? this.name,
    crop: crop ?? this.crop,
    points: points ?? this.points,
    ph: ph ?? this.ph,
    nitrogen: nitrogen ?? this.nitrogen,
    phosphorus: phosphorus ?? this.phosphorus,
    potassium: potassium ?? this.potassium,
    moisture: moisture ?? this.moisture,
    devices: devices ?? this.devices,
    soilAnalysis: clearSoilAnalysis ? null : soilAnalysis ?? this.soilAnalysis,
    cropHistory: cropHistory ?? this.cropHistory,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'crop': crop,
    'points': points.map((p) => [p.latitude, p.longitude]).toList(),
    'ph': ph,
    'nitrogen': nitrogen,
    'phosphorus': phosphorus,
    'potassium': potassium,
    'moisture': moisture,
    'devices': devices.map((d) => d.toJson()).toList(),
    'soilAnalysis': soilAnalysis?.toJson(),
    'cropHistory': cropHistory,
  };

  factory Parcel.fromJson(Map<String, dynamic> json) => Parcel(
    id: json['id'] as String,
    name: json['name'] as String,
    crop: json['crop'] as String,
    points: (json['points'] as List)
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList(),
    ph: (json['ph'] as num).toDouble(),
    nitrogen: (json['nitrogen'] as num).toDouble(),
    phosphorus: (json['phosphorus'] as num).toDouble(),
    potassium: (json['potassium'] as num).toDouble(),
    moisture: (json['moisture'] as num).toDouble(),
    devices: (json['devices'] as List)
        .map((d) => FarmDevice.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList(),
    soilAnalysis: json['soilAnalysis'] is Map
        ? SoilAnalysis.fromJson(
            Map<String, dynamic>.from(json['soilAnalysis'] as Map),
          )
        : null,
    cropHistory: json['cropHistory'] is List
        ? (json['cropHistory'] as List)
              .whereType<String>()
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList()
        : const [],
  );
}

class FarmDevice {
  const FarmDevice({
    required this.name,
    required this.kind,
    this.connected = true,
    this.battery = 88,
  });
  final String name;
  final String kind;
  final bool connected;
  final int battery;

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind,
    'connected': connected,
    'battery': battery,
  };
  factory FarmDevice.fromJson(Map<String, dynamic> json) => FarmDevice(
    name: json['name'] as String,
    kind: json['kind'] as String,
    connected: json['connected'] as bool,
    battery: json['battery'] as int,
  );
}

List<Parcel> demoParcels() => [
  Parcel(
    id: 'demo-1',
    name: 'Parcela Norte',
    crop: 'Maíz',
    points: const [
      LatLng(-12.04325, -77.03085),
      LatLng(-12.04325, -77.0285),
      LatLng(-12.0451, -77.0285),
      LatLng(-12.0451, -77.03085),
    ],
    devices: const [
      FarmDevice(name: 'Sensor de suelo 01', kind: 'Suelo', battery: 86),
      FarmDevice(name: 'Estación climática', kind: 'Clima', battery: 72),
    ],
  ),
  Parcel(
    id: 'demo-2',
    name: 'Parcela Este',
    crop: 'Papa',
    points: const [
      LatLng(-12.0436, -77.0279),
      LatLng(-12.0436, -77.0263),
      LatLng(-12.0455, -77.0263),
      LatLng(-12.0455, -77.0279),
    ],
    ph: 5.3,
    moisture: 33,
    nitrogen: 32,
    devices: const [
      FarmDevice(name: 'Sensor de suelo 02', kind: 'Suelo', battery: 24),
      FarmDevice(
        name: 'Válvula inteligente',
        kind: 'Riego',
        connected: false,
        battery: 0,
      ),
    ],
  ),
  Parcel(
    id: 'demo-3',
    name: 'Parcela Sur',
    crop: 'Quinua',
    points: const [
      LatLng(-12.0462, -77.031),
      LatLng(-12.0462, -77.0287),
      LatLng(-12.0478, -77.0287),
      LatLng(-12.0478, -77.031),
    ],
    ph: 6.1,
    moisture: 54,
    phosphorus: 48,
    devices: const [
      FarmDevice(name: 'Sensor de suelo 03', kind: 'Suelo', battery: 96),
    ],
  ),
];
