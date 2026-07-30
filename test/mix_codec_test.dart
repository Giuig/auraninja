import 'package:auraninja/model/mix.dart';
import 'package:auraninja/utils/mix_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MixCodec', () {
    final mix = Mix(
      id: 'abc',
      name: 'Rainy focus',
      icon: '🌧️',
      sounds: [
        MixSound(path: 'assets/sounds/rain/light-rain.ogg', volume: 0.4),
        MixSound(path: 'https://example.com/stream', volume: 0.8),
      ],
    );

    test('encode → tryDecode round-trips name, icon, sounds and volumes', () {
      final code = MixCodec.encode(mix);
      final decoded = MixCodec.tryDecode(code);

      expect(decoded, isNotNull);
      expect(decoded!.name, mix.name);
      expect(decoded.icon, mix.icon);
      expect(decoded.sounds.length, 2);
      expect(decoded.sounds[0].path, mix.sounds[0].path);
      expect(decoded.sounds[0].volume, closeTo(0.4, 1e-9));
      expect(decoded.sounds[1].path, mix.sounds[1].path);
      expect(decoded.sounds[1].isStream, isTrue);
    });

    test('assigns a fresh id (never reuses the sender id)', () {
      final decoded = MixCodec.tryDecode(MixCodec.encode(mix));
      expect(decoded!.id, isNot('abc'));
    });

    test('extracts the code from surrounding pasted text', () {
      final code = MixCodec.encode(mix);
      final pasted = 'Hey, try my mix 🎧\n\n$code\n\nOpen it in Auraninja!';
      expect(MixCodec.tryDecode(pasted)?.name, mix.name);
    });

    test('returns null for junk / no code', () {
      expect(MixCodec.tryDecode('just some text'), isNull);
      expect(MixCodec.tryDecode(''), isNull);
      expect(MixCodec.tryDecode('AN1!!!not-valid-base64!!!'), isNull);
    });
  });
}
