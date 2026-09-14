import 'package:flutter/material.dart';

/// Centralised volume slider used across the app.
///
/// All volume-related constants (min, max, track/thumb sizes) live here.
/// Use [compact] for tight layouts like sound cards.
class VolumeSlider extends StatelessWidget {
  static const double minVolume = 0.01;
  static const double maxVolume = 1.0;

  final double value;
  final ValueChanged<double> onChanged;

  /// When true, renders a slimmer track (height 3) and smaller thumb (r 8),
  /// suitable for the sound card's constrained layout.
  final bool compact;

  const VolumeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final slider = Slider(
      value: value.clamp(minVolume, maxVolume),
      min: minVolume,
      max: maxVolume,
      onChanged: onChanged,
    );

    if (!compact) return slider;

    return SizedBox(
      height: 20,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        child: slider,
      ),
    );
  }
}
