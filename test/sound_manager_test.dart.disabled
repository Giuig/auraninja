/* // test/sound_manager_test.dart

import 'package:auraninja/data/sound_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:auraninja/utils/sound_manager.dart';
import 'mocks.mocks.dart'; // Make sure this path is correct for your generated mocks

// Helper function to stub common AudioPlayer methods
void _stubMockAudioPlayer(MockAudioPlayer player) {
  when(player.play(any)).thenAnswer((_) async {});
  when(player.setVolume(any)).thenAnswer((_) async {});
  when(player.setReleaseMode(any)).thenAnswer((_) async {});
  when(player.stop()).thenAnswer((_) async {});
  when(player.dispose()).thenAnswer((_) async {});
  when(player.setAudioContext(any)).thenAnswer((_) async {});
  when(player.getCurrentPosition()).thenAnswer((_) async => Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioPlayer mockAudioPlayer;
  late MockExclusivityManager mockExclusivityManager;
  late SoundManager soundManager;

  final testSounds = buildLocalizedSounds(null);

  final List<MockAudioPlayer> allCreatedMockPlayers = [];

  setUp(() {
    SoundManager.isTestMode = true;

    allCreatedMockPlayers.clear();

    mockAudioPlayer = MockAudioPlayer();
    mockExclusivityManager = MockExclusivityManager();

    _stubMockAudioPlayer(mockAudioPlayer);

    when(mockExclusivityManager.setRequestedSound(any)).thenReturn(null);
    when(mockExclusivityManager.getSoundToStop(any)).thenReturn(null);
    when(mockExclusivityManager.isCurrentPriority(any)).thenReturn(true);
    when(mockExclusivityManager.setPlayingSound(any)).thenReturn(null);
    when(mockExclusivityManager.clearPlayingSound(any)).thenReturn(null);
    when(mockExclusivityManager.clearAll()).thenReturn(null);

    SoundManager.debugAudioPlayerFactory = () => mockAudioPlayer;

    soundManager = SoundManager();

    soundManager.players.clear();
  });

  tearDown(() {
    SoundManager.isTestMode = false;
    SoundManager.debugAudioPlayerFactory = () => AudioPlayer();
    soundManager.stopAll();
  });

  group('SoundManager Play Function', () {
    test('play an ogg sound', () async {
      final soundToPlay =
          testSounds.firstWhere((s) => !s.path.startsWith('http'));

      await soundManager.play(soundToPlay);

      expect(soundManager.isPlaying(soundToPlay), true);
      expect(soundManager.players.containsKey(soundToPlay.path), true);
    });

    test('play an http sound', () async {
      final soundToPlay =
          testSounds.firstWhere((s) => s.path.startsWith('http'));

      await soundManager.play(soundToPlay);

      expect(soundManager.isPlaying(soundToPlay), true);
      expect(soundManager.players.containsKey(soundToPlay.path), true);
    });

    test('playing a second binaural stops the first', () async {
      final soundToPlay1 =
          testSounds.firstWhere((s) => s.path.contains('binaural'));
      final soundToPlay2 =
          testSounds.lastWhere((s) => s.path.contains('binaural'));

      final mockAudioPlayer2 = MockAudioPlayer();
      _stubMockAudioPlayer(mockAudioPlayer2);

      int callCount = 0;
      SoundManager.debugAudioPlayerFactory = () {
        callCount++;
        return callCount == 1 ? mockAudioPlayer : mockAudioPlayer2;
      };

      await soundManager.play(soundToPlay1);
      await soundManager.play(soundToPlay2);

      expect(soundManager.isPlaying(soundToPlay1), false);
      expect(soundManager.players.containsKey(soundToPlay1.path), false);
      expect(soundManager.isPlaying(soundToPlay2), true);
      expect(soundManager.players.containsKey(soundToPlay2.path), true);
      verifyNever(mockAudioPlayer2.dispose());
    });

    test('playing a second http stops the first', () async {
      final soundToPlay1 =
          testSounds.firstWhere((s) => s.path.startsWith('http'));
      final soundToPlay2 =
          testSounds.lastWhere((s) => s.path.startsWith('http'));

      final mockAudioPlayer2 = MockAudioPlayer();
      _stubMockAudioPlayer(mockAudioPlayer2);

      int callCount = 0;
      SoundManager.debugAudioPlayerFactory = () {
        callCount++;
        return callCount == 1 ? mockAudioPlayer : mockAudioPlayer2;
      };

      await soundManager.play(soundToPlay1);
      await soundManager.play(soundToPlay2);

      expect(soundManager.isPlaying(soundToPlay1), false);
      expect(soundManager.players.containsKey(soundToPlay1.path), false);
      expect(soundManager.isPlaying(soundToPlay2), true);
      expect(soundManager.players.containsKey(soundToPlay2.path), true);
      verifyNever(mockAudioPlayer2.dispose());
    });

    test('only last stream remains active after multiple rapid play calls',
        () async {
      final streamSounds =
          testSounds.where((s) => s.path.startsWith('http')).take(3).toList();

      final List<MockAudioPlayer> allSequentialMocks = [];

      SoundManager.debugAudioPlayerFactory = () {
        final MockAudioPlayer newMockPlayer = MockAudioPlayer();
        _stubMockAudioPlayer(newMockPlayer);
        allSequentialMocks.add(newMockPlayer);
        return newMockPlayer;
      };

      for (final sound in streamSounds) {
        await soundManager.play(sound);
      }

      final lastSound = streamSounds.last;

      expect(soundManager.isPlaying(lastSound), true);
      expect(soundManager.players.containsKey(lastSound.path), true);

      for (int i = 0; i < streamSounds.length - 1; i++) {
        final sound = streamSounds[i];

        expect(soundManager.players.containsKey(sound.path), false);
        expect(soundManager.isPlaying(sound), false);
      }

      final lastSoundPlayer = allSequentialMocks.last;
      verifyNever(lastSoundPlayer.dispose());
      verifyNever(lastSoundPlayer.stop());
    });

    test(
        'only last stream plays after repeated play calls on same/different streams (complex sequence)',
        () async {
      final streamSounds =
          testSounds.where((s) => s.path.startsWith('http')).take(2).toList();

      final playSequence = [
        streamSounds[0],
        streamSounds[0],
        streamSounds[1],
        streamSounds[0],
        streamSounds[1],
      ];

      final List<MockAudioPlayer> createdPlayerInstances = [];

      SoundManager.debugAudioPlayerFactory = () {
        final mockPlayer = MockAudioPlayer();
        _stubMockAudioPlayer(mockPlayer);
        createdPlayerInstances.add(mockPlayer);
        return mockPlayer;
      };

      for (final sound in playSequence) {
        await soundManager.play(sound);
      }

      final lastSound = playSequence.last;

      expect(soundManager.isPlaying(lastSound), true);
      expect(soundManager.players.containsKey(lastSound.path), true);

      for (final sound in streamSounds) {
        if (sound.path != lastSound.path) {
          expect(soundManager.isPlaying(sound), false);
          expect(soundManager.players.containsKey(sound.path), false);
        }
      }

      final lastActiveMock = createdPlayerInstances.last;
      verifyNever(lastActiveMock.dispose());
      verifyNever(lastActiveMock.stop());
    });
  });

  group('SoundManager Pause and Resume All Functions', () {
    test('pauseAll pauses all currently playing ogg sounds', () async {
      final soundsToPlay = testSounds.take(3).toList();

      for (final sound in soundsToPlay) {
        await soundManager.play(sound);
      }

      for (final sound in soundsToPlay) {
        expect(soundManager.isPlaying(sound), true);
      }

      await soundManager.pauseAll();

      for (final sound in soundsToPlay) {
        expect(soundManager.isPlaying(sound), false);
        expect(soundManager.isPaused(sound), true);
      }
      expect(soundManager.isGloballyPausedNotifier.value, isTrue);
    });

    test(
        'pauseAll stops the currently http playing sound and mark it as paused',
        () async {
      final soundToPause =
          testSounds.firstWhere((s) => s.path.startsWith('http'));

      await soundManager.play(soundToPause);

      expect(soundManager.isPlaying(soundToPause), true);

      await soundManager.pauseAll();

      expect(soundManager.isPlaying(soundToPause), false);
      expect(soundManager.isPaused(soundToPause), true);

      expect(soundManager.isGloballyPausedNotifier.value, isTrue);
    });

    test(
        'resumeAll resumes all previously paused sounds and marks _isGloballyPaused as false',
        () async {
      final sounds = testSounds.take(3).toList();

      for (final sound in sounds) {
        await soundManager.play(sound);
      }

      await soundManager.pauseAll();
      expect(soundManager.isGloballyPausedNotifier.value, isTrue);
      for (final sound in sounds) {
        expect(soundManager.isPaused(sound), isTrue);
        expect(soundManager.isPlaying(sound), isFalse);
      }

      await soundManager.resumeAll();

      expect(soundManager.isGloballyPausedNotifier.value, isFalse);
      for (final sound in sounds) {
        expect(soundManager.isPlaying(sound), true);
        expect(soundManager.isPaused(sound), false);
      }
    });

    test('resumeAll restarts http streams with fresh cache-busted URL',
        () async {
      final httpSound = testSounds.firstWhere((s) => s.path.startsWith('http'));

      await soundManager.play(httpSound);
      await soundManager.pauseAll();

      reset(mockAudioPlayer); // clear old call history

      when(mockAudioPlayer.play(any)).thenAnswer((_) async {
        final source = _.positionalArguments.first as UrlSource;
        expect(source.url, contains(httpSound.path));
        expect(source.url, contains('t='));
      });

      when(mockAudioPlayer.getCurrentPosition())
          .thenAnswer((_) async => Duration.zero);

      await soundManager.resumeAll();

      verify(mockAudioPlayer.stop()).called(1);
      verify(mockAudioPlayer.play(any)).called(1);
    });

    test(
        'playing another sound will resume all paused sounds when globally paused',
        () async {
      final nonStreamSounds =
          testSounds.where((s) => !s.path.startsWith('http')).take(5).toList();

      for (final sound in nonStreamSounds) {
        await soundManager.play(sound);
      }

      await soundManager.pauseAll();
      expect(soundManager.isGloballyPausedNotifier.value, isTrue);
      for (final sound in nonStreamSounds) {
        expect(soundManager.isPaused(sound), true);
      }

      await soundManager.stop(nonStreamSounds.last);
      await soundManager.play(nonStreamSounds.last);

      expect(soundManager.isGloballyPausedNotifier.value, isFalse);

      for (final sound in nonStreamSounds) {
        expect(soundManager.isPlaying(sound), true);
        expect(soundManager.isPaused(sound), false);
      }
    });
  });

  group('SoundManager Individual Pause/Resume Functions', () {
    test('pause an individual ogg sound', () async {
      final soundToPause = testSounds.first;

      await soundManager.play(soundToPause);
      expect(soundManager.isPlaying(soundToPause), isTrue);
      expect(soundManager.isPaused(soundToPause), isFalse);

      await soundManager.pause(soundToPause);
      expect(soundManager.isPlaying(soundToPause), isFalse);
      expect(soundManager.isPaused(soundToPause), isTrue);
      expect(soundManager.isGloballyPausedNotifier.value, isFalse);
    });

    test('resume an individual ogg sound', () async {
      final soundToResume = testSounds.first;

      await soundManager.play(soundToResume);
      await soundManager.pause(soundToResume);
      expect(soundManager.isPlaying(soundToResume), isFalse);
      expect(soundManager.isPaused(soundToResume), isTrue);

      await soundManager.resume(soundToResume);
      expect(soundManager.isPlaying(soundToResume), true);
      expect(soundManager.isPaused(soundToResume), false);
    });

    test('pause an individual http sound', () async {
      final soundToPause =
          testSounds.firstWhere((s) => s.path.startsWith('http'));

      await soundManager.play(soundToPause);
      expect(soundManager.isPlaying(soundToPause), isTrue);
      expect(soundManager.isPaused(soundToPause), isFalse);

      await soundManager.pause(soundToPause);
      expect(soundManager.isPlaying(soundToPause), isFalse);
      expect(soundManager.isPaused(soundToPause), isTrue);
      expect(soundManager.isGloballyPausedNotifier.value, isFalse);
    });

    test('resume an individual http sound', () async {
      final soundToResume =
          testSounds.firstWhere((s) => s.path.startsWith('http'));

      await soundManager.play(soundToResume);
      await soundManager.pause(soundToResume);
      expect(soundManager.isPlaying(soundToResume), isFalse);
      expect(soundManager.isPaused(soundToResume), isTrue);

      await soundManager.resume(soundToResume);
      expect(soundManager.isPlaying(soundToResume), true);
      expect(soundManager.isPaused(soundToResume), false);
    });

    test('resume an individual http stream restarts with new URL', () async {
      final httpSound = testSounds.firstWhere((s) => s.path.startsWith('http'));

      await soundManager.play(httpSound);
      await soundManager.pause(httpSound);

      reset(mockAudioPlayer);

      when(mockAudioPlayer.play(any)).thenAnswer((_) async {
        final source = _.positionalArguments.first as UrlSource;
        expect(source.url, contains(httpSound.path));
        expect(source.url, contains('t='));
      });

      when(mockAudioPlayer.getCurrentPosition())
          .thenAnswer((_) async => Duration.zero);

      await soundManager.resume(httpSound);

      verify(mockAudioPlayer.stop()).called(1);
      verify(mockAudioPlayer.play(any)).called(1);
    });

    test('stopping an individual sound clears its paused status', () async {
      final sound = testSounds.first;

      await soundManager.play(sound);
      await soundManager.pause(sound);
      expect(soundManager.isPaused(sound), isTrue);

      await soundManager.stop(sound);
      expect(soundManager.isPlaying(sound), false);
      expect(soundManager.isPaused(sound), false);
      expect(soundManager.players.containsKey(sound.path), false);
    });
  });

  group('SoundManager Stop Functions', () {
    test('stop a specific sound', () async {
      final sound1 = testSounds.first;

      soundManager = SoundManager();

      await soundManager.play(sound1);
      expect(soundManager.isPlaying(sound1), true);
      expect(soundManager.players.containsKey(sound1.path), true);

      await soundManager.stop(sound1);

      expect(soundManager.isPlaying(sound1), false);
      expect(soundManager.players.containsKey(sound1.path), false);
    });

    test('stopAll stops and disposes all playing sounds', () async {
      final soundsToPlay = testSounds.take(3).toList();

      final List<MockAudioPlayer> players = [];
      SoundManager.debugAudioPlayerFactory = () {
        final mock = MockAudioPlayer();
        _stubMockAudioPlayer(mock);
        players.add(mock);
        return mock;
      };

      for (final sound in soundsToPlay) {
        await soundManager.play(sound);
      }

      for (final sound in soundsToPlay) {
        expect(soundManager.isPlaying(sound), true);
      }
      expect(soundManager.players.length, soundsToPlay.length);

      await soundManager.stopAll();

      for (final sound in soundsToPlay) {
        expect(soundManager.isPlaying(sound), false);
        expect(soundManager.players.containsKey(sound.path), false);
      }
      expect(soundManager.players.isEmpty, true);

      expect(soundManager.isGloballyPausedNotifier.value, isFalse);
    });
  });
}
 */
