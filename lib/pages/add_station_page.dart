import 'dart:async';
import 'dart:convert';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/services/user_stations_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddStationPage extends StatefulWidget {
  final String categoryKey; // Translation key, e.g. '@internetRadio'

  const AddStationPage({super.key, required this.categoryKey});

  @override
  State<AddStationPage> createState() => _AddStationPageState();
}

class _AddStationPageState extends State<AddStationPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Search tab
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  bool _hasSearched = false;
  String? _searchError;
  Timer? _debounce;

  // URL tab
  final _urlCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _searchError = null;
      });
      return;
    }
    // Wait for at least 2 characters before hitting the API.
    if (trimmed.length < 2) return;
    // Search 500 ms after the user stops typing.
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _hasSearched = true;
      _searchError = null;
      _searchResults = [];
    });
    try {
      final uri =
          Uri.https('de1.api.radio-browser.info', '/json/stations/search', {
            'name': query,
            'limit': '40',
            'hidebroken': 'true',
            'order': 'votes',
            'reverse': 'true',
          });
      final resp = await http
          .get(uri, headers: {'User-Agent': 'Auraninja/1.0'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        setState(() {
          _searchResults = list.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() => _searchError = 'Server error ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _searchError = 'Connection error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFromSearch(Map<String, dynamic> station) async {
    final favicon = (station['favicon'] as String?) ?? '';
    final url =
        (station['url_resolved'] as String?) ??
        (station['url'] as String?) ??
        '';
    if (url.isEmpty) return;

    final sound = NinjaSound(
      name: (station['name'] as String?) ?? 'Unknown Station',
      category: widget.categoryKey,
      icon: favicon.isNotEmpty ? favicon : '📻',
      path: url,
      attribution: (station['homepage'] as String?) ?? '',
      isUserAdded: true,
    );

    await UserStationsService.add(sound);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _addFromUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || !url.startsWith('http')) return;
    setState(() => _adding = true);

    final name = _nameCtrl.text.trim();
    final sound = NinjaSound(
      name: name.isNotEmpty ? name : url,
      category: widget.categoryKey,
      icon: '📻',
      path: url,
      attribution: '',
      isUserAdded: true,
    );

    await UserStationsService.add(sound);
    if (mounted) {
      setState(() => _adding = false);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final showNoResults = !_searching &&
        _hasSearched &&
        _searchResults.isEmpty &&
        _searchError == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.addRadioStation ?? 'Add Radio Station'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.search), text: l10n?.search ?? 'Search'),
            Tab(icon: const Icon(Icons.link), text: l10n?.url ?? 'URL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Search tab ──────────────────────────────────────────────
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: l10n?.searchStationsHint ?? 'Search stations by name…',
                  onChanged: _onSearchChanged,
                  trailing: [
                    _searching
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _search,
                          ),
                  ],
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _search();
                  },
                ),
              ),
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _searchError!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              if (showNoResults)
                Expanded(
                  child: Center(
                    child: Text(
                      l10n?.noStationsFound ?? 'No stations found',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, i) {
                    final s = _searchResults[i];
                    final favicon = (s['favicon'] as String?) ?? '';
                    final name = (s['name'] as String?) ?? '';
                    final country = (s['country'] as String?) ?? '';
                    final tags = (s['tags'] as String?) ?? '';
                    final subtitle = [
                      if (country.isNotEmpty) country,
                      if (tags.isNotEmpty) tags,
                    ].join(' · ');

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 40,
                          height: 40,
                          color: colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const Text('📻', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      title: Text(name),
                      subtitle: subtitle.isNotEmpty
                          ? Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: colorScheme.primary,
                        ),
                        onPressed: () => _addFromSearch(s),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ── URL tab ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: l10n?.streamUrl ?? 'Stream URL',
                    hintText: l10n?.streamUrlHint ?? 'https://…',
                    prefixIcon: const Icon(Icons.radio),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n?.stationNameOptional ?? 'Station name (optional)',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _adding ? null : _addFromUrl,
                  icon: _adding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(l10n?.addStation ?? 'Add Station'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
