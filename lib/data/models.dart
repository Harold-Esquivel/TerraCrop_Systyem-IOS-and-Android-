import 'package:latlong2/latlong.dart';

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

  bool get critical =>
      ph < 5.5 ||
      ph > 7.8 ||
      moisture < 25 ||
      nitrogen < 25 ||
      phosphorus < 25 ||
      potassium < 25;
  bool get warning =>
      critical ||
      ph < 6 ||
      ph > 7.2 ||
      moisture < 40 ||
      nitrogen < 40 ||
      phosphorus < 40 ||
      potassium < 40;
  String get status => critical
      ? 'En riesgo'
      : warning
      ? 'Atención'
      : 'Saludable';

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
