import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_theme.dart';
import '../app/ui.dart';
import '../data/models.dart';
import '../data/agronomy_catalog.dart';
import '../data/terra_store.dart';
import 'mapbox_parcel_map.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  Color parcelColor(Parcel parcel) => parcel.critical
      ? const Color(0xFFE58A4D)
      : parcel.hasOnlyMissingSoilData
      ? context.colors.muted
      : parcel.warning
      ? const Color(0xFFD8A13D)
      : context.colors.green;
  static const _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  final controller = MapController();
  late final AnimationController placement;
  late final AnimationController pulse;
  String? newParcelId;
  bool drawing = false;
  LatLng? firstCorner;
  List<LatLng>? draft;
  String? selectedId;
  bool is3D = true;

  bool get useMapbox =>
      _mapboxToken.isNotEmpty &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    placement =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 360),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    pulse =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addListener(() {
          if (mounted) setState(() {});
        });
  }

  List<LatLng> rectangle(LatLng a, LatLng b) => [
    LatLng(a.latitude, a.longitude),
    LatLng(a.latitude, b.longitude),
    LatLng(b.latitude, b.longitude),
    LatLng(b.latitude, a.longitude),
  ];

  void mapTap(LatLng point, List<Parcel> parcels) {
    if (drawing) {
      if (firstCorner == null) {
        setState(() => firstCorner = point);
      } else {
        if ((firstCorner!.latitude - point.latitude).abs() < 0.00001 ||
            (firstCorner!.longitude - point.longitude).abs() < 0.00001) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marca una esquina opuesta más lejos'),
            ),
          );
          return;
        }
        final points = rectangle(firstCorner!, point);
        setState(() {
          draft = points;
          firstCorner = null;
          drawing = false;
        });
        _parcelDialog(points: points);
      }
      return;
    }
    for (final parcel in parcels.reversed) {
      if (_containsPoint(parcel.points, point)) {
        setState(() => selectedId = parcel.id);
        pulse.forward(from: 0);
        return;
      }
    }
    setState(() => selectedId = null);
  }

  bool _containsPoint(List<LatLng> vertices, LatLng point) {
    if (vertices.length < 3) return false;
    var inside = false;
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      final a = vertices[i];
      final b = vertices[j];
      if ((a.latitude > point.latitude) != (b.latitude > point.latitude) &&
          point.longitude <
              (b.longitude - a.longitude) *
                      (point.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  Future<void> _saveVertex(String parcelId, int index, LatLng point) async {
    if (!mounted) return;
    final store = context.read<TerraStore>();
    final parcel = store.parcels
        .where((item) => item.id == parcelId)
        .firstOrNull;
    if (parcel == null || index < 0 || index >= parcel.points.length) return;
    final points = [...parcel.points]..[index] = point;
    try {
      await store.updateParcel(parcel.copyWith(points: points));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forma de la parcela guardada')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la parcela')),
      );
    }
  }

  Future<void> _parcelDialog({Parcel? parcel, List<LatLng>? points}) async {
    final catalog = await AgronomyCatalog.load();
    if (!mounted) return;
    final name = TextEditingController(text: parcel?.name ?? '');
    String crop = parcel?.crop ?? 'Maíz';
    final store = context.read<TerraStore>();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(parcel == null ? 'Nueva parcela' : 'Editar parcela'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la parcela',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: crop,
                decoration: const InputDecoration(labelText: 'Cultivo'),
                items:
                    <String>{
                          for (final profile in catalog.crops) profile.name,
                          crop,
                        }
                        .toList()
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (value) =>
                    setDialogState(() => crop = value ?? crop),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      if (parcel == null && points != null) {
        store.addParcel(name: name.text.trim(), crop: crop, points: points);
        newParcelId = store.parcels.last.id;
        placement.forward(from: 0);
      } else if (parcel != null) {
        await store.updateParcel(
          parcel.copyWith(name: name.text.trim(), crop: crop),
        );
      }
    }
    if (mounted) setState(() => draft = null);
    name.dispose();
  }

  List<LatLng> animatedPoints(Parcel parcel) {
    if (parcel.id != newParcelId || placement.value == 1) return parcel.points;
    final center = LatLng(
      parcel.points.map((p) => p.latitude).reduce((a, b) => a + b) /
          parcel.points.length,
      parcel.points.map((p) => p.longitude).reduce((a, b) => a + b) /
          parcel.points.length,
    );
    final scale = .8 + .2 * Curves.easeOutCubic.transform(placement.value);
    return [
      for (final p in parcel.points)
        LatLng(
          center.latitude + (p.latitude - center.latitude) * scale,
          center.longitude + (p.longitude - center.longitude) * scale,
        ),
    ];
  }

  @override
  void dispose() {
    placement.dispose();
    pulse.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TerraStore>();
    final selected = store.parcels.where((p) => p.id == selectedId).firstOrNull;
    return Column(
      children: [
        PageIntro(
          eyebrow: 'Tu campo, en un vistazo',
          title: 'Mapa de parcelas',
          subtitle: useMapbox
              ? 'Explora y edita tus parcelas en el mapa satelital'
              : 'Monitorea tus cultivos desde cualquier lugar',
          trailing: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: context.colors.ink,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MetricPill(
                icon: Icons.grid_view_rounded,
                label: '${store.parcels.length} parcelas',
                color: context.colors.blue,
              ),
              MetricPill(
                icon: Icons.eco_outlined,
                label:
                    '${store.parcels.where((p) => !p.warning).length} saludables',
              ),
              const MetricPill(icon: Icons.wifi_tethering, label: 'EN VIVO'),
            ],
          ),
        ),
        const SizedBox(height: 17),
        if (useMapbox)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PressButton(
                label: is3D ? 'Vista 2D' : 'Vista 3D',
                icon: Icons.terrain_outlined,
                outlined: true,
                onPressed: () => setState(() => is3D = !is3D),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: useMapbox
                    ? MapboxParcelMap(
                        parcels: store.parcels,
                        selectedId: selectedId,
                        firstCorner: firstCorner,
                        draft: draft,
                        is3D: is3D,
                        isDrawing: drawing,
                        onTap: (point) => mapTap(point, store.parcels),
                        onParcelTap: (id) {
                          if (drawing) return;
                          setState(() => selectedId = id);
                          pulse.forward(from: 0);
                        },
                        onVertexMoved: _saveVertex,
                      )
                    : FlutterMap(
                        mapController: controller,
                        options: MapOptions(
                          initialCenter: const LatLng(-12.0454, -77.0288),
                          initialZoom: 15.8,
                          onTap: (_, point) => mapTap(point, store.parcels),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.terracrop.app',
                          ),
                          PolygonLayer(
                            polygons: [
                              for (final parcel in store.parcels)
                                Polygon(
                                  points: animatedPoints(parcel),
                                  color: parcelColor(parcel).withValues(
                                    alpha:
                                        (parcel.id == selectedId ? .42 : .25) *
                                        (parcel.id == newParcelId
                                            ? placement.value
                                            : 1),
                                  ),
                                  borderColor: parcel.id == selectedId
                                      ? context.colors.blue
                                      : parcelColor(parcel),
                                  borderStrokeWidth: parcel.id == selectedId
                                      ? 4 + 2 * math.sin(math.pi * pulse.value)
                                      : 2,
                                ),
                              if (draft != null)
                                Polygon(
                                  points: draft!,
                                  color: context.colors.blue.withValues(
                                    alpha: .25,
                                  ),
                                  borderColor: context.colors.blue,
                                  borderStrokeWidth: 3,
                                ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              for (final parcel in store.parcels)
                                Marker(
                                  point: LatLng(
                                    parcel.points
                                            .map((p) => p.latitude)
                                            .reduce((a, b) => a + b) /
                                        parcel.points.length,
                                    parcel.points
                                            .map((p) => p.longitude)
                                            .reduce((a, b) => a + b) /
                                        parcel.points.length,
                                  ),
                                  width: 110,
                                  height: 33,
                                  child: IgnorePointer(
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: context.colors.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x33304953),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        parcel.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: InkWell(
                              onTap: () => launchUrl(
                                Uri.parse(
                                  'https://www.openstreetmap.org/copyright',
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                color: context.colors.surface.withValues(
                                  alpha: .88,
                                ),
                                child: Text(
                                  '© OpenStreetMap contributors',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.colors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              Positioned(
                top: 15,
                left: 18,
                right: 18,
                child: SurfaceCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 18,
                        color: context.colors.blue,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          drawing
                              ? firstCorner == null
                                    ? 'Toca la primera esquina'
                                    : 'Toca la esquina opuesta'
                              : useMapbox && selected != null
                              ? 'Arrastra un vértice para ajustar la parcela'
                              : 'Toca una parcela para ver detalles',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (drawing)
                        InkWell(
                          onTap: () => setState(() {
                            drawing = false;
                            firstCorner = null;
                          }),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: context.colors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: selected == null ? 22 : 175,
                child: PressButton(
                  label: drawing ? 'Dibujando...' : 'Nueva parcela',
                  icon: Icons.add,
                  onPressed: () => setState(() {
                    drawing = true;
                    firstCorner = null;
                    selectedId = null;
                  }),
                ),
              ),
              if (selected != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(selected.id),
                    tween: Tween(begin: .93, end: 1),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: SurfaceCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selected.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              MetricPill(
                                icon: selected.hasOnlyMissingSoilData
                                    ? Icons.help_outline
                                    : selected.warning
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline,
                                label: selected.status,
                                color: parcelColor(selected),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${selected.crop} · pH ${selected.ph.toStringAsFixed(1)} · ${selected.devices.length} dispositivos',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: PressButton(
                                  label: 'Editar',
                                  icon: Icons.edit_outlined,
                                  outlined: true,
                                  onPressed: () =>
                                      _parcelDialog(parcel: selected),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: PressButton(
                                  label: 'Eliminar',
                                  icon: Icons.delete_outline,
                                  outlined: true,
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Eliminar parcela'),
                                        content: Text(
                                          '¿Eliminar ${selected.name} y sus datos?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      store.removeParcel(selected.id);
                                      setState(() => selectedId = null);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
