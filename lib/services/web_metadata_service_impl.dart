import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fetch Icecast metadata by making a request to the stream.
/// Uses the Icy-MetaData header to request metadata from the server.
Future<String?> fetchIcecastMetadata(String url) async {
  try {
    debugPrint('[WebMetadata] Fetching metadata from: $url');

    // Make a HEAD request first to get Icy-MetaInt
    final response = await http.head(
      Uri.parse(url),
      headers: {'Icy-MetaData': '1'},
    ).timeout(const Duration(seconds: 5));

    final metaInt = response.headers['icy-metaint'];
    if (metaInt == null) {
      debugPrint('[WebMetadata] No Icy-MetaInt header');
      return null;
    }

    debugPrint('[WebMetadata] Icy-MetaInt: $metaInt');

    // For actual metadata content, we'd need to stream the response
    // For now, we can try to get metadata from the Icy-Name header
    final icyName = response.headers['icy-name'];
    if (icyName != null && icyName.isNotEmpty) {
      debugPrint('[WebMetadata] Station name: $icyName');
      return icyName;
    }

    return null;
  } catch (e) {
    debugPrint('[WebMetadata] Error: $e');
    return null;
  }
}
