import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../app/app_theme.dart';
import '../data/models.dart';

/// Native Mapbox map for the parcel editor. The OSM map remains available on
/// platforms where Mapbox annotations are not supported.
class MapboxParcelMap extends StatefulWidget {
  const MapboxParcelMap({
    super.key,
    required this.parcels,
    required this.selectedId,
    required this.firstCorner,
    required this.draft,
    required this.isDrawing,
    required this.is3D,
    required this.onTap,
    required this.onVertexMoved,
    required this.onParcelTap,
  });

  final List<Parcel> parcels;
  final String? selectedId;
  final LatLng? firstCorner;
  final List<LatLng>? draft;
  final bool isDrawing;
  final bool is3D;
  final void Function(LatLng point) onTap;
  final Future<void> Function(String parcelId, int vertexIndex, LatLng point)
  onVertexMoved;
  final void Function(String parcelId) onParcelTap;

  @override
  State<MapboxParcelMap> createState() => _MapboxParcelMapState();
}

class _VertexRef {
  const _VertexRef(this.parcelId, this.index);

  final String parcelId;
  final int index;
}

class _MapboxParcelMapState extends State<MapboxParcelMap> {
  MapboxMap? _map;
  PolygonAnnotationManager? _polygons;
  PointAnnotationManager? _labels;
  CircleAnnotationManager? _circles;
  Cancelable? _polygonTaps;
  Cancelable? _vertexDrags;
  final _parcelByPolygonId = <String, String>{};
  final _vertexByCircleId = <String, _VertexRef>{};
  Future<void> _renderTask = Future.value();
  late final CameraViewportState _initialViewport = CameraViewportState(
    center: _initialCenter(),
    zoom: 15.5,
    pitch: widget.is3D ? 55 : 0,
  );

  Point _initialCenter() {
    final points = widget.parcels.expand((parcel) => parcel.points).toList();
    if (points.isEmpty) {
      return Point(coordinates: Position(-77.0288, -12.0454));
    }
    return Point(
      coordinates: Position(
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
      ),
    );
  }

  Position _position(LatLng point) => Position(point.longitude, point.latitude);

  Polygon _geometry(List<LatLng> points) => Polygon(
    coordinates: [
      [for (final point in points) _position(point), _position(points.first)],
    ],
  );

  @override
  void didUpdateWidget(covariant MapboxParcelMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.is3D != widget.is3D) {
      unawaited(_map?.setCamera(CameraOptions(pitch: widget.is3D ? 55 : 0)));
    }
    if (oldWidget.selectedId != widget.selectedId) _updateOrnamentMargins();
    if (oldWidget.isDrawing != widget.isDrawing) _syncPolygonTaps();
    if (!identical(oldWidget.parcels, widget.parcels) ||
        oldWidget.selectedId != widget.selectedId ||
        oldWidget.firstCorner != widget.firstCorner ||
        !identical(oldWidget.draft, widget.draft)) {
      _scheduleRender();
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _updateOrnamentMargins();
    map.addInteraction(
      TapInteraction.onMap((event) {
        if (!mounted) return;
        final coordinates = event.point.coordinates;
        widget.onTap(
          LatLng(coordinates.lat.toDouble(), coordinates.lng.toDouble()),
        );
      }),
    );

    final polygons = await map.annotations.createPolygonAnnotationManager();
    if (!mounted) return;
    _polygons = polygons;
    final labels = await map.annotations.createPointAnnotationManager();
    if (!mounted) return;
    _labels = labels;
    final circles = await map.annotations.createCircleAnnotationManager();
    if (!mounted) return;
    _circles = circles;
    _syncPolygonTaps();
    _vertexDrags = circles.dragEvents(
      onEnd: (annotation) {
        final ref = _vertexByCircleId[annotation.id];
        if (ref == null || !mounted) return;
        final position = annotation.geometry.coordinates;
        unawaited(
          widget.onVertexMoved(
            ref.parcelId,
            ref.index,
            LatLng(position.lat.toDouble(), position.lng.toDouble()),
          ),
        );
      },
    );
    _scheduleRender();
    await _frameInitialParcels(map);
  }

  Future<void> _frameInitialParcels(MapboxMap map) async {
    final points = widget.parcels.expand((parcel) => parcel.points).toList();
    if (points.isEmpty) return;
    final south = points
        .map((point) => point.latitude)
        .reduce((a, b) => a < b ? a : b);
    final north = points
        .map((point) => point.latitude)
        .reduce((a, b) => a > b ? a : b);
    final west = points
        .map((point) => point.longitude)
        .reduce((a, b) => a < b ? a : b);
    final east = points
        .map((point) => point.longitude)
        .reduce((a, b) => a > b ? a : b);
    if (south == north || west == east) return;
    try {
      final camera = await map.cameraForCoordinateBounds(
        CoordinateBounds(
          southwest: Point(coordinates: Position(west, south)),
          northeast: Point(coordinates: Position(east, north)),
          infiniteBounds: false,
        ),
        MbxEdgeInsets(top: 72, left: 28, bottom: 72, right: 28),
        0,
        widget.is3D ? 55 : 0,
        16.5,
        null,
      );
      if (mounted) await map.setCamera(camera);
    } catch (error) {
      debugPrint('No se pudo encuadrar las parcelas: $error');
    }
  }

  void _updateOrnamentMargins() {
    final map = _map;
    if (map == null) return;
    final margin = widget.selectedId == null ? 74.0 : 180.0;
    unawaited(map.logo.updateSettings(LogoSettings(marginBottom: margin)));
    unawaited(
      map.attribution.updateSettings(AttributionSettings(marginBottom: margin)),
    );
  }

  void _syncPolygonTaps() {
    _polygonTaps?.cancel();
    _polygonTaps = null;
    final polygons = _polygons;
    if (polygons == null || widget.isDrawing) return;
    _polygonTaps = polygons.tapEvents(
      onTap: (annotation) {
        final parcelId = _parcelByPolygonId[annotation.id];
        if (parcelId != null && mounted) widget.onParcelTap(parcelId);
      },
    );
  }

  void _scheduleRender() {
    _renderTask = _renderTask.then((_) => _renderAnnotations()).catchError((
      Object error,
      StackTrace stack,
    ) {
      debugPrint('No se pudieron dibujar las parcelas en Mapbox: $error');
    });
  }

  Future<void> _renderAnnotations() async {
    final polygons = _polygons;
    final labels = _labels;
    final circles = _circles;
    if (!mounted || polygons == null || labels == null || circles == null) {
      return;
    }

    await polygons.deleteAll();
    await labels.deleteAll();
    await circles.deleteAll();
    if (!mounted) return;
    _parcelByPolygonId.clear();
    _vertexByCircleId.clear();

    final parcelIds = <String>[];
    final polygonOptions = <PolygonAnnotationOptions>[];
    for (final parcel in widget.parcels) {
      if (parcel.points.length < 3) continue;
      parcelIds.add(parcel.id);
      final selected = parcel.id == widget.selectedId;
      final color = selected
          ? blue
          : parcel.critical
          ? const Color(0xFFE58A4D)
          : green;
      polygonOptions.add(
        PolygonAnnotationOptions(
          geometry: _geometry(parcel.points),
          fillColor: color.toARGB32(),
          fillOpacity: selected ? .5 : .36,
          fillOutlineColor: color.toARGB32(),
        ),
      );
    }
    final draft = widget.draft;
    if (draft != null && draft.length >= 3) {
      polygonOptions.add(
        PolygonAnnotationOptions(
          geometry: _geometry(draft),
          fillColor: blue.toARGB32(),
          fillOpacity: .35,
          fillOutlineColor: blue.toARGB32(),
        ),
      );
    }
    if (polygonOptions.isNotEmpty) {
      final created = await polygons.createMulti(polygonOptions);
      for (
        var index = 0;
        index < parcelIds.length && index < created.length;
        index++
      ) {
        final annotation = created[index];
        if (annotation != null) {
          _parcelByPolygonId[annotation.id] = parcelIds[index];
        }
      }
    }
    if (!mounted) return;

    final labelOptions = <PointAnnotationOptions>[];
    for (final parcel in widget.parcels) {
      if (parcel.points.isEmpty) continue;
      final center = LatLng(
        parcel.points.map((point) => point.latitude).reduce((a, b) => a + b) /
            parcel.points.length,
        parcel.points.map((point) => point.longitude).reduce((a, b) => a + b) /
            parcel.points.length,
      );
      labelOptions.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: _position(center)),
          textField: parcel.name,
          textSize: 12,
          textColor: Colors.white.toARGB32(),
          textHaloColor: ink.toARGB32(),
          textHaloWidth: 1.5,
        ),
      );
    }
    if (labelOptions.isNotEmpty) await labels.createMulti(labelOptions);
    if (!mounted) return;

    final circleOptions = <CircleAnnotationOptions>[];
    final vertexRefs = <_VertexRef>[];
    final selected = widget.parcels
        .where((parcel) => parcel.id == widget.selectedId)
        .firstOrNull;
    if (selected != null) {
      for (var index = 0; index < selected.points.length; index++) {
        vertexRefs.add(_VertexRef(selected.id, index));
        circleOptions.add(
          CircleAnnotationOptions(
            geometry: Point(coordinates: _position(selected.points[index])),
            circleColor: blue.toARGB32(),
            circleRadius: 9,
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 2,
            isDraggable: true,
          ),
        );
      }
    }
    final corner = widget.firstCorner;
    if (corner != null) {
      circleOptions.add(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _position(corner)),
          circleColor: blue.toARGB32(),
          circleRadius: 8,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2,
        ),
      );
    }
    if (circleOptions.isNotEmpty) {
      final created = await circles.createMulti(circleOptions);
      for (
        var index = 0;
        index < vertexRefs.length && index < created.length;
        index++
      ) {
        final annotation = created[index];
        if (annotation != null) {
          _vertexByCircleId[annotation.id] = vertexRefs[index];
        }
      }
    }
  }

  @override
  void dispose() {
    _polygonTaps?.cancel();
    _vertexDrags?.cancel();
    _map = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MapWidget(
    styleUri: MapboxStyles.STANDARD_SATELLITE,
    viewport: _initialViewport,
    textureView: true,
    onMapCreated: _onMapCreated,
    onMapLoadedListener: (_) => debugPrint('Mapa satelital Mapbox cargado'),
    onMapLoadErrorListener: (event) =>
        debugPrint('Error al cargar el mapa satelital: ${event.type}'),
  );
}
