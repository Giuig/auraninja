import 'package:auraninja/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:auraninja/model/ninja_sound.dart';

List<NinjaSound> buildLocalizedSounds(BuildContext? context) {
  final bool hasContext = context != null;
  // Safely get AppLocalizations if context is available
  final AppLocalizations? projLocalization =
      hasContext ? AppLocalizations.of(context) : null;

  final sounds = <NinjaSound>[
    // Weather
    NinjaSound(
      name: hasContext ? projLocalization!.lightRain : 'Light Rain',
      category: '@weather',
      icon: '🌦️',
      path: 'assets/sounds/rain/light-rain.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.heavyRain : 'Heavy Rain',
      category: '@weather',
      icon: '🌧️',
      path: 'assets/sounds/rain/heavy-rain.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.rainOnWindow : 'Rain on Window',
      category: '@weather',
      icon: '🪟',
      path: 'assets/sounds/rain/rain-on-window.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.rainOnCarRoof : 'Rain on Car Roof',
      category: '@weather',
      icon: '🚗',
      path: 'assets/sounds/rain/rain-on-car-roof.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.rainOnUmbrella : 'Rain on Umbrella',
      category: '@weather',
      icon: '☂️',
      path: 'assets/sounds/rain/rain-on-umbrella.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.thunder : 'Thunder',
      category: '@weather',
      icon: '⚡',
      path: 'assets/sounds/nature/thunder.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.wind : 'Wind',
      category: '@weather',
      icon: '🌬️',
      path: 'assets/sounds/nature/wind.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.howlingWind : 'Howling Wind',
      category: '@weather',
      icon: '💨',
      path: 'assets/sounds/nature/howling-wind.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.windInTrees : 'Wind in Trees',
      category: '@weather',
      icon: '🌳',
      path: 'assets/sounds/nature/wind-in-trees.ogg',
      attribution: '@',
    ),

    // Nature - Water
    NinjaSound(
      name: hasContext ? projLocalization!.waves : 'Waves',
      category: '@nature',
      icon: '🌊',
      path: 'assets/sounds/nature/waves.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.river : 'River',
      category: '@nature',
      icon: '🏞️',
      path: 'assets/sounds/nature/river.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.waterfall : 'Waterfall',
      category: '@nature',
      icon: '💧',
      path: 'assets/sounds/nature/waterfall.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.droplets : 'Droplets',
      category: '@nature',
      icon: '💦',
      path: 'assets/sounds/nature/droplets.ogg',
      attribution: '@',
    ),

    // Nature - Forest & Ambient
    NinjaSound(
      name: hasContext ? projLocalization!.fire : 'Fire',
      category: '@nature',
      icon: '🔥',
      path: 'assets/sounds/nature/fire.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.walkInSnow : 'Walk in Snow',
      category: '@nature',
      icon: '❄️',
      path: 'assets/sounds/nature/walk-in-snow.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.walkOnLeaves : 'Walk on Leaves',
      category: '@nature',
      icon: '🍂',
      path: 'assets/sounds/nature/walk-on-leaves.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.jungle : 'Jungle',
      category: '@nature',
      icon: '🌴',
      path: 'assets/sounds/nature/jungle.ogg',
      attribution: '@',
    ),

    // Nature - Animals
    NinjaSound(
      name: hasContext ? projLocalization!.birds : 'Birds',
      category: '@nature',
      icon: '🐦',
      path: 'assets/sounds/nature/birds.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.crickets : 'Crickets',
      category: '@nature',
      icon: '🦗',
      path: 'assets/sounds/nature/crickets.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.frog : 'Frog',
      category: '@nature',
      icon: '🐸',
      path: 'assets/sounds/nature/frog.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.owl : 'Owl',
      category: '@nature',
      icon: '🦉',
      path: 'assets/sounds/nature/owl.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.whale : 'Whale',
      category: '@nature',
      icon: '🐋',
      path: 'assets/sounds/nature/whale.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.cat : 'Cat',
      category: '@nature',
      icon: '🐱',
      path: 'assets/sounds/nature/cat.ogg',
      attribution: '@',
    ),

    // Objects
    NinjaSound(
      name: hasContext ? projLocalization!.keyboard : 'Keyboard',
      category: '@objects',
      icon: '⌨️',
      path: 'assets/sounds/things/keyboard.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.typewriter : 'Typewriter',
      category: '@objects',
      icon: '📝',
      path: 'assets/sounds/things/typewriter.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.clock : 'Clock',
      category: '@objects',
      icon: '🕐',
      path: 'assets/sounds/things/clock.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.windChimes : 'Wind Chimes',
      category: '@objects',
      icon: '🎐',
      path: 'assets/sounds/things/wind-chimes.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.singingBowl : 'Singing Bowl',
      category: '@objects',
      icon: '🥣',
      path: 'assets/sounds/things/singing-bowl.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.ceilingFan : 'Ceiling Fan',
      category: '@objects',
      icon: '🌀',
      path: 'assets/sounds/things/ceiling-fan.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.boilingWater : 'Boiling Water',
      category: '@objects',
      icon: '🫖',
      path: 'assets/sounds/things/boiling-water.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.bubbles : 'Bubbles',
      category: '@objects',
      icon: '🫧',
      path: 'assets/sounds/things/bubbles.ogg',
      attribution: '@',
    ),

    // Places
    NinjaSound(
      name: hasContext ? projLocalization!.cafe : 'Cafe',
      category: '@places',
      icon: '☕',
      path: 'assets/sounds/places/cafe.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.library2 : 'Library',
      category: '@places',
      icon: '📚',
      path: 'assets/sounds/places/library.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.office : 'Office',
      category: '@places',
      icon: '🏢',
      path: 'assets/sounds/places/office.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.train : 'Train',
      category: '@places',
      icon: '🚂',
      path: 'assets/sounds/places/train.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.airplane : 'Airplane',
      category: '@places',
      icon: '✈️',
      path: 'assets/sounds/places/plane.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.underwater : 'Underwater',
      category: '@places',
      icon: '🐡',
      path: 'assets/sounds/places/underwater.ogg',
      attribution: '@',
    ),

    NinjaSound(
      name: hasContext ? projLocalization!.laserFocus : 'Laser Focus',
      category: '@binaural',
      icon: '🎯',
      path: 'assets/sounds/binaural/focus-10hz.ogg',
      attribution: 'Laser Focus by Binauro — https://binauro.com/downloads',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.creativeFlow : 'Creative Flow',
      category: '@binaural',
      icon: '🎨',
      path: 'assets/sounds/binaural/alpha-8hz.ogg',
      attribution: 'Creative Flow by Binauro — https://binauro.com/downloads',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.zenCalm : 'Zen Calm',
      category: '@binaural',
      icon: '🧘',
      path: 'assets/sounds/binaural/theta-5hz.ogg',
      attribution: 'Zen Calm by Binauro — https://binauro.com/downloads',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.deepCalm : 'Deep Calm',
      category: '@binaural',
      icon: '🌙',
      path: 'assets/sounds/binaural/theta-4hz.ogg',
      attribution: 'Deep Calm by Binauro — https://binauro.com/downloads',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.deepSleep : 'Deep Sleep',
      category: '@binaural',
      icon: '😴',
      path: 'assets/sounds/binaural/delta-2hz.ogg',
      attribution: 'Deep Sleep by Binauro — https://binauro.com/downloads',
    ),
    NinjaSound(
      name:
          hasContext ? projLocalization!.theDeepestSleep : 'The Deepest Sleep',
      category: '@binaural',
      icon: '💤',
      path: 'assets/sounds/binaural/delta-1hz.ogg',
      attribution:
          'The Deepest Sleep by Binauro — https://binauro.com/downloads',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.brown : 'Brown Noise',
      category: '@noise',
      icon: '🟤',
      path: 'assets/sounds/noise/brown-noise.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.green : 'Green Noise',
      category: '@noise',
      icon: '🟢',
      path: 'assets/sounds/noise/green.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.pink : 'Pink Noise',
      category: '@noise',
      icon: '🌸',
      path: 'assets/sounds/noise/pink-noise.ogg',
      attribution: '@',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.white : 'White Noise',
      category: '@noise',
      icon: '⚪',
      path: 'assets/sounds/noise/white-noise.ogg',
      attribution: '@',
    ),
  ];

  if (!kDebugMode) {
    sounds.addAll([
      //Internet Radio
      NinjaSound(
        name: 'Yumi Co. Radio',
        category: '@internetRadio',
        icon: '🌆',
        path: 'https://yumicoradio.net/stream',
        attribution: 'Yumi Co. Radio - https://yumicoradio.net',
      ),
    ]);
  }

  if (kDebugMode) {
    sounds.addAll([
      //Unauthorized yet
      NinjaSound(
        name: 'Sample Radio Mast',
        category: '@internetRadio',
        icon: '📻',
        path: 'https://audio-edge-cmc51.fra.h.radiomast.io/ref-128k-mp3-stereo',
        attribution: "Sample Radio Mast - https://radiomast.io",
      ),
      NinjaSound(
        name: 'Plaza One',
        category: '@internetRadio',
        icon: '🐈‍⬛',
        path: 'https://radio.plaza.one/mp3',
        attribution: 'Plaza One - https://plaza.one',
      ),
    ]);
  }

  if (kDebugMode && !kDebugMode) {
    sounds.addAll([
      //Unauthorized yet
      NinjaSound(
        name: 'Cliqhop IDM',
        category: '@internetRadio',
        icon: '🤖',
        path: 'https://ice3.somafm.com/cliqhop-128-mp3',
        attribution: "SomaFM's Cliqhop - https://somafm.com/cliqhop",
      ),
      NinjaSound(
        name: 'Vaporwaves',
        category: '@internetRadio',
        icon: '💿',
        path: 'https://ice3.somafm.com/vaporwaves-128-mp3',
        attribution: "SomaFM's Vaporwaves - https://somafm.com/vaporwaves",
      ),
      NinjaSound(
        name: 'Groove Salad',
        category: '@internetRadio',
        icon: '🥗',
        path: 'https://ice3.somafm.com/groovesalad-128-mp3',
        attribution: "SomaFM's Groove Salad - https://somafm.com/groovesalad",
      ),
      NinjaSound(
        name: 'Plaza One',
        category: '@internetRadio',
        icon: '🐈‍⬛',
        path: 'https://radio.plaza.one/mp3',
        attribution: 'Plaza One - https://plaza.one',
      ),
    ]);
  }

  return sounds;
}
