import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/data/sound_data.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/mix.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/services/mixes_service.dart';
import 'package:auraninja/services/user_stations_service.dart';
import 'package:auraninja/widgets/volume_slider.dart';

class NewMixSheet extends StatefulWidget {
  /// Called after a new mix is created. Not called for edits.
  final void Function(String mixId)? onMixSaved;

  /// When non-null the sheet opens in edit mode, pre-populated with this mix.
  final Mix? existingMix;

  const NewMixSheet({super.key, this.onMixSaved, this.existingMix});

  bool get _isEditMode => existingMix != null;

  @override
  State<NewMixSheet> createState() => _NewMixSheetState();
}

class _NewMixSheetState extends State<NewMixSheet> {
  final Map<String, bool> _selected = {};
  final Map<String, double> _volumes = {};
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _soundsStartedHere = {};

  List<NinjaSound> _allSounds = [];
  bool _loadingSounds = true;
  bool _saved = false;
  String? _nameError;
  bool _saving = false;

  late WrapperAudioHandler _handler;

  static const _categoryOrder = [
    '@weather',
    '@nature',
    '@noise',
    '@objects',
    '@places',
    '@binaural',
    '@internetRadio',
  ];

  @override
  void initState() {
    super.initState();
    _handler = Provider.of<WrapperAudioHandler>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSounds();
    });
  }

  Future<void> _loadSounds() async {
    try {
      final localSounds = buildLocalizedSounds(context);
      final userStations = await UserStationsService.load();
      if (!mounted) return;

      final allSounds = [...localSounds, ...userStations];

      if (widget._isEditMode) {
        for (final mixSound in widget.existingMix!.sounds) {
          _selected[mixSound.path] = true;
          _volumes[mixSound.path] = mixSound.volume.clamp(0.01, 1.0);
        }
        _nameController.text = widget.existingMix!.name;
      } else {
        final existing = await MixesService.load();
        if (!mounted) return;
        _nameController.text = 'Mix ${existing.length + 1}';
      }

      setState(() {
        _allSounds = allSounds;
        _loadingSounds = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allSounds = buildLocalizedSounds(null);
        _loadingSounds = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (!_saved) {
      for (final path in _soundsStartedHere) {
        unawaited(_handler.ninjaStop(path));
      }
    }
    super.dispose();
  }

  bool _isExclusive(String category) =>
      category == '@binaural' ||
      category == '@noise' ||
      category == '@internetRadio';

  String _categoryLabel(String category) {
    final l10n = AppLocalizations.of(context);
    switch (category) {
      case '@weather':
        return l10n?.weather ?? 'Weather';
      case '@nature':
        return l10n?.nature ?? 'Nature';
      case '@objects':
        return l10n?.objects ?? 'Objects';
      case '@places':
        return l10n?.places ?? 'Places';
      case '@binaural':
        return l10n?.binaural ?? 'Binaural';
      case '@noise':
        return l10n?.noise ?? 'Noise';
      case '@internetRadio':
        return l10n?.internetRadio ?? 'Internet Radio';
      default:
        return category;
    }
  }

  Future<void> _toggleSound(NinjaSound sound) async {
    final path = sound.path;
    final wasSelected = _selected[path] ?? false;

    if (wasSelected) {
      setState(() => _selected[path] = false);
      _soundsStartedHere.remove(path);
      unawaited(_handler.ninjaStop(path));
    } else {
      if (_isExclusive(sound.category)) {
        final previous = _allSounds
            .where((s) =>
                s.category == sound.category && (_selected[s.path] ?? false))
            .toList();
        for (final prev in previous) {
          _soundsStartedHere.remove(prev.path);
          unawaited(_handler.ninjaStop(prev.path));
          setState(() => _selected[prev.path] = false);
        }
      }

      setState(() {
        _selected[path] = true;
        _volumes.putIfAbsent(path, () => 0.5);
      });

      _soundsStartedHere.add(path);
      _handler.registerSounds([sound]);
      if (sound.isStream) {
        unawaited(_handler.ninjaPlay(path));
      } else {
        await _handler.ninjaPlay(path);
      }
      _handler.setVolume(path, _volumes[path]!);
    }
  }

  Future<void> _saveMix() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = l10n?.mixNameLabel ?? 'Mix name');
      return;
    }

    final existing = await MixesService.load();
    final existingNames = existing
        .where((m) => !widget._isEditMode || m.id != widget.existingMix!.id)
        .map((m) => m.name.toLowerCase())
        .toSet();
    if (existingNames.contains(name.toLowerCase())) {
      setState(
          () => _nameError = l10n?.duplicateMixName ?? 'Name already in use');
      return;
    }

    setState(() => _saving = true);

    final sounds = _allSounds
        .where((s) => _selected[s.path] ?? false)
        .map((s) => MixSound(path: s.path, volume: _volumes[s.path] ?? 0.5))
        .toList();

    if (widget._isEditMode) {
      await MixesService.update(Mix(
        id: widget.existingMix!.id,
        name: name,
        icon: widget.existingMix!.icon,
        sounds: sounds,
        createdAt: widget.existingMix!.createdAt,
      ));
    } else {
      final mix = Mix(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        sounds: sounds,
      );
      await MixesService.add(mix);
      _saved = true;
      if (mounted) widget.onMixSaved?.call(mix.id);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteMix() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteMixTitle ?? 'Delete mix?'),
        content: Text(l10n?.deleteMixContent ??
            'This mix will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n?.delete ?? 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await MixesService.remove(widget.existingMix!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  int get _selectedCount => _selected.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isEdit = widget._isEditMode;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Text(
                    isEdit
                        ? (l10n?.editMix ?? 'Edit mix')
                        : (l10n?.nameMix ?? 'Name your mix'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n?.mixNameLabel ?? 'Mix name',
                        errorText: _nameError,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                    ),
                  ),
                  if (isEdit)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                      tooltip: l10n?.delete ?? 'Delete',
                      onPressed: _deleteMix,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Sound list
            Expanded(
              child: _loadingSounds
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      children: [
                        for (final category in _categoryOrder)
                          _buildCategorySection(category),
                      ],
                    ),
            ),
            const Divider(height: 1),
            // Save button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        (_selectedCount > 0 && !_saving) ? _saveMix : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      isEdit
                          ? (l10n?.saveMix ?? 'Save changes')
                          : (_selectedCount > 0
                              ? '${l10n?.saveMix ?? 'Save Mix'} ($_selectedCount)'
                              : (l10n?.saveMix ?? 'Save Mix')),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySection(String category) {
    final sounds = _allSounds.where((s) => s.category == category).toList();
    if (sounds.isEmpty) return const SizedBox.shrink();

    final exclusive = _isExclusive(category);
    final label = _categoryLabel(category);
    final theme = Theme.of(context);
    final selectedCount =
        sounds.where((s) => _selected[s.path] ?? false).length;

    return ExpansionTile(
      initiallyExpanded: false,
      title: Row(
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          if (exclusive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'max 1',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
          if (selectedCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$selectedCount',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      children: [
        for (final sound in sounds) _buildSoundTile(sound),
      ],
    );
  }

  Widget _buildSoundTile(NinjaSound sound) {
    final path = sound.path;
    final isSelected = _selected[path] ?? false;
    final volume = _volumes[path] ?? 0.5;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          dense: true,
          leading: _buildSoundIcon(sound, theme),
          title: Text(sound.name),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleSound(sound),
          ),
          onTap: () => _toggleSound(sound),
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(left: 56, right: 16, bottom: 4),
            child: Row(
              children: [
                Icon(Icons.volume_up_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                Expanded(
                  child: VolumeSlider(
                    value: volume,
                    onChanged: (v) {
                      setState(() => _volumes[path] = v);
                      _handler.setVolume(path, v);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSoundIcon(NinjaSound sound, ThemeData theme) {
    final icon = sound.icon;
    if (icon is String && icon.startsWith('http')) {
      return const Text('📻', style: TextStyle(fontSize: 22));
    }
    if (icon is String) {
      return Text(icon, style: const TextStyle(fontSize: 22));
    }
    if (icon is IconData) {
      return Icon(icon, size: 24, color: theme.colorScheme.primary);
    }
    return const Icon(Icons.music_note, size: 24);
  }
}
