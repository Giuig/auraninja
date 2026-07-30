import 'dart:convert';

import 'package:auraninja/model/mix.dart';

/// Offline, copy-pasteable share codes for mixes.
///
/// Format: `AN1` + base64url(JSON). The `AN1` prefix versions the payload and
/// lets [tryDecode] pull the code out of pasted text that may contain
/// surrounding words (e.g. a chat message). Only the shareable content is
/// encoded — the recipient gets a fresh `id`/`createdAt` on import so codes
/// stay short and never collide with existing mixes.
class MixCodec {
  MixCodec._();

  static const _prefix = 'AN1';
  static final _token = RegExp(r'AN1[A-Za-z0-9_=-]+');

  /// Encode [mix] to a shareable code.
  static String encode(Mix mix) {
    final payload = <String, dynamic>{
      'name': mix.name,
      'icon': mix.icon,
      'sounds': mix.sounds.map((s) => s.toJson()).toList(),
    };
    final bytes = utf8.encode(jsonEncode(payload));
    return _prefix + base64Url.encode(bytes);
  }

  /// Extract and decode a mix from arbitrary pasted [text].
  ///
  /// Returns a new [Mix] (fresh id + createdAt) or `null` if no valid code is
  /// found or it fails to parse.
  static Mix? tryDecode(String text) {
    final match = _token.firstMatch(text);
    if (match == null) return null;
    try {
      final b64 = match.group(0)!.substring(_prefix.length);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(b64)));
      if (decoded is! Map<String, dynamic>) return null;

      final rawSounds = decoded['sounds'];
      if (rawSounds is! List || rawSounds.isEmpty) return null;
      final sounds = rawSounds
          .map((s) => MixSound.fromJson(s as Map<String, dynamic>))
          .toList();

      final name = (decoded['name'] as String?)?.trim();
      return Mix(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: (name != null && name.isNotEmpty) ? name : 'Imported mix',
        icon: decoded['icon'] as String?,
        sounds: sounds,
      );
    } catch (_) {
      return null;
    }
  }
}
