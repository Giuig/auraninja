import 'package:auraninja/l10n/app_localizations.dart';
import 'first_page_config.dart';
import 'package:flutter/material.dart';
import 'package:ninja_material/bootstrap.dart';

void main() => runNinjaApp(
      defaultSeedColor: const Color.fromARGB(255, 0, 94, 255),
      specificLocalizationDelegate: AppLocalizations.delegate,
      appFirstPageConfig: appFirstPageConfig,
    );
