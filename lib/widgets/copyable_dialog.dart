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

/// Shows [text] as selectable content, so there is always a way for the user to
/// get it.
///
/// What makes this work where a bare `Clipboard.setData` does not is that the
/// text is on screen and selectable. That matters most on web, where Flutter
/// paints to a canvas — text rendered anywhere else in the app cannot be
/// selected by the user at all. Selecting it here and copying with the
/// browser's own copy command **does** work even when `Clipboard.setData` is
/// refused: Flutter mirrors a [SelectableText] into a real DOM `<textarea>`,
/// and the browser's copy command is not gated by the `clipboard-write`
/// permission that governs the async clipboard API. Measured 2026-09-18.
///
/// [showCopyButton] controls the built-in copy action, and the distinction is
/// not cosmetic:
///
/// * A **proactive** caller (the dialog is the primary way to get the text)
///   should keep it. Pressing it is a fresh user gesture with no preceding
///   `await`, which is the condition browsers require for a clipboard write, so
///   it succeeds wherever the clipboard is permitted at all.
/// * A **failure-fallback** caller — one that opens this dialog only *because* a
///   copy already failed — must pass `false`. That caller's first attempt was
///   already the optimal one, so a refusal was on permission grounds and an
///   identical retry is refused identically. Offering it under a description
///   that says to copy by hand is incoherent, and it was reported as such.
///   Verified: both attempts reject with the same `NotAllowedError` while
///   `document.hasFocus()` is true, and Flutter attempts no `execCommand`
///   fallback because it selects its clipboard strategy upfront.
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
  Future<bool> Function()? onShare,
  bool showCopyButton = true,
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
        if (showCopyButton)
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
