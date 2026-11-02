import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/widgets/reorder_sheet.dart';

void main() {
  const entries = [
    ReorderEntry(path: 'rain', label: 'Light Rain', icon: '🌧️'),
    ReorderEntry(path: 'yumi', label: 'Yumi Co. Radio', icon: '📻'),
    ReorderEntry(path: 'fire', label: 'Fire', icon: '🔥'),
  ];

  Future<List<List<String>>> openSheet(WidgetTester tester) async {
    final changes = <List<String>>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showReorderSheet(
              context,
              title: 'Reorder favourites',
              entries: entries,
              onChanged: changes.add,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return changes;
  }

  testWidgets('lists every entry in order, each with a drag handle',
      (tester) async {
    await openSheet(tester);

    expect(find.text('Reorder favourites'), findsOneWidget);
    final top = [
      for (final label in ['Light Rain', 'Yumi Co. Radio', 'Fire'])
        tester.getTopLeft(find.text(label)).dy
    ];
    expect(top, orderedEquals([...top]..sort()));
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
  });

  testWidgets('dragging the last entry to the top reports the new order',
      (tester) async {
    final changes = await openSheet(tester);

    final handle = find.byIcon(Icons.drag_handle).last;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -300), timeStamp: Duration.zero);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(changes, isNotEmpty);
    expect(changes.last, ['fire', 'rain', 'yumi']);
  });

  testWidgets('Done closes the sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Reorder favourites'), findsNothing);
  });
}
