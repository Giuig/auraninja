import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:auraninja/data/sound_data.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/services/user_stations_service.dart';

class CreditsPage extends StatefulWidget {
  const CreditsPage({super.key});

  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  final Map<String, TapGestureRecognizer> _recognizers = {};
  List<NinjaSound> _userStations = [];

  @override
  void initState() {
    super.initState();
    _loadStations();
    UserStationsService.listenable.addListener(_loadStations);
  }

  Future<void> _loadStations() async {
    final stations = await UserStationsService.load();
    if (mounted) setState(() => _userStations = stations);
  }

  @override
  void dispose() {
    UserStationsService.listenable.removeListener(_loadStations);
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  List<TextSpan> _buildTextSpans(
      String text, TextStyle? style, TextStyle? linkStyle) {
    final RegExp urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final List<TextSpan> spans = [];

    text.splitMapJoin(
      urlRegExp,
      onMatch: (Match match) {
        final url = match.group(0)!;
        // Reuse existing recognizer — never create-and-dispose on every rebuild.
        final recognizer = _recognizers.putIfAbsent(url, () {
          final r = TapGestureRecognizer();
          r.onTap = () async {
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication);
          };
          return r;
        });
        spans.add(TextSpan(
          text: url,
          style: linkStyle ??
              style?.copyWith(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
          recognizer: recognizer,
        ));
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: style));
        return '';
      },
    );

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sounds = buildLocalizedSounds(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // Build categories map with only credited sounds
    final Map<String, List<NinjaSound>> categories = {};

    for (final sound in sounds) {
      if (sound.attribution != '@') {
        categories.putIfAbsent(sound.category, () => []).add(sound);
      }
    }

    // Merge user-added stations into their existing category bucket.
    for (final station in _userStations) {
      categories.putIfAbsent(station.category, () => []).add(station);
    }

    const double iconSize = 20;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pixabay attribution at top
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.otherSounds ?? 'Other Sounds',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${l10n?.additionalSoundsSourcedFrom ?? 'Additional sounds sourced from'} ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      ..._buildTextSpans(
                        'https://pixabay.com',
                        theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Category credits
          ...categories.entries.map((entry) {
            final categoryName = entry.key;
            final categorySounds = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...categorySounds.map((sound) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sound.icon is IconData
                              ? Icon(
                                  sound.icon as IconData,
                                  size: iconSize,
                                  color: colorScheme.onSurfaceVariant,
                                )
                              : Text(
                                  // Favicon URLs look bad as text — always use emoji.
                                  (sound.icon as String).startsWith('http')
                                      ? '📻'
                                      : sound.icon as String,
                                  style: TextStyle(
                                    fontSize: iconSize * 0.8,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: sound.attribution.isNotEmpty
                                        ? '${sound.name}: '
                                        : sound.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  ..._buildTextSpans(
                                    sound.attribution,
                                    theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                    theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
