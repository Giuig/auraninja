import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/widgets/bottom_player_bar.dart';
import 'package:flutter/material.dart';
import 'package:ninja_material/pages/first_page.dart';

import 'example_player_page.dart';

final FirstPageConfig appFirstPageConfig = FirstPageConfig(
  destinationsBuilder: appDestinationsBuilder,
  pages: appPages,
  bottomBar: BottomPlayerBar(),
);

final appPages = [ExamplePlayerPage()];

List<NavigationDestination> appDestinationsBuilder(BuildContext context) {
  return [
    NavigationDestination(
      selectedIcon: Icon(Icons.music_note),
      icon: Icon(Icons.music_note_outlined),
      label: AppLocalizations.of(context)!.sounds,
    ),
  ];
}
