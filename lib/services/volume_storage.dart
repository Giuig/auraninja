import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the last used volume for each sound path.
class VolumeStorage {
  static const _key = 'sound_volumes';

  static Future<Map<String, double>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return {};

    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  static Future<void> save(String path, double volume) async {
    final volumes = await load();
    volumes[path] = volume;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(volumes));
  }

  static Future<void> saveAll(Map<String, double> volumes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(volumes));
  }

  static Future<double?> get(String path) async {
    final volumes = await load();
    return volumes[path];
  }
}
