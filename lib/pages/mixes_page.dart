import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/data/sound_data.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/mix.dart';
import 'package:auraninja/services/mixes_service.dart';
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
      setState(() {
        _mixes = List.from(MixesService.mixesNotifier.value);
      });
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
    final handler = Provider.of<WrapperAudioHandler>(context, listen: false);

    // Stop all currently playing sounds
    await handler.stopAll();

    // Get all available sounds
    final allSounds = buildLocalizedSounds(context);
    final soundMap = {for (final s in allSounds) s.path: s};

    // Play each sound in the mix with saved volume
    for (final mixSound in mix.sounds) {
      final sound = soundMap[mixSound.path];
      if (sound != null) {
        handler.registerSounds([sound]);
        await handler.ninjaPlay(mixSound.path);
        handler.setVolume(mixSound.path, mixSound.volume);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mixes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.noMixes ?? 'No mixes saved',
              style: TextStyle(
                color: colorScheme.outline,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.noMixesHint ?? 'Play sounds and save as a mix',
              style: TextStyle(
                color: colorScheme.outline.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mixes.length,
      itemBuilder: (context, index) {
        final mix = _mixes[index];
        return Card(
          child: ListTile(
            leading:
                Text(mix.icon ?? '🎵', style: const TextStyle(fontSize: 24)),
            title: Text(mix.name),
            subtitle: Text('${mix.sounds.length} sounds'),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _playMix(mix),
            ),
          ),
        );
      },
    );
  }
}
