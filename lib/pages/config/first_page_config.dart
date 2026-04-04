import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/pages/credits_page.dart';
import 'package:auraninja/pages/sounds_page.dart';
import 'package:auraninja/pages/visualizer_page.dart';
import 'package:auraninja/widgets/bottom_player_bar.dart';
import 'package:flutter/material.dart';
import 'package:ninja_material/pages/first_page.dart';

final FirstPageConfig appFirstPageConfig = FirstPageConfig(
  destinationsBuilder: appDestinationsBuilder,
  pages: appPages,
  bottomBar: BottomPlayerBar(),
);

final appPages = [
  SoundsPage(),
  VisualizerPage(),
  CreditsPage(),
];

List<NavigationDestination> appDestinationsBuilder(BuildContext context) {
  return [
    NavigationDestination(
      selectedIcon: Icon(Icons.music_note),
      icon: Icon(Icons.music_note_outlined),
      label: AppLocalizations.of(context)!.sounds,
    ),
    NavigationDestination(
      selectedIcon: Icon(Icons.waves),
      icon: Icon(Icons.waves_outlined),
      label: AppLocalizations.of(context)!.visualizer,
    ),
    NavigationDestination(
      selectedIcon: Icon(Icons.book),
      icon: Icon(Icons.book_outlined),
      label: AppLocalizations.of(context)!.credits,
    ),
  ];
}
