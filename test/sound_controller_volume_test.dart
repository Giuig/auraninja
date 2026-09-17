import 'package:flutter_test/flutter_test.dart';
import 'package:auraninja/audio/sound_controller.dart';
import 'package:auraninja/model/ninja_sound.dart';

void main() {
  // A stream sound short-circuits every engine backend inside setVolume():
  // _useSoloud and _useWebSeamless are both false because isStream == true,
  // and hasPlayer stays false because this test never calls the lazy
  // `player` getter or load()/play(). That isolates the assertions below to
  // exactly the notifyListeners() gating this test exists to cover, with no
  // SoLoud/just_audio/web-engine call ever attempted.
  NinjaSound streamSound() => NinjaSound(
        name: 'Test Stream',
        category: 'stream',
        icon: '📻',
        path: 'https://example.com/stream.mp3',
      );

  group('SoundController.setVolume notification gating', () {
    test('notifies once on an actual value change', () {
      final controller = SoundController(streamSound());
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setVolume(0.25);

      expect(notifications, 1);
      expect(controller.volume, 0.25);
    });

    test('does not notify on a repeat of the same value', () {
      final controller = SoundController(streamSound());
      controller.setVolume(0.25); // establish _volume before attaching listener

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setVolume(0.25); // same value again — engine dispatch still
      // happens (see setVolume's comment), but no listener should fire.

      expect(notifications, 0);
      expect(controller.volume, 0.25);
    });
  });
}
