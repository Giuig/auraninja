import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorites';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.toSet() ?? {};
  }

  static Future<void> save(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, favorites.toList());
  }

  static Future<void> add(String path) async {
    final favorites = await load();
    favorites.add(path);
    await save(favorites);
  }

  static Future<void> remove(String path) async {
    final favorites = await load();
    favorites.remove(path);
    await save(favorites);
  }

  static Future<bool> isFavorite(String path) async {
    final favorites = await load();
    return favorites.contains(path);
  }
}
