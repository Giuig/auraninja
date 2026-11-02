import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/pages/sounds_page.dart';
import 'package:auraninja/widgets/sound_card.dart';

/// Screen readers announce an icon-only control by its tooltip. The heart on
/// every sound card and the remove-station "×" had none, so TalkBack could not
/// reach them at all (found on the S24U, 2026-11-02).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app(Widget home, WrapperAudioHandler handler) =>
      ChangeNotifierProvider<WrapperAudioHandler>.value(
        value: handler,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home),
        ),
      );

  final rain = NinjaSound(
    name: 'Light Rain',
    category: '@weather',
    icon: '🌧️',
    path: 'sounds/weather/light-rain.ogg',
  );

  Widget card(bool isFavorite, VoidCallback onToggle) => SizedBox(
        width: 200,
        child: ChangeNotifierProvider<SoundController>(
          create: (_) => SoundController(rain),
          child: SoundCard(
            localizedSoundMap: const {},
            isFavorite: isFavorite,
            onFavoriteToggle: onToggle,
          ),
        ),
      );

  testWidgets('the heart is labelled "Add to favorites" and still toggles',
      (tester) async {
    var toggled = 0;
    await tester
        .pumpWidget(app(card(false, () => toggled++), WrapperAudioHandler()));

    await tester.tap(find.byTooltip('Add to favorites'));

    expect(toggled, 1);
  });

  testWidgets('a favourited heart is labelled "Remove from favorites"',
      (tester) async {
    await tester.pumpWidget(app(card(true, () {}), WrapperAudioHandler()));

    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
  });

  testWidgets('a user station\'s remove button is labelled', (tester) async {
    SharedPreferences.setMockInitialValues({
      'user_radio_stations': jsonEncode([
        {
          'name': 'Test FM',
          'category': '@internetRadio',
          'icon': '',
          'path': 'https://example.com/stream',
          'isUserAdded': true,
        }
      ]),
    });
    await tester.pumpWidget(app(const SoundsPage(), WrapperAudioHandler()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Test FM'), findsOneWidget);
    expect(find.byTooltip('Remove station'), findsOneWidget);
  });
}
