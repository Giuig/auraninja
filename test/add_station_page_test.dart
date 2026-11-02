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
import 'package:auraninja/services/user_stations_service.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

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
          },
          {
            'name': 'Other FM',
            'url_resolved': 'https://example.com/other',
            'country': 'Italy',
            'tags': 'jazz',
            'favicon': '',
          }
        ]),
        200,
      ));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Types a query and lets the debounced, mocked radio-browser search land.
  Future<void> search(WidgetTester tester, Widget app) =>
      http.runWithClient(() async {
        await tester.pumpWidget(app);
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.enterText(find.byType(TextField).first, 'test');
        await tester.pump(const Duration(milliseconds: 600)); // debounce
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }, () => radioBrowser);

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  group('issue #13: adding several stations in one visit', () {
    testWidgets('the page stays open and marks each added station',
        (tester) async {
      await search(tester, page());

      await tapAndSettle(tester, find.byTooltip('Add Station').first);

      expect(find.byType(AddStationPage), findsOneWidget);
      expect(find.byTooltip('Added'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Add Station').first);

      expect(find.byTooltip('Added'), findsNWidgets(2));
      final saved = await tester.runAsync(UserStationsService.load);
      expect(saved!.map((s) => s.path),
          ['https://example.com/stream', 'https://example.com/other']);
    });

    testWidgets('a station saved earlier shows as added', (tester) async {
      SharedPreferences.setMockInitialValues({
        'user_radio_stations': jsonEncode([
          {
            'name': 'Test FM',
            'category': '@internetRadio',
            'icon': '',
            'path': 'https://example.com/stream',
            'isUserAdded': true,
          }
        ]),
      });

      await search(tester, page());

      expect(find.byTooltip('Added'), findsOneWidget);
      expect(find.byTooltip('Add Station'), findsOneWidget);
    });

    testWidgets('going back reports that stations were added', (tester) async {
      bool? result;
      final host = MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      const AddStationPage(categoryKey: '@internetRadio'),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await http.runWithClient(() async {
        await tester.pumpWidget(host);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'test');
        await tester.pump(const Duration(milliseconds: 600));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }, () => radioBrowser);

      await tapAndSettle(tester, find.byTooltip('Add Station').first);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });

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
    expect(find.byTooltip('Add Station'), findsNWidgets(2));
  });
}
