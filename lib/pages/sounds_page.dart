import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/data/sound_data.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/pages/add_station_page.dart';
import 'package:auraninja/services/favorites_service.dart';
import 'package:auraninja/services/user_stations_service.dart';
import 'package:auraninja/widgets/sound_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundsPage extends StatefulWidget {
  const SoundsPage({super.key});

  @override
  State<SoundsPage> createState() => _SoundsPageState();
}

class _SoundsPageState extends State<SoundsPage> {
  List<NinjaSound> _localizedSounds = [];
  Map<String, NinjaSound> _localizedSoundMap = {};
  List<NinjaSound> _userStations = [];
  Set<String> _favorites = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Keys of categories the user has collapsed.
  Set<String> _collapsedCategories = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Translate category keys like '@nature' to localized strings.
  /// Keys starting with '@' are looked up in AppLocalizations.
  /// Plain strings are returned as-is (backward compat).
  String _translateCategory(String categoryKey) {
    if (!categoryKey.startsWith('@')) return categoryKey;
    final key = categoryKey.substring(1); // Remove '@'
    final l10n = AppLocalizations.of(context);
    switch (key) {
      case 'nature':
        return l10n?.nature ?? 'Nature';
      case 'objects':
        return l10n?.objects ?? 'Objects';
      case 'places':
        return l10n?.places ?? 'Places';
      case 'rain':
        return l10n?.rain ?? 'Rain';
      case 'binaural':
        return l10n?.binaural ?? 'Binaural';
      case 'noise':
        return l10n?.noise ?? 'Noise';
      case 'internetRadio':
        return l10n?.internetRadio ?? 'Internet Radio';
      case 'favorites':
        return l10n?.favorites ?? 'Favorites';
      default:
        return categoryKey;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserStations();
    _loadCollapsedCategories();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await FavoritesService.load();
    if (mounted) setState(() => _favorites = favorites);
  }

  void _toggleFavorite(String path) {
    setState(() {
      if (_favorites.contains(path)) {
        _favorites.remove(path);
      } else {
        _favorites.add(path);
      }
    });
    FavoritesService.save(_favorites);
  }

  Future<void> _loadCollapsedCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('collapsed_categories') ?? [];
    if (mounted) setState(() => _collapsedCategories = saved.toSet());
  }

  void _toggleCategory(String key) {
    setState(() {
      if (_collapsedCategories.contains(key)) {
        _collapsedCategories.remove(key);
      } else {
        _collapsedCategories.add(key);
      }
    });
    SharedPreferences.getInstance().then((prefs) => prefs.setStringList(
        'collapsed_categories', _collapsedCategories.toList()));
  }

  Future<void> _loadUserStations() async {
    final stations = await UserStationsService.load();
    if (!mounted) return;
    setState(() => _userStations = stations);
    _refreshSounds();
  }

  void _refreshSounds() {
    if (!mounted) return;
    final hardcoded = buildLocalizedSounds(context);
    _localizedSounds = [...hardcoded, ..._userStations];
    _localizedSoundMap = {for (final s in _localizedSounds) s.path: s};
    final wrapper = Provider.of<WrapperAudioHandler>(context, listen: false);
    wrapper.registerSounds(_localizedSounds);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshSounds();
  }

  Future<void> _openAddStation() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AddStationPage(categoryKey: '@internetRadio'),
      ),
    );
    if (added == true) await _loadUserStations();
  }

  Future<void> _deleteStation(NinjaSound sound) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Station'),
        content: Text('Remove "${sound.name}" from your stations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final wrapper = Provider.of<WrapperAudioHandler>(context, listen: false);
      // Remove from local state FIRST so that any _refreshSounds() call
      // triggered by unregisterSound's notifyListeners won't re-register
      // the station with a fresh controller (which would make it appear as
      // "Uncategorized" with no delete button).
      setState(() {
        _userStations.removeWhere((s) => s.path == sound.path);
        _favorites.remove(sound.path);
      });
      _refreshSounds();
      await wrapper.unregisterSound(sound.path);
      await UserStationsService.remove(sound.path);
      await FavoritesService.save(_favorites);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wrapper = Provider.of<WrapperAudioHandler>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final controllers = wrapper.allControllers;

    // Filter controllers by search query
    List<SoundController> filteredControllers = controllers;
    if (_searchQuery.isNotEmpty) {
      filteredControllers = controllers.where((c) {
        final sound = _localizedSoundMap[c.sound.path];
        final name = sound?.name ?? c.sound.name;
        return name.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    final categories = <String, List<SoundController>>{};
    for (final c in filteredControllers) {
      final category =
          _localizedSoundMap[c.sound.path]?.category ?? 'Uncategorized';
      categories.putIfAbsent(category, () => []).add(c);
    }

    // Build ordered list of categories, with Favorites first if any exist
    final orderedCategories = <MapEntry<String, List<SoundController>>>[];

    // Add Favorites category first if there are favorites (only when not searching)
    if (_favorites.isNotEmpty && _searchQuery.isEmpty) {
      final favControllers =
          controllers.where((c) => _favorites.contains(c.sound.path)).toList();
      if (favControllers.isNotEmpty) {
        orderedCategories.add(MapEntry('@favorites', favControllers));
      }
    }

    // Add other categories (excluding favorited sounds from them)
    // Define category order: regular categories first, then Binaural, Noise, Internet Radio last
    const categoryOrder = [
      '@nature',
      '@objects',
      '@places',
      '@rain',
      '@binaural',
      '@noise',
      '@internetRadio',
    ];

    final sortedCategories = categories.entries.toList();
    sortedCategories.sort((a, b) {
      final aIndex = categoryOrder.indexOf(a.key);
      final bIndex = categoryOrder.indexOf(b.key);
      // If category is in our order list, sort by that order
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
      // If only one is in the list, it comes first (for known) or last (for unknown)
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      // Otherwise sort alphabetically
      return a.key.compareTo(b.key);
    });

    for (final entry in sortedCategories) {
      // When searching, show all matching sounds including favorites
      // When not searching, exclude favorites from their original categories
      final filteredSounds = _searchQuery.isEmpty
          ? entry.value
              .where((c) => !_favorites.contains(c.sound.path))
              .toList()
          : entry.value;
      if (filteredSounds.isNotEmpty) {
        orderedCategories.add(MapEntry(entry.key, filteredSounds));
      }
    }

    final bool noResults = _searchQuery.isNotEmpty && orderedCategories.isEmpty;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)?.searchSounds ??
                            'Search sounds...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                    ),
                  ),
                  // No results message
                  if (noResults)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No sounds found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Categories
                  ...orderedCategories.map((entry) {
                    final categoryKey = entry.key;
                    final categorySounds = entry.value;
                    final isFavoritesCategory = categoryKey == '@favorites';
                    final isRadioCategory = categorySounds.any(
                      (c) => c.sound.isStream,
                    );

                    final isCollapsed =
                        _collapsedCategories.contains(categoryKey);
                    final hasActiveSounds = categorySounds.any((c) =>
                        c.status == PlaybackStatus.playing ||
                        c.status == PlaybackStatus.loading);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Category header ───────────────────────────────
                          Row(
                            children: [
                              // Tappable area: label + playing indicator + arrow
                              Expanded(
                                child: InkWell(
                                  onTap: () => _toggleCategory(categoryKey),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _translateCategory(categoryKey),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall,
                                          ),
                                        ),
                                        // Playing indicator — only when collapsed
                                        AnimatedOpacity(
                                          opacity:
                                              isCollapsed && hasActiveSounds
                                                  ? 1.0
                                                  : 0.0,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: Icon(
                                              Icons.graphic_eq,
                                              size: 20,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        // Collapse arrow
                                        AnimatedRotation(
                                          turns: isCollapsed ? -0.25 : 0,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: Icon(
                                            Icons.expand_more,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (isRadioCategory && !isFavoritesCategory)
                                IconButton.filled(
                                  onPressed: _openAddStation,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Add radio station',
                                ),
                            ],
                          ),

                          // ── Collapsible content ───────────────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: isCollapsed
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8, bottom: 16),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        const minCardWidth = 160;
                                        final maxWidth = constraints.maxWidth;
                                        int cols =
                                            (maxWidth / (minCardWidth + 16))
                                                .floor();
                                        cols = cols > 0 ? cols : 1;
                                        final cardWidth =
                                            (maxWidth - (cols - 1) * 16) / cols;

                                        return Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          children:
                                              categorySounds.map((controller) {
                                            final sound = _localizedSoundMap[
                                                controller.sound.path];
                                            final isUserAdded =
                                                sound?.isUserAdded ?? false;

                                            return SizedBox(
                                              width: cardWidth,
                                              child: Stack(
                                                children: [
                                                  ChangeNotifierProvider.value(
                                                    value: controller,
                                                    child: SoundCard(
                                                      localizedSoundMap:
                                                          _localizedSoundMap,
                                                      isFavorite: _favorites
                                                          .contains(controller
                                                              .sound.path),
                                                      onFavoriteToggle: () =>
                                                          _toggleFavorite(
                                                              controller
                                                                  .sound.path),
                                                    ),
                                                  ),
                                                  if (isUserAdded &&
                                                      sound != null)
                                                    Positioned(
                                                      top: 4,
                                                      right: 4,
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            _deleteStation(
                                                                sound),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(3),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: colorScheme
                                                                .errorContainer,
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color: colorScheme
                                                                  .error,
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Icon(
                                                            Icons.close,
                                                            size: 14,
                                                            color: colorScheme
                                                                .onErrorContainer,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
