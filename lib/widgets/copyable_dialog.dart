import 'package:auraninja/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies [text], reporting whether it actually worked instead of letting a
/// platform refusal escape as an unhandled error.
///
/// `Clipboard.setData` is not universally available, despite reading like it
/// is. On web it throws `PlatformException(copy_fail)` when the browser denies
/// `clipboard-write`, and browsers additionally only permit a clipboard write
/// during *transient user activation* — which an `await` earlier in the same
/// handler can consume, so a copy attempted after awaiting something else is
/// routinely refused even where permission would otherwise be granted.
///
/// Every caller must therefore handle the `false` case rather than assume
/// success. [showCopyableDialog] is the general answer.
Future<bool> copyToClipboard(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {
    return false;
  }
}

/// Shows [text] as selectable content with its own copy button, so there is
/// always a way for the user to get it.
///
/// Two things make this work where a bare `Clipboard.setData` does not:
///
/// * The copy button is a **fresh user gesture** with no preceding `await`,
///   which is the condition browsers require for a clipboard write.
/// * If the copy is refused anyway, the text is on screen and selectable. That
///   matters most on web, where Flutter paints to a canvas — text rendered
///   anywhere else in the app cannot be selected by the user at all.
///
/// [display] overrides how the text is presented (e.g. a title/subtitle pair);
/// [text] is always what gets copied.
///
/// [onShare], when non-null, adds a Share button that hands off to the
/// platform's own share sheet. Pass it only where such a sheet exists — on web
/// most desktop browsers have no Web Share API, so a button there would be a
/// control that does nothing. It should report whether the share happened; the
/// dialog closes only if it did, leaving the code on screen otherwise.
Future<void> showCopyableDialog({
  required BuildContext context,
  required String title,
  required String description,
  required String text,
  Widget? display,
  Future<bool> Function()? onShare,
}) async {
  final l10n = AppLocalizations.of(context);
  // Captured before any await: after the dialog pops, its own context can no
  // longer resolve a messenger.
  final messenger = ScaffoldMessenger.of(context);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      // scrollable, because the text is unbounded: a mix code is base64url over
      // the whole mix, and a mix has no cap on its sound count while a stream's
      // path is an arbitrary-length URL.
      scrollable: true,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          const SizedBox(height: 12),
          display ??
              SelectableText(
                text,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n?.close ?? 'Close'),
        ),
        if (onShare != null)
          TextButton.icon(
            onPressed: () async {
              final shared = await onShare();
              if (shared && ctx.mounted) Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.share_outlined, size: 18),
            label: Text(l10n?.shareMix ?? 'Share'),
          ),
        FilledButton.icon(
          onPressed: () async {
            final copied = await copyToClipboard(text);
            // Only dismiss on success — if the copy was refused the user still
            // needs the text on screen to select by hand.
            if (copied && ctx.mounted) Navigator.of(ctx).pop();
            messenger.showSnackBar(SnackBar(
              content: Text(copied
                  ? (l10n?.copiedToClipboard ?? 'Copied to clipboard')
                  : (l10n?.copyFailed ?? "Couldn't copy to the clipboard")),
              duration: const Duration(seconds: 2),
            ));
          },
          icon: const Icon(Icons.copy, size: 18),
          label: Text(l10n?.copyToClipboard ?? 'Copy'),
        ),
      ],
    ),
  );
}
