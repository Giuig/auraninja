/// Centralised category identifier constants.
///
/// Every file that assigns or compares NinjaSound.category must import this.
/// Changing a value here is the only intervention needed.
abstract final class SoundCategory {
  static const weather = '@weather';
  static const nature = '@nature';
  static const objects = '@objects';
  static const places = '@places';
  static const binaural = '@binaural';
  static const noise = '@noise';
  static const internetRadio = '@internetRadio';

  /// Categories where only one sound may be active at a time.
  static const exclusive = {binaural, noise, internetRadio};
}
