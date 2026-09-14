/// Eases a linear progress value [t] (0.0 at fade start, 1.0 at fade end)
/// into an ease-out curve for volume fades.
///
/// Volume drops faster at the start and tapers off near the end, which reads
/// as "gentle" — a linear ramp feels like it cuts off abruptly right before
/// silence because human loudness perception is roughly logarithmic, not
/// linear.
///
/// [t] is clamped to [0.0, 1.0]; the result is always in that same range.
double fadeOutEase(double t) {
  final clamped = t.clamp(0.0, 1.0);
  final inverse = 1.0 - clamped;
  return 1.0 - inverse * inverse;
}
