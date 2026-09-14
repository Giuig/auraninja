import 'package:flutter_test/flutter_test.dart';
import 'package:auraninja/audio/fade_curve.dart';

void main() {
  group('fadeOutEase', () {
    test('starts at 0.0 and ends at 1.0', () {
      expect(fadeOutEase(0.0), 0.0);
      expect(fadeOutEase(1.0), 1.0);
    });

    test('is monotonically non-decreasing across the fade', () {
      var previous = fadeOutEase(0.0);
      for (var i = 1; i <= 20; i++) {
        final t = i / 20;
        final value = fadeOutEase(t);
        expect(value, greaterThanOrEqualTo(previous),
            reason: 'value should never decrease as t increases');
        previous = value;
      }
    });

    test('eases out: covers more ground early than late', () {
      // "Gentle" means the volume should already be well down by the
      // midpoint, not still hovering near full volume — a linear ramp
      // would read as an abrupt cut right at the end instead.
      final firstHalfDelta = fadeOutEase(0.5) - fadeOutEase(0.0);
      final secondHalfDelta = fadeOutEase(1.0) - fadeOutEase(0.5);
      expect(firstHalfDelta, greaterThan(secondHalfDelta));
    });

    test('clamps values outside [0.0, 1.0]', () {
      expect(fadeOutEase(-0.5), 0.0);
      expect(fadeOutEase(1.5), 1.0);
    });

    test('stays within [0.0, 1.0] for values inside the range', () {
      for (var i = 0; i <= 10; i++) {
        final value = fadeOutEase(i / 10);
        expect(value, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
