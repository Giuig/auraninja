import 'package:auraninja/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:auraninja/model/ninja_sound.dart';

List<NinjaSound> buildLocalizedSounds(BuildContext? context) {
  final bool hasContext = context != null;
  final AppLocalizations? projLocalization =
      hasContext ? AppLocalizations.of(context) : null;

  final sounds = <NinjaSound>[
    // Weather
    NinjaSound(
      name: hasContext ? projLocalization!.lightRain : 'Light Rain',
      category: '@weather',
      icon: '🌦️',
      path: 'assets/sounds/rain/light-rain.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.heavyRain : 'Heavy Rain',
      category: '@weather',
      icon: '🌧️',
      path: 'assets/sounds/rain/heavy-rain.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.rainOnWindow : 'Rain on Window',
      category: '@weather',
      icon: '🪟',
      path: 'assets/sounds/rain/rain-on-window.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.rainOnCarRoof : 'Rain on Car Roof',
      category: '@weather',
      icon: '🚗',
      path: 'assets/sounds/rain/rain-on-car-roof.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.rainOnUmbrella : 'Rain on Umbrella',
      category: '@weather',
      icon: '☂️',
      path: 'assets/sounds/rain/rain-on-umbrella.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.thunder : 'Thunder',
      category: '@weather',
      icon: '⚡',
      path: 'assets/sounds/nature/thunder.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.wind : 'Wind',
      category: '@weather',
      icon: '🌬️',
      path: 'assets/sounds/nature/wind.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.howlingWind : 'Howling Wind',
      category: '@weather',
      icon: '💨',
      path: 'assets/sounds/nature/howling-wind.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.windInTrees : 'Wind in Trees',
      category: '@weather',
      icon: '🌳',
      path: 'assets/sounds/nature/wind-in-trees.ogg',
    ),

    // Nature - Water
    NinjaSound(
      name: hasContext ? projLocalization!.waves : 'Waves',
      category: '@nature',
      icon: '🌊',
      path: 'assets/sounds/nature/waves.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.river : 'River',
      category: '@nature',
      icon: '🏞️',
      path: 'assets/sounds/nature/river.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.waterfall : 'Waterfall',
      category: '@nature',
      icon: '💧',
      path: 'assets/sounds/nature/waterfall.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.droplets : 'Droplets',
      category: '@nature',
      icon: '💦',
      path: 'assets/sounds/nature/droplets.ogg',
    ),

    // Nature - Forest & Ambient
    NinjaSound(
      name: hasContext ? projLocalization!.fire : 'Fire',
      category: '@nature',
      icon: '🔥',
      path: 'assets/sounds/nature/fire.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.walkInSnow : 'Walk in Snow',
      category: '@nature',
      icon: '❄️',
      path: 'assets/sounds/nature/walk-in-snow.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.walkOnLeaves : 'Walk on Leaves',
      category: '@nature',
      icon: '🍂',
      path: 'assets/sounds/nature/walk-on-leaves.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.jungle : 'Jungle',
      category: '@nature',
      icon: '🌴',
      path: 'assets/sounds/nature/jungle.ogg',
    ),

    // Nature - Animals
    NinjaSound(
      name: hasContext ? projLocalization!.birds : 'Birds',
      category: '@nature',
      icon: '🐦',
      path: 'assets/sounds/nature/birds.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.crickets : 'Crickets',
      category: '@nature',
      icon: '🦗',
      path: 'assets/sounds/nature/crickets.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.frog : 'Frog',
      category: '@nature',
      icon: '🐸',
      path: 'assets/sounds/nature/frog.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.owl : 'Owl',
      category: '@nature',
      icon: '🦉',
      path: 'assets/sounds/nature/owl.ogg',
      volumeMultiplier: 1.5,
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.whale : 'Whale',
      category: '@nature',
      icon: '🐋',
      path: 'assets/sounds/nature/whale.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.cat : 'Cat',
      category: '@nature',
      icon: '🐱',
      path: 'assets/sounds/nature/cat.ogg',
    ),

    // Objects
    NinjaSound(
      name: hasContext ? projLocalization!.keyboard : 'Keyboard',
      category: '@objects',
      icon: '⌨️',
      path: 'assets/sounds/things/keyboard.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.typewriter : 'Typewriter',
      category: '@objects',
      icon: '📝',
      path: 'assets/sounds/things/typewriter.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.clock : 'Clock',
      category: '@objects',
      icon: '🕐',
      path: 'assets/sounds/things/clock.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.windChimes : 'Wind Chimes',
      category: '@objects',
      icon: '🎐',
      path: 'assets/sounds/things/wind-chimes.ogg',
      volumeMultiplier: 1.3,
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.singingBowl : 'Singing Bowl',
      category: '@objects',
      icon: '🥣',
      path: 'assets/sounds/things/singing-bowl.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.ceilingFan : 'Ceiling Fan',
      category: '@objects',
      icon: '🌀',
      path: 'assets/sounds/things/ceiling-fan.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.boilingWater : 'Boiling Water',
      category: '@objects',
      icon: '🫖',
      path: 'assets/sounds/things/boiling-water.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.bubbles : 'Bubbles',
      category: '@objects',
      icon: '🫧',
      path: 'assets/sounds/things/bubbles.ogg',
    ),

    // Places
    NinjaSound(
      name: hasContext ? projLocalization!.cafe : 'Cafe',
      category: '@places',
      icon: '☕',
      path: 'assets/sounds/places/cafe.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.library2 : 'Library',
      category: '@places',
      icon: '📚',
      path: 'assets/sounds/places/library.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.office : 'Office',
      category: '@places',
      icon: '🏢',
      path: 'assets/sounds/places/office.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.train : 'Train',
      category: '@places',
      icon: '🚂',
      path: 'assets/sounds/places/train.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.airplane : 'Airplane',
      category: '@places',
      icon: '✈️',
      path: 'assets/sounds/places/plane.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.underwater : 'Underwater',
      category: '@places',
      icon: '🐡',
      path: 'assets/sounds/places/underwater.ogg',
    ),

    // Binaural
    NinjaSound(
      name: hasContext ? projLocalization!.laserFocus : 'Laser Focus',
      category: '@binaural',
      icon: '🎯',
      path: 'assets/sounds/binaural/focus-10hz.ogg',
      volumeMultiplier: 2.5,
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.creativeFlow : 'Creative Flow',
      category: '@binaural',
      icon: '🎨',
      path: 'assets/sounds/binaural/alpha-8hz.ogg',
      volumeMultiplier: 2.5,
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.zenCalm : 'Zen Calm',
      category: '@binaural',
      icon: '🧘',
      path: 'assets/sounds/binaural/theta-5hz.ogg',
      volumeMultiplier: 2.5,
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.deepCalm : 'Deep Calm',
      category: '@binaural',
      icon: '🌙',
      path: 'assets/sounds/binaural/theta-4hz.ogg',
      volumeMultiplier: 2.5,
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.deepSleep : 'Deep Sleep',
      category: '@binaural',
      icon: '😴',
      path: 'assets/sounds/binaural/delta-2hz.ogg',
    ),
    NinjaSound(
      name:
          hasContext ? projLocalization!.theDeepestSleep : 'The Deepest Sleep',
      category: '@binaural',
      icon: '💤',
      path: 'assets/sounds/binaural/delta-1hz.ogg',
    ),

    // Noise
    NinjaSound(
      name: hasContext ? projLocalization!.brown : 'Brown Noise',
      category: '@noise',
      icon: '🟤',
      path: 'assets/sounds/noise/brown-noise.ogg',
      volumeMultiplier: 1.2,
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.green : 'Green Noise',
      category: '@noise',
      icon: '🟢',
      path: 'assets/sounds/noise/green.ogg',
      volumeMultiplier: 1.2,
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.pink : 'Pink Noise',
      category: '@noise',
      icon: '🌸',
      path: 'assets/sounds/noise/pink-noise.ogg',
      volumeMultiplier: 1.2,
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.white : 'White Noise',
      category: '@noise',
      icon: '⚪',
      path: 'assets/sounds/noise/white-noise.ogg',
      volumeMultiplier: 1.2,
    ),
  ];

  if (!kDebugMode) {
    sounds.addAll([
      // Internet Radio
      NinjaSound(
        name: 'Yumi Co. Radio',
        category: '@internetRadio',
        icon: '🌆',
        path: 'https://yumicoradio.net/stream',
      ),
    ]);
  }

  if (kDebugMode) {
    sounds.addAll([
      NinjaSound(
        name: 'Sample Radio Mast',
        category: '@internetRadio',
        icon: '📻',
        path: 'https://audio-edge-cmc51.fra.h.radiomast.io/ref-128k-mp3-stereo',
      ),
      NinjaSound(
        name: 'Plaza One',
        category: '@internetRadio',
        icon: '🐈‍⬛',
        path: 'https://radio.plaza.one/mp3',
      ),
    ]);
  }

  return sounds;
}
