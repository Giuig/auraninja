import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/model/ninja_sound.dart';

/// Stands in for just_audio's AudioPlayer, including its built-in audio-focus
/// handling (`handleInterruptions: true`, the default). The duck branch below
/// is copied from just_audio 0.10.5 (`_setupAudioSession`): a duck that begins
/// only halves the volume for `AndroidAudioUsage.game`, but a duck that ends
/// doubles it unconditionally. auraninja is not a game, so every duck end
/// doubles the radio's volume (issue #12).
///
/// The real player subscribes inside `AudioSession.instance.then(...)`. For
/// the first player after launch that waits on a platform round trip, while
/// the controller's own `AudioSession.instance` call returns at once, so the
/// controller hears each event FIRST. [subscribeLate] reproduces that order;
/// otherwise the fake hears events first, as every later player does.
class FakeDuckingPlayer implements just_audio.AudioPlayer {
  FakeDuckingPlayer(Stream<AudioInterruptionEvent> events,
      {bool subscribeLate = false}) {
    void subscribe() => _sub = events.listen((event) {
          if (event.type != AudioInterruptionType.duck) return;
          if (!event.begin) setVolume(min(1.0, volume * 2));
        });
    subscribeLate ? Future(subscribe) : subscribe();
  }

  StreamSubscription<AudioInterruptionEvent>? _sub;
  double _volume = 1.0;

  @override
  double get volume => _volume;

  @override
  Future<void> setVolume(double volume) async => _volume = volume;

  @override
  Stream<just_audio.PlayerState> get playerStateStream => const Stream.empty();

  @override
  Future<void> dispose() async => _sub?.cancel();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  NinjaSound radio() => NinjaSound(
        name: 'Test Radio',
        category: 'stream',
        icon: '📻',
        path: 'https://example.com/stream.mp3',
      );

  late StreamController<AudioInterruptionEvent> events;
  late FakeDuckingPlayer fake;
  late SoundController controller;

  setUp(() {
    events = StreamController<AudioInterruptionEvent>.broadcast(sync: true);
    controller = SoundController(
      radio(),
      createPlayer: () => fake = FakeDuckingPlayer(events.stream),
      interruptionEvents: events.stream,
    );
    controller.player; // create the player, as load() does
  });

  tearDown(() async {
    controller.dispose();
    await events.close();
  });

  Future<void> duck() async {
    events.add(AudioInterruptionEvent(true, AudioInterruptionType.duck));
    events.add(AudioInterruptionEvent(false, AudioInterruptionType.duck));
    await pumpEventQueue();
  }

  group('issue #12: another app ducking the radio', () {
    test('a duck ending leaves the radio at the slider volume', () async {
      controller.setVolume(0.3);

      await duck();

      expect(fake.volume, 0.3);
    });

    test('repeated ducks do not ratchet the volume up to max', () async {
      controller.setVolume(0.2);

      for (var i = 0; i < 5; i++) {
        await duck();
      }

      expect(fake.volume, 0.2);
    });

    testWidgets('a radio faded out by the sleep timer stays silent',
        (tester) async {
      controller.setVolume(0.4);
      controller.fadeTo(0.0, Duration.zero); // fadeTo reads the wall clock
      await tester.pump(const Duration(milliseconds: 100));
      expect(fake.volume, 0.0);

      await tester.runAsync(duck);

      expect(fake.volume, 0.0);
    });

    test('the first player after launch, which hears ducks after us, too',
        () async {
      final late = SoundController(
        radio(),
        createPlayer: () =>
            fake = FakeDuckingPlayer(events.stream, subscribeLate: true),
        interruptionEvents: events.stream,
      );
      late.player;
      await pumpEventQueue(); // the player's own subscription lands now
      late.setVolume(0.3);

      await duck();

      expect(fake.volume, 0.3);
      late.dispose();
    });

    test('a pause interruption does not touch the volume', () async {
      controller.setVolume(0.3);

      events.add(AudioInterruptionEvent(true, AudioInterruptionType.pause));
      events.add(AudioInterruptionEvent(false, AudioInterruptionType.pause));
      await pumpEventQueue();

      expect(fake.volume, 0.3);
    });
  });
}
