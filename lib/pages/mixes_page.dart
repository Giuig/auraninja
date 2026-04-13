import 'dart:async';

import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/data/sound_data.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/mix.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/services/mixes_service.dart';
import 'package:auraninja/services/user_stations_service.dart';
import 'package:auraninja/widgets/new_mix_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

String _resolveIcon(dynamic icon) {
  if (icon is String && icon.startsWith('http')) return '📻';
  if (icon is String && icon.isNotEmpty) return icon;
  return '🔊';
}

class MixesPage extends StatefulWidget {
  const MixesPage({super.key});

  @override
  State<MixesPage> createState() => _MixesPageState();
}

class _MixesPageState extends State<MixesPage> {
  List<Mix> _mixes = [];
  bool _loading = true;

  // Loading spinner while a mix is being set up
  String? _playingMixId;

  // Which mix is "active" (playing or was playing but modified) — persists
  // until stopAll() empties activeControllers
  String? _activeMixId;

  // Handler reference stored so we can add/remove listener safely
  WrapperAudioHandler? _handler;

  // Accordion edit state
  String? _expandedMixId;
  List<MixSound>? _editSounds;
  bool _editHasChanges = false;
  Map<String, NinjaSound> _soundMap = {};

  @override
  void initState() {
    super.initState();
    _loadMixes();
    MixesService.mixesNotifier.addListener(_onMixesChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newHandler =
        Provider.of<WrapperAudioHandler>(context, listen: false);
    if (newHandler != _handler) {
      _handler?.removeListener(_onHandlerChanged);
      _handler = newHandler;
      _handler!.addListener(_onHandlerChanged);
    }
  }

  @override
  void dispose() {
    _handler?.removeListener(_onHandlerChanged);
    MixesService.mixesNotifier.removeListener(_onMixesChanged);
    super.dispose();
  }

  // Clear activeMixId when all sounds stop
  void _onHandlerChanged() {
    if (!mounted) return;
    if (_activeMixId != null &&
        (_handler?.activeControllers.isEmpty ?? false)) {
      setState(() => _activeMixId = null);
    }
  }

  void _onMixesChanged() {
    if (mounted) {
      setState(() => _mixes = List.from(MixesService.mixesNotifier.value));
    }
  }

  Future<void> _loadMixes() async {
    final mixes = await MixesService.load();
    if (mounted) {
      setState(() {
        _mixes = mixes;
        _loading = false;
      });
    }
  }

  Future<void> _playMix(Mix mix) async {
    setState(() => _playingMixId = mix.id);
    final handler = Provider.of<WrapperAudioHandler>(context, listen: false);

    await handler.stopAll();

    final hardcoded = buildLocalizedSounds(context);
    final userStations = await UserStationsService.load();
    final allSounds = [...hardcoded, ...userStations];
    final soundMap = {for (final s in allSounds) s.path: s};

    int unavailableCount = 0;

    for (final mixSound in mix.sounds) {
      NinjaSound? sound = soundMap[mixSound.path];

      if (sound == null && mixSound.isStream) {
        sound = NinjaSound(
          name: 'Radio',
          category: '@internetRadio',
          icon: '📻',
          path: mixSound.path,
          isUserAdded: true,
        );
      }

      if (sound != null) {
        handler.registerSounds([sound]);
        if (mixSound.isStream) {
          unawaited(handler.ninjaPlay(mixSound.path));
        } else {
          await handler.ninjaPlay(mixSound.path);
        }
        handler.setVolume(mixSound.path, mixSound.volume);
      } else {
        unavailableCount++;
      }
    }

    if (mounted) {
      setState(() {
        _playingMixId = null;
        _activeMixId = mix.id; // Set after setup completes
      });
      if (unavailableCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '$unavailableCount sound${unavailableCount == 1 ? '' : 's'} in this mix couldn\'t be loaded',
          ),
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_editHasChanges) return true;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes to this mix.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _toggleExpand(Mix mix) async {
    if (_expandedMixId == mix.id) {
      if (!await _confirmDiscardChanges()) return;
      if (!mounted) return;
      setState(() {
        _expandedMixId = null;
        _editSounds = null;
        _editHasChanges = false;
      });
      return;
    }

    if (_expandedMixId != null && _editHasChanges) {
      if (!await _confirmDiscardChanges()) return;
      if (!mounted) return;
    }

    final hardcoded = buildLocalizedSounds(context);
    final userStations = await UserStationsService.load();
    final allSounds = [...hardcoded, ...userStations];

    if (!mounted) return;

    // If this mix is active, seed edit state from live volumes; otherwise from saved
    final List<MixSound> initialSounds;
    if (_activeMixId == mix.id && _handler != null) {
      initialSounds = _handler!.activeControllers
          .map((c) => MixSound(path: c.sound.path, volume: c.volume))
          .toList();
    } else {
      initialSounds =
          mix.sounds.map((s) => MixSound(path: s.path, volume: s.volume)).toList();
    }

    setState(() {
      _expandedMixId = mix.id;
      _editSounds = initialSounds;
      _editHasChanges = false;
      _soundMap = {for (final s in allSounds) s.path: s};
    });
  }

  Future<void> _saveEditedMix(Mix mix) async {
    if (_editSounds == null) return;
    await MixesService.update(Mix(
      id: mix.id,
      name: mix.name,
      icon: mix.icon,
      createdAt: mix.createdAt,
      sounds: List.from(_editSounds!),
    ));
    if (mounted) {
      setState(() => _editHasChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)?.mixUpdated ?? 'Mix updated'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _renameMix(Mix mix) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: mix.name);
    final existingNames =
        _mixes.where((m) => m.id != mix.id).map((m) => m.name).toSet();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? errorText;
        return StatefulBuilder(
          builder: (_, setDialogState) => AlertDialog(
            title: Text(l10n?.renameMix ?? 'Rename mix'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n?.mixNameLabel ?? 'Mix name',
                errorText: errorText,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (errorText != null) setDialogState(() => errorText = null);
              },
              onSubmitted: (_) {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                if (existingNames.contains(name)) {
                  setDialogState(() => errorText =
                      l10n?.duplicateMixName ?? 'Name already in use');
                } else {
                  Navigator.of(ctx).pop(true);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  if (existingNames.contains(name)) {
                    setDialogState(() => errorText =
                        l10n?.duplicateMixName ?? 'Name already in use');
                  } else {
                    Navigator.of(ctx).pop(true);
                  }
                },
                child: Text(l10n?.saveMix ?? 'Save'),
              ),
            ],
          ),
        );
      },
    );
    final name = controller.text.trim();
    if (confirmed == true && name.isNotEmpty && mounted) {
      await MixesService.update(Mix(
        id: mix.id,
        name: name,
        icon: mix.icon,
        sounds: mix.sounds,
        createdAt: mix.createdAt,
      ));
    }
  }

  Future<bool> _confirmDelete(Mix mix) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteMixTitle ?? 'Delete mix?'),
        content: Text(
            l10n?.deleteMixContent ?? 'This mix will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n?.delete ?? 'Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _openNewMixSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NewMixSheet(
        onMixSaved: (mixId) {
          if (mounted) setState(() => _activeMixId = mixId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<WrapperAudioHandler>(
      builder: (context, handler, _) {
        final activePaths =
            handler.activeControllers.map((c) => c.sound.path).toSet();

        final Widget body;
        if (_mixes.isEmpty) {
          body = Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_music_outlined,
                    size: 64, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  l10n?.noMixes ?? 'No mixes saved',
                  style: TextStyle(color: colorScheme.outline, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n?.noMixesHint ??
                      "Tap + to create a mix, or play sounds and use 'Save Mix'",
                  style: TextStyle(
                      color: colorScheme.outline.withValues(alpha: 0.7),
                      fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          );
        } else {
          body = ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: _mixes.length,
            itemBuilder: (context, index) {
              final mix = _mixes[index];
              final isLoading = _playingMixId == mix.id;
              final mixPaths = mix.sounds.map((s) => s.path).toSet();

              final isActiveClean = !isLoading &&
                  _activeMixId == mix.id &&
                  activePaths.isNotEmpty &&
                  activePaths.length == mixPaths.length &&
                  activePaths.containsAll(mixPaths);

              final isActiveModified = !isLoading &&
                  _activeMixId == mix.id &&
                  !isActiveClean;

              final isExpanded = _expandedMixId == mix.id;

              Color? cardColor;
              if (isActiveClean) {
                cardColor = colorScheme.primaryContainer.withValues(alpha: 0.45);
              } else if (isActiveModified) {
                cardColor =
                    colorScheme.tertiaryContainer.withValues(alpha: 0.45);
              }

              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: Text(mix.icon ?? '🎵',
                          style: const TextStyle(fontSize: 24)),
                      title: Text(mix.name),
                      subtitle: Text('${mix.sounds.length} sounds'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'rename') _renameMix(mix);
                              if (value == 'delete') {
                                _confirmDelete(mix).then((confirmed) {
                                  if (confirmed) {
                                    if (_expandedMixId == mix.id) {
                                      setState(() {
                                        _expandedMixId = null;
                                        _editSounds = null;
                                        _editHasChanges = false;
                                      });
                                    }
                                    if (_activeMixId == mix.id) {
                                      setState(() => _activeMixId = null);
                                    }
                                    MixesService.remove(mix.id);
                                  }
                                });
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(children: [
                                  const Icon(Icons.edit_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  Text(l10n?.renameMix ?? 'Rename'),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      size: 18, color: colorScheme.error),
                                  const SizedBox(width: 8),
                                  Text(l10n?.delete ?? 'Delete',
                                      style: TextStyle(
                                          color: colorScheme.error)),
                                ]),
                              ),
                            ],
                          ),
                          if (isLoading)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (isActiveClean)
                            Tooltip(
                              message: 'Playing',
                              child: Icon(Icons.equalizer,
                                  color: colorScheme.primary),
                            )
                          else if (isActiveModified)
                            Tooltip(
                              message: 'Mix modified',
                              child: Icon(Icons.sync,
                                  color: colorScheme.tertiary),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => _playMix(mix),
                            ),
                          IconButton(
                            icon: Icon(isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more),
                            onPressed: () => _toggleExpand(mix),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: isExpanded && _editSounds != null
                          ? _buildExpandedSection(
                              context,
                              mix,
                              handler,
                              colorScheme,
                              l10n,
                              isActiveMix: isActiveClean || isActiveModified,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          );
        }

        return Stack(
          children: [
            body,
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: _openNewMixSheet,
                tooltip: 'New mix',
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpandedSection(
    BuildContext context,
    Mix mix,
    WrapperAudioHandler handler,
    ColorScheme colorScheme,
    AppLocalizations? l10n, {
    required bool isActiveMix,
  }) {
    final editSounds = _editSounds!;
    final editPaths = editSounds.map((s) => s.path).toSet();
    final addableSounds = handler.activeControllers
        .where((c) => !editPaths.contains(c.sound.path))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        // Live/saved indicator
        if (isActiveMix)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(Icons.equalizer, size: 14, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Showing live volumes',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
        if (editSounds.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No sounds in this mix',
                style: TextStyle(color: colorScheme.outline)),
          )
        else
          ...editSounds.asMap().entries.map((entry) {
            final i = entry.key;
            final mixSound = entry.value;
            final ninjaSound = _soundMap[mixSound.path];
            final displayIcon = _resolveIcon(ninjaSound?.icon ?? '🔊');
            final name = ninjaSound?.name ??
                (mixSound.isStream
                    ? 'Radio'
                    : mixSound.path.split('/').last);

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
              child: Row(
                children: [
                  Text(displayIcon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Theme.of(context).textTheme.bodyMedium),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                          ),
                          child: Slider(
                            value: mixSound.volume,
                            min: 0.1,
                            max: 1.0,
                            onChanged: (v) {
                              setState(() {
                                _editSounds![i] =
                                    MixSound(path: mixSound.path, volume: v);
                                _editHasChanges = true;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: colorScheme.error, size: 20),
                    onPressed: () {
                      setState(() {
                        _editSounds!.removeAt(i);
                        _editHasChanges = true;
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        if (addableSounds.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Add from playing',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: colorScheme.outline),
            ),
          ),
          ...addableSounds.map((c) {
            final displayIcon = _resolveIcon(c.sound.icon);
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Text(displayIcon, style: const TextStyle(fontSize: 18)),
              title: Text(c.sound.name,
                  style: Theme.of(context).textTheme.bodyMedium),
              trailing: IconButton(
                icon: Icon(Icons.add_circle_outline,
                    color: colorScheme.primary, size: 20),
                onPressed: () {
                  setState(() {
                    _editSounds!
                        .add(MixSound(path: c.sound.path, volume: c.volume));
                    _editHasChanges = true;
                  });
                },
              ),
            );
          }),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _editHasChanges ? () => _saveEditedMix(mix) : null,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save changes'),
            ),
          ),
        ),
      ],
    );
  }
}
