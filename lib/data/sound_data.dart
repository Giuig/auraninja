import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/model/ninja_sound.dart';
import 'package:auraninja/model/sound_category.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

List<NinjaSound> buildLocalizedSounds(BuildContext? context) {
  final bool hasContext = context != null;
  final AppLocalizations? projLocalization =
      hasContext ? AppLocalizations.of(context) : null;

  final sounds = <NinjaSound>[
    // Weather
    NinjaSound(
      name: hasContext ? projLocalization!.lightRain : 'Light Rain',
      category: SoundCategory.weather,
      icon: '🌦️',
      path: 'assets/sounds/rain/light-rain.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.heavyRain : 'Heavy Rain',
      category: SoundCategory.weather,
      icon: '🌧️',
      path: 'assets/sounds/rain/heavy-rain.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.rainOnWindow : 'Rain on Window',
      category: SoundCategory.weather,
      icon: '🪟',
      path: 'assets/sounds/rain/rain-on-window.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.rainOnCarRoof : 'Rain on Car Roof',
      category: SoundCategory.weather,
      icon: '🚗',
      path: 'assets/sounds/rain/rain-on-car-roof.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.rainOnUmbrella : 'Rain on Umbrella',
      category: SoundCategory.weather,
      icon: '☂️',
      path: 'assets/sounds/rain/rain-on-umbrella.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.thunder : 'Thunder',
      category: SoundCategory.weather,
      icon: '⚡',
      path: 'assets/sounds/nature/thunder.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.wind : 'Wind',
      category: SoundCategory.weather,
      icon: '🌬️',
      path: 'assets/sounds/nature/wind.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.howlingWind : 'Howling Wind',
      category: SoundCategory.weather,
      icon: '💨',
      path: 'assets/sounds/nature/howling-wind.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.windInTrees : 'Wind in Trees',
      category: SoundCategory.weather,
      icon: '🌳',
      path: 'assets/sounds/nature/wind-in-trees.ogg',
    ),

    // Nature - Water
    NinjaSound(
      name: hasContext ? projLocalization!.waves : 'Waves',
      category: SoundCategory.nature,
      icon: '🌊',
      path: 'assets/sounds/nature/waves.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.river : 'River',
      category: SoundCategory.nature,
      icon: '🏞️',
      path: 'assets/sounds/nature/river.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.waterfall : 'Waterfall',
      category: SoundCategory.nature,
      icon: '💧',
      path: 'assets/sounds/nature/waterfall.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.droplets : 'Droplets',
      category: SoundCategory.nature,
      icon: '💦',
      path: 'assets/sounds/nature/droplets.ogg',
    ),

    // Nature - Forest & Ambient
    NinjaSound(
      name: hasContext ? projLocalization!.fire : 'Fire',
      category: SoundCategory.nature,
      icon: '🔥',
      path: 'assets/sounds/nature/fire.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.walkInSnow : 'Walk in Snow',
      category: SoundCategory.nature,
      icon: '❄️',
      path: 'assets/sounds/nature/walk-in-snow.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.walkOnLeaves : 'Walk on Leaves',
      category: SoundCategory.nature,
      icon: '🍂',
      path: 'assets/sounds/nature/walk-on-leaves.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.jungle : 'Jungle',
      category: SoundCategory.nature,
      icon: '🌴',
      path: 'assets/sounds/nature/jungle.ogg',
    ),

    // Nature - Animals
    NinjaSound(
      name: hasContext ? projLocalization!.birds : 'Birds',
      category: SoundCategory.nature,
      icon: '🐦',
      path: 'assets/sounds/nature/birds.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.crickets : 'Crickets',
      category: SoundCategory.nature,
      icon: '🦗',
      path: 'assets/sounds/nature/crickets.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.frog : 'Frog',
      category: SoundCategory.nature,
      icon: '🐸',
      path: 'assets/sounds/nature/frog.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.owl : 'Owl',
      category: SoundCategory.nature,
      icon: '🦉',
      path: 'assets/sounds/nature/owl.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.whale : 'Whale',
      category: SoundCategory.nature,
      icon: '🐋',
      path: 'assets/sounds/nature/whale.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.cat : 'Cat',
      category: SoundCategory.nature,
      icon: '🐱',
      path: 'assets/sounds/nature/cat.ogg',
    ),

    // Objects
    NinjaSound(
      name: hasContext ? projLocalization!.keyboard : 'Keyboard',
      category: SoundCategory.objects,
      icon: '⌨️',
      path: 'assets/sounds/things/keyboard.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.typewriter : 'Typewriter',
      category: SoundCategory.objects,
      icon: '📝',
      path: 'assets/sounds/things/typewriter.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.clock : 'Clock',
      category: SoundCategory.objects,
      icon: '🕐',
      path: 'assets/sounds/things/clock.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.windChimes : 'Wind Chimes',
      category: SoundCategory.objects,
      icon: '🎐',
      path: 'assets/sounds/things/wind-chimes.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.singingBowl : 'Singing Bowl',
      category: SoundCategory.objects,
      icon: '🥣',
      path: 'assets/sounds/things/singing-bowl.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.ceilingFan : 'Ceiling Fan',
      category: SoundCategory.objects,
      icon: '🌀',
      path: 'assets/sounds/things/ceiling-fan.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.boilingWater : 'Boiling Water',
      category: SoundCategory.objects,
      icon: '🫖',
      path: 'assets/sounds/things/boiling-water.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.bubbles : 'Bubbles',
      category: SoundCategory.objects,
      icon: '🫧',
      path: 'assets/sounds/things/bubbles.ogg',
    ),

    // Places
    NinjaSound(
      name: hasContext ? projLocalization!.cafe : 'Cafe',
      category: SoundCategory.places,
      icon: '☕',
      path: 'assets/sounds/places/cafe.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.library2 : 'Library',
      category: SoundCategory.places,
      icon: '📚',
      path: 'assets/sounds/places/library.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.office : 'Office',
      category: SoundCategory.places,
      icon: '🏢',
      path: 'assets/sounds/places/office.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.train : 'Train',
      category: SoundCategory.places,
      icon: '🚂',
      path: 'assets/sounds/places/train.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.airplane : 'Airplane',
      category: SoundCategory.places,
      icon: '✈️',
      path: 'assets/sounds/places/plane.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.underwater : 'Underwater',
      category: SoundCategory.places,
      icon: '🐡',
      path: 'assets/sounds/places/underwater.ogg',
    ),

    // Binaural
    NinjaSound(
      name: hasContext ? projLocalization!.laserFocus : 'Laser Focus',
      category: SoundCategory.binaural,
      icon: '🎯',
      path: 'assets/sounds/binaural/focus-10hz.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.creativeFlow : 'Creative Flow',
      category: SoundCategory.binaural,
      icon: '🎨',
      path: 'assets/sounds/binaural/alpha-8hz.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.zenCalm : 'Zen Calm',
      category: SoundCategory.binaural,
      icon: '🧘',
      path: 'assets/sounds/binaural/theta-5hz.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.deepCalm : 'Deep Calm',
      category: SoundCategory.binaural,
      icon: '🌙',
      path: 'assets/sounds/binaural/theta-4hz.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.deepSleep : 'Deep Sleep',
      category: SoundCategory.binaural,
      icon: '😴',
      path: 'assets/sounds/binaural/delta-2hz.ogg',
    ),
    NinjaSound(
      name:
          hasContext ? projLocalization!.theDeepestSleep : 'The Deepest Sleep',
      category: SoundCategory.binaural,
      icon: '💤',
      path: 'assets/sounds/binaural/delta-1hz.ogg',
    ),

    // Noise
    NinjaSound(
      name: hasContext ? projLocalization!.brown : 'Brown Noise',
      category: SoundCategory.noise,
      icon: '🟤',
      path: 'assets/sounds/noise/brown-noise.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.green : 'Green Noise',
      category: SoundCategory.noise,
      icon: '🟢',
      path: 'assets/sounds/noise/green.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.pink : 'Pink Noise',
      category: SoundCategory.noise,
      icon: '🌸',
      path: 'assets/sounds/noise/pink-noise.ogg',
    ),
    NinjaSound(
      name: hasContext ? projLocalization!.white : 'White Noise',
      category: SoundCategory.noise,
      icon: '⚪',
      path: 'assets/sounds/noise/white-noise.ogg',
    ),
  ];

  if (!kDebugMode) {
    sounds.addAll([
      NinjaSound(
        name: 'Yumi Co. Radio',
        category: SoundCategory.internetRadio,
        icon: '🌆',
        path: 'https://yumicoradio.net/stream',
      ),
    ]);
  }

  if (kDebugMode) {
    // Radio Mast's reference streams: built for player testing, royalty-free,
    // 24/7, and free for personal and commercial use.
    // https://www.radiomast.io/reference-streams
    //
    // Picked for CODEC COVERAGE, not for listening. Debug used to carry two
    // MP3 stations, so the AAC, HE-AAC and Ogg decode paths were never
    // exercised in development. One of those two was also a real community
    // station (radio.plaza.one), i.e. someone else's bandwidth paying for our
    // debug builds -- keep test traffic on endpoints that exist for it.
    //
    // Always use the canonical `streams.radiomast.io` host. It geo-redirects,
    // and this list used to hardcode the edge it returns here
    // (`audio-edge-cmc51.fra...`), which pinned every developer to Frankfurt.
    sounds.addAll([
      NinjaSound(
        name: 'Ref MP3 128k',
        category: SoundCategory.internetRadio,
        icon: '📻',
        path: 'https://streams.radiomast.io/ref-128k-mp3-stereo',
      ),
      NinjaSound(
        name: 'Ref AAC-LC 128k',
        category: SoundCategory.internetRadio,
        icon: '🎧',
        path: 'https://streams.radiomast.io/ref-128k-aaclc-stereo',
      ),
      NinjaSound(
        name: 'Ref Opus 64k',
        category: SoundCategory.internetRadio,
        icon: '🧊',
        path: 'https://streams.radiomast.io/ref-64k-ogg-opus-stereo',
      ),
      NinjaSound(
        name: 'Ref HE-AAC 24k mono',
        category: SoundCategory.internetRadio,
        icon: '📉',
        path: 'https://streams.radiomast.io/ref-24k-heaacv1-mono',
      ),
      // DELIBERATELY BROKEN -- do not "fix" this URL. It is the only way to
      // exercise the stream-failure and reconnect path on demand instead of
      // waiting for a real stream to drop. Debug builds only.
      NinjaSound(
        name: 'Ref dead stream (error test)',
        category: SoundCategory.internetRadio,
        icon: '💀',
        path: 'https://streams.radiomast.io/ref-does-not-exist',
      ),
    ]);
  }

  return sounds;
}
