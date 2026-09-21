import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/bootstrap.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/pages/config/first_page_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:ninja_material/bootstrap.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Namespace this app's stored preferences. WEB ONLY, and it must stay the
  // first thing that happens.
  //
  // Every ninja app is served from the same origin —
  // https://giuig.github.io/<app>/ — and browser storage is scoped to the
  // ORIGIN, not the path. `shared_preferences` writes every key with a flat
  // `flutter.` prefix, so the apps shared one key space and silently
  // overwrote each other: picking a theme colour in one repainted the others,
  // and `favorites` collided outright (this app stores sound paths there,
  // tvninja stores channel ids).
  //
  // Native is deliberately excluded. Each platform app already has its own
  // sandbox, so the collision cannot happen there — and changing the prefix
  // on Android would orphan every existing user's favourites, mixes, volumes
  // and theme. Web users lose their stored settings once, which is the
  // accepted cost of ending the collision.
  //
  // `setPrefix` throws a StateError once anything has called
  // `SharedPreferences.getInstance()`, and `initAudioHandler()` below does
  // exactly that — so this cannot move any later, and it cannot live in
  // `runNinjaApp` either.
  if (kIsWeb) {
    SharedPreferences.setPrefix('auraninja.');
  }

  if (!kIsWeb) {
    await SoLoud.instance.init();
  }
  final audioHandler = await initAudioHandler();

  runNinjaApp(
    defaultSeedColor: Colors.lightGreen.shade500,
    specificLocalizationDelegate: AppLocalizations.delegate,
    appFirstPageConfig: appFirstPageConfig,
    additionalProviders: [
      ChangeNotifierProvider<WrapperAudioHandler>.value(value: audioHandler),
    ],
  );
}
