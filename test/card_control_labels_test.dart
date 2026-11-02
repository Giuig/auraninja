import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
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
/// A stream player that reports "playing" on demand, so a radio card can
/// show its playing-only controls without any real audio.
class FakePlayingPlayer implements just_audio.AudioPlayer {
  final states = StreamController<just_audio.PlayerState>.broadcast();
  double _volume = 1.0;

  @override
  Stream<just_audio.PlayerState> get playerStateStream => states.stream;
  @override
  Stream<just_audio.IcyMetadata?> get icyMetadataStream => const Stream.empty();
  @override
  double get volume => _volume;
  @override
  Future<void> setVolume(double v) async => _volume = v;
  @override
  Future<void> dispose() async => states.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  group('volume reset on a playing card', () {
    Future<SoundController> playingRadio(
        WidgetTester tester, double volume) async {
      final fake = FakePlayingPlayer();
      final controller = SoundController(
        NinjaSound(
          name: 'Test FM',
          category: '@internetRadio',
          icon: '📻',
          path: 'https://example.com/stream',
        ),
        createPlayer: () => fake,
        interruptionEvents: const Stream.empty(),
      );
      controller.player; // create it, as load() does
      controller.setVolume(volume);
      await tester.pumpWidget(app(
          SizedBox(
            width: 200,
            child: ChangeNotifierProvider<SoundController>.value(
              value: controller,
              child: const SoundCard(localizedSoundMap: {}),
            ),
          ),
          WrapperAudioHandler()));
      fake.states
          .add(just_audio.PlayerState(true, just_audio.ProcessingState.ready));
      await tester.pump();
      return controller;
    }

    testWidgets('is labelled while it is visible', (tester) async {
      await playingRadio(tester, 0.2);

      expect(find.byTooltip('Reset volume'), findsOneWidget);
    });

    testWidgets('is hidden from screen readers at the default volume',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await playingRadio(tester, 0.5);

      expect(find.byTooltip('Reset volume'), findsNothing);
      expect(find.bySemanticsLabel('Reset volume'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsOneWidget); // still laid out
      semantics.dispose();
    });
  });

  testWidgets("the search field's clear button is labelled", (tester) async {
    await tester.pumpWidget(app(const SoundsPage(), WrapperAudioHandler()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'rain');
    await tester.pump();

    expect(find.byTooltip('Clear search'), findsOneWidget);
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
