import 'dart:async';

import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/data/sound_data.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/mix.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/model/sound_category.dart';
import 'package:auraninja/services/mixes_service.dart';
import 'package:auraninja/services/user_stations_service.dart';
import 'package:auraninja/utils/mix_codec.dart';
import 'package:auraninja/widgets/new_mix_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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
    final l10n = AppLocalizations.of(context);

    // Resolve each mix sound to a NinjaSound (known local/user sound, or an
    // ad-hoc entry for a radio stream), counting any that can't be found.
    final resolved = <MixSound, NinjaSound>{};
    var unavailableCount = 0;
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
        resolved[mixSound] = sound;
      } else {
        unavailableCount++;
      }
    }

    await handler.stopAll();
    handler.registerSounds(resolved.values.toList());

    // Start every sound concurrently so the mix begins together instead of
    // fading in one-by-one. Time-box each so a single dead stream can't hang
    // the whole batch, and swallow per-sound errors.
    //
    // 4s, not longer: the loading spinner blocks on this Future.wait, so a
    // single slow/dead stream in the mix holds up the whole indicator for
    // however long this is. Every real stream observed while testing this
    // connected within ~2s — a connection that hasn't established by 4s is
    // overwhelmingly likely dead rather than merely slow, so this trims the
    // worst-case stuck-spinner time without meaningfully risking cutting off
    // a stream that would have succeeded given longer.
    await Future.wait(resolved.keys.map((mixSound) async {
      try {
        await handler
            .ninjaPlay(mixSound.path)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // A single failed/slow sound shouldn't abort the rest of the mix.
      }
    }));

    // Apply the mix's per-sound volumes WITHOUT persisting, so playing a mix
    // never overwrites the Sounds page's global per-sound volumes. Done after
    // playback starts so it wins over registerSounds' async volume restore.
    for (final entry in resolved.entries) {
      handler.setVolume(entry.key.path, entry.key.volume, persist: false);
    }

    handler.setActiveMix(resolved.isEmpty ? null : mix.id);
    if (!mounted) return;
    setState(() => _playingMixId = null);
    if (unavailableCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          l10n?.mixSoundsUnavailable(unavailableCount) ??
              '$unavailableCount sound${unavailableCount == 1 ? '' : 's'} couldn\'t be loaded',
        ),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Future<void> _stopMix() async {
    final handler = Provider.of<WrapperAudioHandler>(context, listen: false);
    await handler.stopAll();
    // No local state to clear — "active" is derived from what's actually
    // playing, so it updates itself once stopAll() takes effect.
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

  Future<void> _shareMix(Mix mix) async {
    final code = MixCodec.encode(mix);
    try {
      await SharePlus.instance.share(
        ShareParams(text: code, subject: mix.name),
      );
    } catch (_) {
      // share_plus deliberately throws on web when the Web Share API isn't
      // available (most desktop browsers) and no fallback is configured —
      // silently do nothing without this, since the exception otherwise
      // propagates unhandled. Clipboard works everywhere, so use it as the
      // universal fallback rather than only patching the web case.
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n?.copiedToClipboard ?? 'Copied to clipboard'),
      ));
    }
  }

  Future<void> _importMix() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.importMix ?? 'Import mix'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                l10n?.importMixPrompt ?? 'Paste the mix code you received',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n?.importAction ?? 'Import'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;

    final mix = MixCodec.tryDecode(code);
    if (!mounted) return;
    if (mix == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n?.invalidMixCode ?? "That isn't a valid mix code"),
      ));
      return;
    }
    final stored = await MixesService.importMix(mix);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(l10n?.mixImported(stored.name) ?? 'Imported "${stored.name}"'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final handler = context.watch<WrapperAudioHandler>();
    final playingPaths = handler.activeControllers
        .where((c) => c.status == PlaybackStatus.playing)
        .map((c) => c.sound.path)
        .toSet();

    // "Active mix" has to be tracked by id (handler.activeMixId), not
    // inferred from sound content — two mixes with identical selections are
    // indistinguishable once playing, so matching by path set alone would
    // highlight every one of them at once. Still validate the remembered id
    // against what's actually playing right now, so it self-clears
    // (harmlessly) if playback diverged from that mix without going through
    // stopAll() — e.g. a sound stopped individually from the Sounds page.
    String? effectiveActiveMixId;
    final rememberedId = handler.activeMixId;
    if (rememberedId != null) {
      Mix? rememberedMix;
      for (final m in _mixes) {
        if (m.id == rememberedId) {
          rememberedMix = m;
          break;
        }
      }
      final rememberedPaths =
          rememberedMix?.sounds.map((s) => s.path).toSet() ?? const {};
      if (rememberedPaths.isNotEmpty &&
          setEquals(playingPaths, rememberedPaths)) {
        effectiveActiveMixId = rememberedId;
      }
    }

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
          final isActive = mix.id == effectiveActiveMixId;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isActive
                ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                : null,
            // Card doesn't clip its child by default, so the ListTile's
            // hover/splash highlight was rendering as a full square past the
            // card's rounded corners instead of following its shape.
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              onTap: anyLoading
                  ? null
                  : () => isActive ? _stopMix() : _playMix(mix),
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
                      icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
                      tooltip: isActive
                          ? (l10n?.stopMix ?? 'Stop')
                          : null,
                      onPressed: anyLoading
                          ? null
                          : () => isActive ? _stopMix() : _playMix(mix),
                    ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: l10n?.shareMix ?? 'Share',
                    // Not gated on anyLoading: this only reads the mix's
                    // static sound list, never live playback state, so
                    // there's nothing for it to race with.
                    onPressed: () => _shareMix(mix),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    // Gated like Play/Stop: opening Edit while _playMix's
                    // Future.wait is still in flight lets the sheet's
                    // "what's already playing" snapshot race against sounds
                    // that haven't started yet, so it can end up incomplete.
                    onPressed: anyLoading
                        ? null
                        : () => _openMixSheet(existingMix: mix),
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
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'importMix',
                onPressed: _importMix,
                tooltip: l10n?.importMix ?? 'Import mix',
                child: const Icon(Icons.file_download_outlined),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'newMix',
                onPressed: () => _openMixSheet(),
                tooltip: l10n?.newMix ?? 'New mix',
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
