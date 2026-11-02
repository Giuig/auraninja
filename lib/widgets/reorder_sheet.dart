import 'package:auraninja/l10n/app_localizations.dart';
import 'package:auraninja/widgets/sound_icon.dart';
import 'package:flutter/material.dart';

/// One row of the reorder sheet.
class ReorderEntry {
  final String path;
  final String label;

  /// Anything [buildSoundIcon] accepts: IconData, an emoji, or a logo URL.
  final dynamic icon;

  const ReorderEntry({
    required this.path,
    required this.label,
    required this.icon,
  });
}

/// Lets the user reorder a Sounds-page section (issue #14). Rows move by an
/// explicit drag handle, the same way with touch, mouse and keyboard, rather
/// than by long-pressing cards in the grid. [onChanged] gets the full new
/// order of paths after every move, so the section behind the sheet updates
/// live and nothing is lost if the sheet is dismissed instead of closed.
Future<void> showReorderSheet(
  BuildContext context, {
  required String title,
  required List<ReorderEntry> entries,
  required ValueChanged<List<String>> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReorderSheet(
      title: title,
      entries: entries,
      onChanged: onChanged,
    ),
  );
}

class _ReorderSheet extends StatefulWidget {
  final String title;
  final List<ReorderEntry> entries;
  final ValueChanged<List<String>> onChanged;

  const _ReorderSheet({
    required this.title,
    required this.entries,
    required this.onChanged,
  });

  @override
  State<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends State<_ReorderSheet> {
  late final List<ReorderEntry> _entries = List.of(widget.entries);

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      _entries.insert(newIndex, _entries.removeAt(oldIndex));
    });
    widget.onChanged([for (final e in _entries) e.path]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n?.done ?? 'Done'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: scrollController,
                buildDefaultDragHandles: false,
                itemCount: _entries.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return ListTile(
                    key: ValueKey(entry.path),
                    leading: SizedBox(
                      width: 32,
                      height: 32,
                      child: buildSoundIcon(entry.icon, 28,
                          theme.colorScheme.onSurfaceVariant),
                    ),
                    title: Text(entry.label),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Icon(
                          Icons.drag_handle,
                          semanticLabel: l10n?.dragToReorder ?? 'Drag to reorder',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
