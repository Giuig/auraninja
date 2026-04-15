import 'dart:async';

import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/data/sound_data.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/mix.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/model/sound_category.dart';
import 'package:auraninja/services/mixes_service.dart';
import 'package:auraninja/services/user_stations_service.dart';
import 'package:auraninja/widgets/new_mix_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MixesPage extends StatefulWidget {
  const MixesPage({super.key});

  @override
  State<MixesPage> createState() => _MixesPageState();
}

class _MixesPageState extends State<MixesPage> {
  List<Mix> _mixes = [];
  bool _loading = true;
  Map<String, NinjaSound> _soundMap = {};

  /// Non-null while a mix is being loaded — disables all play buttons.
  String? _playingMixId;

  @override
  void initState() {
    super.initState();
    _loadMixes();
    MixesService.mixesNotifier.addListener(_onMixesChanged);
  }

  @override
  void dispose() {
    MixesService.mixesNotifier.removeListener(_onMixesChanged);
    super.dispose();
  }

  void _onMixesChanged() {
    if (mounted) {
      setState(() => _mixes = List.from(MixesService.mixesNotifier.value));
    }
  }

  Future<void> _loadMixes() async {
    final userStations = await UserStationsService.load();
    final mixes = await MixesService.load();
    if (mounted) {
      final allSounds = [...buildLocalizedSounds(null), ...userStations];
      setState(() {
        _mixes = mixes;
        _soundMap = {for (final s in allSounds) s.path: s};
        _loading = false;
      });
    }
  }

  String _emojiFor(String path) {
    if (path.startsWith('http')) return '📻';
    final icon = _soundMap[path]?.icon;
    if (icon is String && icon.isNotEmpty) return icon;
    return '🔊';
  }

  Widget _buildEmojiStrip(Mix mix) {
    const maxVisible = 5;
    final paths = mix.sounds.map((s) => s.path).toList();
    final visible = paths.take(maxVisible).toList();
    final overflow = paths.length - maxVisible;
    return Row(
      children: [
        for (final path in visible)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(_emojiFor(path), style: const TextStyle(fontSize: 15)),
          ),
        if (overflow > 0)
          Text(
            '+$overflow',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
      ],
    );
  }

  Future<void> _playMix(Mix mix) async {
    setState(() => _playingMixId = mix.id);
    final handler = Provider.of<WrapperAudioHandler>(context, listen: false);

    await handler.stopAll();

    int unavailableCount = 0;

    for (final mixSound in mix.sounds) {
      NinjaSound? sound = _soundMap[mixSound.path];

      if (sound == null && mixSound.isStream) {
        sound = NinjaSound(
          name: 'Radio',
          category: SoundCategory.internetRadio,
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
      setState(() => _playingMixId = null);
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

  void _openMixSheet({Mix? existingMix}) {
    if (existingMix == null) {
      Provider.of<WrapperAudioHandler>(context, listen: false).stopAll();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NewMixSheet(existingMix: existingMix),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
              l10n?.noMixesHint ?? 'Tap + to create your first mix',
              style: TextStyle(
                  color: colorScheme.outline.withValues(alpha: 0.7),
                  fontSize: 14),
              textAlign: TextAlign.center,
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
          final anyLoading = _playingMixId != null;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading:
                  Text(mix.icon ?? '🎵', style: const TextStyle(fontSize: 24)),
              title: Text(mix.name),
              subtitle: mix.sounds.isEmpty
                  ? Text(l10n?.mixSoundCount(0) ?? '0 sounds')
                  : _buildEmojiStrip(mix),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: anyLoading ? null : () => _playMix(mix),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openMixSheet(existingMix: mix),
                  ),
                ],
              ),
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
            onPressed: () => _openMixSheet(),
            tooltip: 'New mix',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
