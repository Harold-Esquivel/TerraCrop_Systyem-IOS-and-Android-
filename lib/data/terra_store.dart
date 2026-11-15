import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_service.dart';
import 'models.dart';

class TerraStore extends ChangeNotifier {
  static const _key = 'terracrop_data_v1';
  final _prefs = SharedPreferencesAsync();
  List<Parcel> parcels = [];
  String userName = 'Agricultor';
  int streak = 1;
  DateTime? lastVisit;
  int revision = 0;
  Future<void> _pendingSave = Future.value();

  Future<void> load() async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null) {
        parcels = demoParcels();
      } else {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        parcels = (data['parcels'] as List)
            .map((e) => Parcel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        userName = (data['userName'] as String?) ?? userName;
        streak = (data['streak'] as int?) ?? 1;
        lastVisit = DateTime.tryParse((data['lastVisit'] as String?) ?? '');
        revision = (data['revision'] as int?) ?? 0;
      }
    } catch (_) {
      parcels = demoParcels();
    }
    final remote = await CloudService.instance.read();
    if (remote != null && ((remote['revision'] as int?) ?? 0) > revision) {
      try {
        parcels = (remote['parcels'] as List)
            .map((e) => Parcel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        userName = (remote['userName'] as String?) ?? userName;
        streak = (remote['streak'] as int?) ?? streak;
        lastVisit = DateTime.tryParse((remote['lastVisit'] as String?) ?? '');
        revision = (remote['revision'] as int?) ?? revision;
      } catch (error) {
        debugPrint('Datos remotos inválidos: $error');
      }
    }
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (lastVisit != null) {
      final previous = DateTime(
        lastVisit!.year,
        lastVisit!.month,
        lastVisit!.day,
      );
      final days = todayOnly.difference(previous).inDays;
      if (days == 1) streak++;
      if (days > 1) streak = 1;
    }
    lastVisit = today;
    revision = DateTime.now().millisecondsSinceEpoch;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final payload = {
      'parcels': parcels.map((p) => p.toJson()).toList(),
      'userName': userName,
      'streak': streak,
      'lastVisit': lastVisit?.toIso8601String(),
      'revision': revision,
    };
    final save = _pendingSave.then((_) async {
      await _prefs.setString(_key, jsonEncode(payload));
      await CloudService.instance.save(payload);
    });
    _pendingSave = save.then((_) {}, onError: (Object _, StackTrace _) {});
    await save;
  }

  void addParcel({
    required String name,
    required String crop,
    required List<LatLng> points,
  }) {
    parcels = [
      ...parcels,
      Parcel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        crop: crop,
        points: points,
      ),
    ];
    revision = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    unawaited(_save());
  }

  Future<void> updateParcel(Parcel parcel) {
    parcels = [
      for (final current in parcels)
        if (current.id == parcel.id) parcel else current,
    ];
    revision = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    return _save();
  }

  void removeParcel(String id) {
    parcels = parcels.where((p) => p.id != id).toList();
    revision = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    unawaited(_save());
  }

  void updateName(String value) {
    userName = value.trim();
    revision = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    unawaited(_save());
  }
}
