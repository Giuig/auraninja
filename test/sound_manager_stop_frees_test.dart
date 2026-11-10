import 'package:auraninja/audio/j_a_sound_manager.dart';
import 'package:auraninja/audio/soloud_engine.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sound_controller_release_on_stop_test.dart' show FakeSoloudEngine;

void main() {
  test('(e) JustAudioSoundManager.stop(path) frees the SoLoud source',
      () async {
    final engine = FakeSoloudEngine();
    SoloudEngine.override = engine;
    addTearDown(() => SoloudEngine.override = null);

    final sound = NinjaSound(
      name: 'Birds',
      category: 'nature',
      icon: 'x',
      path: 'assets/sounds/birds.ogg',
    );
    final manager = JustAudioSoundManager();
    manager.registerSounds([sound]);

    await manager.play(sound.path);
    expect(manager.get(sound.path)!.isPlaying, isTrue);

    await manager.stop(sound.path);

    expect(engine.disposeCount, 1);
  });
}
