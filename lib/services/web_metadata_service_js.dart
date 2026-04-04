import 'dart:js_interop';
import 'package:flutter/foundation.dart';

/// JavaScript interop function to start persistent metadata connection.
/// Calls window.startIcecastMetadata(streamUrl, onUpdate) defined in web/index.html.
@JS('window.startIcecastMetadata')
external void _startIcecastMetadata(JSString streamUrl, JSFunction onUpdate);

/// JavaScript interop function to fetch cached Icecast metadata.
/// Calls window.fetchIcecastMetadata(streamUrl) defined in web/index.html.
@JS('window.fetchIcecastMetadata')
external JSString? _fetchIcecastMetadata(JSString streamUrl);

/// JavaScript interop function to stop metadata connection.
/// Calls window.stopIcecastMetadata() defined in web/index.html.
@JS('window.stopIcecastMetadata')
external void _stopIcecastMetadata();

/// Start persistent metadata connection for a stream.
/// The onUpdate callback will be called when metadata changes.
void startIcecastMetadataJS(String streamUrl, void Function(String) onUpdate) {
  try {
    debugPrint('[JSInterop] Starting metadata stream for: $streamUrl');
    _startIcecastMetadata(streamUrl.toJS, onUpdate.toJS);
  } catch (e) {
    debugPrint('[JSInterop] Error starting: $e');
  }
}

/// Fetch cached Icecast metadata from a stream URL.
/// Returns null if no metadata is available.
String? fetchIcecastMetadataJS(String streamUrl) {
  try {
    final result = _fetchIcecastMetadata(streamUrl.toJS);
    return result?.toDart;
  } catch (e) {
    debugPrint('[JSInterop] Error fetching: $e');
    return null;
  }
}

/// Stop the metadata connection.
void stopIcecastMetadataJS() {
  try {
    _stopIcecastMetadata();
    debugPrint('[JSInterop] Stopped metadata connection');
  } catch (e) {
    debugPrint('[JSInterop] Error stopping: $e');
  }
}
