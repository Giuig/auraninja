import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// http is pulled in through other packages; lib/pages/add_station_page.dart
// already imports it the same way.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/pages/add_station_page.dart';

/// Screen readers announce an IconButton by its tooltip. Without one, the
/// add-station page's search and "+" buttons were read out as just "button".
void main() {
  Widget page() => const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddStationPage(categoryKey: '@internetRadio'),
      );

  final radioBrowser = MockClient((request) async => http.Response(
        jsonEncode([
          {
            'name': 'Test FM',
            'url_resolved': 'https://example.com/stream',
            'country': 'Italy',
            'tags': 'ambient',
            'favicon': '',
          }
        ]),
        200,
      ));

  testWidgets('the search button has a label', (tester) async {
    await tester.pumpWidget(page());

    expect(find.byTooltip('Search'), findsOneWidget);
  });

  testWidgets('each search result\'s add button has a label', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(page());
      await tester.enterText(find.byType(TextField).first, 'test');
      await tester.pump(const Duration(milliseconds: 600)); // debounce
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }, () => radioBrowser);

    expect(find.text('Test FM'), findsOneWidget);
    expect(find.byTooltip('Add Station'), findsOneWidget);
  });
}
