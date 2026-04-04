import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/model/ninja_sound.dart';

Widget _buildSoundIcon(dynamic icon, double size, Color color) {
  if (icon is IconData) {
    return Icon(icon, size: size, color: color);
  }
  final str = icon as String? ?? '📻';
  if (str.startsWith('http')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: str,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) =>
            Text('📻', style: TextStyle(fontSize: size * 0.7)),
      ),
    );
  }
  return Text(str, style: TextStyle(fontSize: size * 0.7, color: color));
}

class SoundCard extends StatelessWidget {
  final Map<String, NinjaSound> localizedSoundMap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const SoundCard({
    super.key,
    required this.localizedSoundMap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SoundController>(context);
    // listen: false — actions only; logo changes are tracked via context.select.
    final handler = Provider.of<WrapperAudioHandler>(context, listen: false);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const double iconSize = 40;
    const double lineHeight = 1.2;
    final textStyle = theme.textTheme.bodySmall;

    final localizedSound = localizedSoundMap[controller.sound.path];
    final localizedName = localizedSound?.name ?? controller.sound.name;

    final bool isActive = controller.status == PlaybackStatus.playing ||
        controller.status == PlaybackStatus.loading ||
        controller.status == PlaybackStatus.paused;

    Color cardColor;
    Color borderColor;
    Color iconAndTextColor;

    switch (controller.status) {
      case PlaybackStatus.error:
        cardColor = colorScheme.errorContainer;
        borderColor = colorScheme.error;
        iconAndTextColor = colorScheme.onErrorContainer;
        break;
      case PlaybackStatus.loading:
      case PlaybackStatus.playing:
        cardColor = colorScheme.secondaryContainer;
        borderColor = colorScheme.primary;
        iconAndTextColor = colorScheme.primary;
        break;
      case PlaybackStatus.paused:
        cardColor = colorScheme.onSecondary;
        borderColor = colorScheme.outlineVariant;
        iconAndTextColor = colorScheme.secondary;
        break;
      default:
        cardColor = colorScheme.surface;
        borderColor = colorScheme.outlineVariant;
        iconAndTextColor = colorScheme.onSurfaceVariant;
    }

    // For radio streams, prefer the favicon from radio-browser.info.
    // context.select rebuilds only this card (not all cards) when its logo
    // arrives; other handler events (play/pause on other sounds) are ignored.
    dynamic displayIcon = controller.sound.icon;
    if (controller.sound.isStream) {
      if (controller.status == PlaybackStatus.playing ||
          controller.status == PlaybackStatus.loading) {
        final logoUrl = context.select<WrapperAudioHandler, String?>(
          (h) => h.getCachedLogoUrl(controller.sound.name),
        );
        displayIcon = (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : '📻';
      } else {
        // Not playing — show cached logo if already fetched, otherwise emoji.
        // peekCachedLogoUrl never triggers a network request.
        final cached = context.select<WrapperAudioHandler, String?>(
          (h) => h.peekCachedLogoUrl(controller.sound.name),
        );
        if (cached != null && cached.isNotEmpty) {
          displayIcon = cached;
        } else {
          displayIcon = '📻';
        }
      }
    }

    return GestureDetector(
      onTap: () {
        if (controller.status == PlaybackStatus.playing ||
            controller.status == PlaybackStatus.loading) {
          handler.ninjaStop(controller.sound.path);
        } else {
          handler.ninjaPlay(controller.sound.path);
        }
      },
      child: Stack(
        children: [
          Card(
            elevation: controller.status == PlaybackStatus.loading ||
                    controller.status == PlaybackStatus.playing
                ? 6
                : 1,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: borderColor,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: iconSize,
                    width: iconSize,
                    child: controller.status == PlaybackStatus.loading
                        ? const CircularProgressIndicator(strokeWidth: 2.5)
                        : _buildSoundIcon(
                            displayIcon, iconSize, iconAndTextColor),
                  ),
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final scaledFontSize = MediaQuery.textScalerOf(context)
                          .scale(textStyle?.fontSize ?? 12.0);
                      return ClipRect(
                        child: SizedBox(
                          height: scaledFontSize * lineHeight * 2,
                          child: Center(
                            child: Text(
                              localizedName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textStyle?.copyWith(
                                color: iconAndTextColor,
                                height: lineHeight,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 4),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                            ),
                            child: Slider(
                              value: controller.volume,
                              min: 0.1,
                              max: 1.0,
                              onChanged: (newVolume) {
                                handler.setVolume(
                                    controller.sound.path, newVolume);
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: Opacity(
                            opacity: (controller.volume - 0.5).abs() > 0.03
                                ? 1.0
                                : 0.0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  handler.setVolume(controller.sound.path, 0.5),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onFavoriteToggle != null)
            Positioned(
              top: 4,
              left: 4,
              child: GestureDetector(
                onTap: onFavoriteToggle,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isFavorite
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFavorite
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 14,
                    color: isFavorite
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
