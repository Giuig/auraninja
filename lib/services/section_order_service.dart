import 'package:shared_preferences/shared_preferences.dart';

/// The user's own order for a Sounds-page section (issue #14), stored as a
/// list of sound paths. Favourites keep theirs in [FavoritesService], whose
/// list is already ordered; this covers the sections that have no list of
/// their own, i.e. Internet Radio (built-in and user-added stations together).
class SectionOrderService {
  static String _key(String section) => 'section_order_$section';

  static Future<List<String>> load(String section) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key(section)) ?? [];
  }

  static Future<void> save(String section, List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(section), paths);
  }
}

/// Returns [items] sorted by [order]. Items whose path is not in [order]
/// (a station added after the last reorder) keep their relative position,
/// after the ordered ones; paths in [order] that match no item are ignored.
List<T> orderByPaths<T>(
    List<T> items, List<String> order, String Function(T) pathOf) {
  if (order.isEmpty) return List.of(items);
  final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
  final ranked = items.where((it) => rank.containsKey(pathOf(it))).toList()
    ..sort((a, b) => rank[pathOf(a)]!.compareTo(rank[pathOf(b)]!));
  return [...ranked, ...items.where((it) => !rank.containsKey(pathOf(it)))];
}
