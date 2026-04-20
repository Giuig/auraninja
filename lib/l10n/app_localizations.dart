import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja')
  ];

  /// No description provided for @sounds.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get sounds;

  /// No description provided for @mixes.
  ///
  /// In en, this message translates to:
  /// **'Mixes'**
  String get mixes;

  /// No description provided for @noMixes.
  ///
  /// In en, this message translates to:
  /// **'No mixes saved'**
  String get noMixes;

  /// No description provided for @noMixesHint.
  ///
  /// In en, this message translates to:
  /// **'Play sounds, then tap \'Save Mix\' in the player'**
  String get noMixesHint;

  /// No description provided for @saveMix.
  ///
  /// In en, this message translates to:
  /// **'Save Mix'**
  String get saveMix;

  /// No description provided for @mixSaved.
  ///
  /// In en, this message translates to:
  /// **'Mix saved'**
  String get mixSaved;

  /// No description provided for @activeSounds.
  ///
  /// In en, this message translates to:
  /// **'Active Sounds'**
  String get activeSounds;

  /// No description provided for @weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// No description provided for @nature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get nature;

  /// No description provided for @rain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get rain;

  /// No description provided for @wind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get wind;

  /// No description provided for @waves.
  ///
  /// In en, this message translates to:
  /// **'Waves'**
  String get waves;

  /// No description provided for @fire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get fire;

  /// No description provided for @binaural.
  ///
  /// In en, this message translates to:
  /// **'Binaural'**
  String get binaural;

  /// No description provided for @creativeFlow.
  ///
  /// In en, this message translates to:
  /// **'Creative Flow'**
  String get creativeFlow;

  /// No description provided for @deepCalm.
  ///
  /// In en, this message translates to:
  /// **'Deep Calm'**
  String get deepCalm;

  /// No description provided for @deepSleep.
  ///
  /// In en, this message translates to:
  /// **'Deep Sleep'**
  String get deepSleep;

  /// No description provided for @laserFocus.
  ///
  /// In en, this message translates to:
  /// **'Laser Focus'**
  String get laserFocus;

  /// No description provided for @theDeepestSleep.
  ///
  /// In en, this message translates to:
  /// **'The Deepest Sleep'**
  String get theDeepestSleep;

  /// No description provided for @zenCalm.
  ///
  /// In en, this message translates to:
  /// **'Zen Calm'**
  String get zenCalm;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @birds.
  ///
  /// In en, this message translates to:
  /// **'Birds'**
  String get birds;

  /// No description provided for @cat.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get cat;

  /// No description provided for @thunder.
  ///
  /// In en, this message translates to:
  /// **'Thunder'**
  String get thunder;

  /// No description provided for @cancelSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel Sleep Timer'**
  String get cancelSleepTimer;

  /// No description provided for @resumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume All'**
  String get resumeAll;

  /// No description provided for @pauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause All'**
  String get pauseAll;

  /// No description provided for @stopAll.
  ///
  /// In en, this message translates to:
  /// **'Stop All'**
  String get stopAll;

  /// Text for sleep timer option, showing minutes remaining
  ///
  /// In en, this message translates to:
  /// **'Sleep in {minutes} minutes'**
  String sleepInMinutes(int minutes);

  /// Text for displaying remaining sleep timer duration
  ///
  /// In en, this message translates to:
  /// **'Sleep in {minutes}:{seconds}'**
  String sleepRemainingTime(int minutes, String seconds);

  /// No description provided for @setSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Set Sleep Timer'**
  String get setSleepTimer;

  /// No description provided for @visualizer.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get visualizer;

  /// No description provided for @internetRadio.
  ///
  /// In en, this message translates to:
  /// **'Internet Radio'**
  String get internetRadio;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyToClipboard;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard!'**
  String get copiedToClipboard;

  /// No description provided for @noise.
  ///
  /// In en, this message translates to:
  /// **'Noise'**
  String get noise;

  /// No description provided for @brown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get brown;

  /// No description provided for @green.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get green;

  /// No description provided for @pink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get pink;

  /// No description provided for @white.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get white;

  /// No description provided for @vizLiquidRibbons.
  ///
  /// In en, this message translates to:
  /// **'Liquid Ribbons'**
  String get vizLiquidRibbons;

  /// No description provided for @vizBreathingOrb.
  ///
  /// In en, this message translates to:
  /// **'Breathing Orb'**
  String get vizBreathingOrb;

  /// No description provided for @vizRadialRings.
  ///
  /// In en, this message translates to:
  /// **'Radial Rings'**
  String get vizRadialRings;

  /// No description provided for @vizParticleDrift.
  ///
  /// In en, this message translates to:
  /// **'Particle Drift'**
  String get vizParticleDrift;

  /// No description provided for @vizRotatingMandala.
  ///
  /// In en, this message translates to:
  /// **'Rotating Mandala'**
  String get vizRotatingMandala;

  /// No description provided for @vizConstellation.
  ///
  /// In en, this message translates to:
  /// **'Constellation'**
  String get vizConstellation;

  /// No description provided for @vizMorphingPolygon.
  ///
  /// In en, this message translates to:
  /// **'Morphing Polygon'**
  String get vizMorphingPolygon;

  /// No description provided for @vizAurora.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get vizAurora;

  /// No description provided for @vizInkDiffusion.
  ///
  /// In en, this message translates to:
  /// **'Ink Diffusion'**
  String get vizInkDiffusion;

  /// No description provided for @playingSounds.
  ///
  /// In en, this message translates to:
  /// **'Playing sounds'**
  String get playingSounds;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @searchStationsHint.
  ///
  /// In en, this message translates to:
  /// **'Search stations by name…'**
  String get searchStationsHint;

  /// No description provided for @noStationsFound.
  ///
  /// In en, this message translates to:
  /// **'No stations found'**
  String get noStationsFound;

  /// No description provided for @addRadioStation.
  ///
  /// In en, this message translates to:
  /// **'Add Radio Station'**
  String get addRadioStation;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @url.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @streamUrl.
  ///
  /// In en, this message translates to:
  /// **'Stream URL'**
  String get streamUrl;

  /// No description provided for @streamUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://…'**
  String get streamUrlHint;

  /// No description provided for @stationNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Station name (optional)'**
  String get stationNameOptional;

  /// No description provided for @addStation.
  ///
  /// In en, this message translates to:
  /// **'Add Station'**
  String get addStation;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @river.
  ///
  /// In en, this message translates to:
  /// **'River'**
  String get river;

  /// No description provided for @waterfall.
  ///
  /// In en, this message translates to:
  /// **'Waterfall'**
  String get waterfall;

  /// No description provided for @walkInSnow.
  ///
  /// In en, this message translates to:
  /// **'Walk in Snow'**
  String get walkInSnow;

  /// No description provided for @walkOnLeaves.
  ///
  /// In en, this message translates to:
  /// **'Walk on Leaves'**
  String get walkOnLeaves;

  /// No description provided for @droplets.
  ///
  /// In en, this message translates to:
  /// **'Droplets'**
  String get droplets;

  /// No description provided for @jungle.
  ///
  /// In en, this message translates to:
  /// **'Jungle'**
  String get jungle;

  /// No description provided for @howlingWind.
  ///
  /// In en, this message translates to:
  /// **'Howling Wind'**
  String get howlingWind;

  /// No description provided for @windInTrees.
  ///
  /// In en, this message translates to:
  /// **'Wind in Trees'**
  String get windInTrees;

  /// No description provided for @things.
  ///
  /// In en, this message translates to:
  /// **'Things'**
  String get things;

  /// No description provided for @keyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get keyboard;

  /// No description provided for @typewriter.
  ///
  /// In en, this message translates to:
  /// **'Typewriter'**
  String get typewriter;

  /// No description provided for @clock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get clock;

  /// No description provided for @windChimes.
  ///
  /// In en, this message translates to:
  /// **'Wind Chimes'**
  String get windChimes;

  /// No description provided for @singingBowl.
  ///
  /// In en, this message translates to:
  /// **'Singing Bowl'**
  String get singingBowl;

  /// No description provided for @ceilingFan.
  ///
  /// In en, this message translates to:
  /// **'Ceiling Fan'**
  String get ceilingFan;

  /// No description provided for @boilingWater.
  ///
  /// In en, this message translates to:
  /// **'Boiling Water'**
  String get boilingWater;

  /// No description provided for @bubbles.
  ///
  /// In en, this message translates to:
  /// **'Bubbles'**
  String get bubbles;

  /// No description provided for @rain2.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get rain2;

  /// No description provided for @lightRain.
  ///
  /// In en, this message translates to:
  /// **'Light Rain'**
  String get lightRain;

  /// No description provided for @heavyRain.
  ///
  /// In en, this message translates to:
  /// **'Heavy Rain'**
  String get heavyRain;

  /// No description provided for @rainOnWindow.
  ///
  /// In en, this message translates to:
  /// **'Rain on Window'**
  String get rainOnWindow;

  /// No description provided for @rainOnCarRoof.
  ///
  /// In en, this message translates to:
  /// **'Rain on Car Roof'**
  String get rainOnCarRoof;

  /// No description provided for @rainOnUmbrella.
  ///
  /// In en, this message translates to:
  /// **'Rain on Umbrella'**
  String get rainOnUmbrella;

  /// No description provided for @otherSounds.
  ///
  /// In en, this message translates to:
  /// **'Other Sounds'**
  String get otherSounds;

  /// No description provided for @additionalSoundsSourcedFrom.
  ///
  /// In en, this message translates to:
  /// **'Additional sounds sourced from'**
  String get additionalSoundsSourcedFrom;

  /// No description provided for @crickets.
  ///
  /// In en, this message translates to:
  /// **'Crickets'**
  String get crickets;

  /// No description provided for @frog.
  ///
  /// In en, this message translates to:
  /// **'Frog'**
  String get frog;

  /// No description provided for @owl.
  ///
  /// In en, this message translates to:
  /// **'Owl'**
  String get owl;

  /// No description provided for @whale.
  ///
  /// In en, this message translates to:
  /// **'Whale'**
  String get whale;

  /// No description provided for @objects.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get objects;

  /// No description provided for @places.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get places;

  /// No description provided for @cafe.
  ///
  /// In en, this message translates to:
  /// **'Cafe'**
  String get cafe;

  /// No description provided for @library2.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library2;

  /// No description provided for @office.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get office;

  /// No description provided for @train.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get train;

  /// No description provided for @airplane.
  ///
  /// In en, this message translates to:
  /// **'Airplane'**
  String get airplane;

  /// No description provided for @underwater.
  ///
  /// In en, this message translates to:
  /// **'Underwater'**
  String get underwater;

  /// No description provided for @searchSounds.
  ///
  /// In en, this message translates to:
  /// **'Search sounds...'**
  String get searchSounds;

  /// No description provided for @nameMix.
  ///
  /// In en, this message translates to:
  /// **'Name your mix'**
  String get nameMix;

  /// No description provided for @editMix.
  ///
  /// In en, this message translates to:
  /// **'Edit mix'**
  String get editMix;

  /// No description provided for @mixSoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sound} other{{count} sounds}}'**
  String mixSoundCount(int count);

  /// No description provided for @mixNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Mix name'**
  String get mixNameLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @renameMix.
  ///
  /// In en, this message translates to:
  /// **'Rename mix'**
  String get renameMix;

  /// No description provided for @deleteMixTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete mix?'**
  String get deleteMixTitle;

  /// No description provided for @deleteMixContent.
  ///
  /// In en, this message translates to:
  /// **'This mix will be permanently removed.'**
  String get deleteMixContent;

  /// No description provided for @duplicateMixName.
  ///
  /// In en, this message translates to:
  /// **'Name already in use'**
  String get duplicateMixName;

  /// No description provided for @updateMixSounds.
  ///
  /// In en, this message translates to:
  /// **'Update sounds'**
  String get updateMixSounds;

  /// No description provided for @mixUpdated.
  ///
  /// In en, this message translates to:
  /// **'Mix updated'**
  String get mixUpdated;

  /// No description provided for @mixSoundsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sound in this mix couldn\'t be loaded} other{{count} sounds in this mix couldn\'t be loaded}}'**
  String mixSoundsUnavailable(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'it',
        'ja'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
