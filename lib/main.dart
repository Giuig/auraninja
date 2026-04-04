import 'package:auraninja/audio/wrapper_audio_handler.dart';
import 'package:auraninja/bootstrap.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/pages/config/first_page_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:ninja_material/bootstrap.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
