import 'dart:convert';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserStationsService {
  static const _key = 'user_radio_stations';

  /// Fires whenever the station list changes (add or remove).
  static final _notifier = ChangeNotifier();
  static Listenable get listenable => _notifier;

  static Future<List<NinjaSound>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => NinjaSound.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(NinjaSound station) async {
    final stations = await load();
    if (stations.any((s) => s.path == station.path)) return;
    stations.add(station);
    await _save(stations);
  }

  static Future<void> remove(String path) async {
    final stations = await load();
    stations.removeWhere((s) => s.path == path);
    await _save(stations);
  }

  static Future<void> _save(List<NinjaSound> stations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(stations.map((s) => s.toJson()).toList()),
    );
    _notifier.notifyListeners();
  }
}
