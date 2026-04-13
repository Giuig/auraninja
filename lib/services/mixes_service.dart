import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auraninja/model/mix.dart';

class MixesService {
  static const _key = 'mixes';
  static final ValueNotifier<List<Mix>> mixesNotifier = ValueNotifier([]);

  static Future<List<Mix>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_key);
      if (jsonList == null) return [];
      return jsonList
          .map((json) => Mix.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Mix> mixes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = mixes.map((m) => jsonEncode(m.toJson())).toList();
      await prefs.setStringList(_key, jsonList);
    } catch (_) {
      // Persistence failure — in-memory notifier still updated below
    }
    mixesNotifier.value = List.from(mixes);
  }

  static Future<void> add(Mix mix) async {
    final mixes = await load();
    mixes.add(mix);
    await save(mixes);
  }

  static Future<void> remove(String id) async {
    final mixes = await load();
    mixes.removeWhere((m) => m.id == id);
    await save(mixes);
  }

  static Future<void> update(Mix mix) async {
    final mixes = await load();
    final index = mixes.indexWhere((m) => m.id == mix.id);
    if (index != -1) {
      mixes[index] = mix;
      await save(mixes);
    }
  }
}
