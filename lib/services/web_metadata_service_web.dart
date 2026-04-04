import 'dart:async';
import 'package:flutter/foundation.dart';

// Import the JS interop implementation
import 'web_metadata_service_js.dart'
    show fetchIcecastMetadataJS, startIcecastMetadataJS, stopIcecastMetadataJS;

/// Web implementation that uses a single persistent connection for ICY metadata.
///
/// Starts one connection to the stream and continuously parses metadata.
/// Polling is only used to read the cached value for Flutter state updates.
class WebMetadataService {
  final String streamUrl;
  final void Function(String streamTitle) onUpdate;
  final Duration updateInterval;

  Timer? _pollingTimer;
  String _lastMetadata = '';
  bool _isRunning = false;

  WebMetadataService({
    required this.streamUrl,
    required this.onUpdate,
    this.updateInterval =
        const Duration(seconds: 5), // Faster polling for cached values
  });

  /// Start metadata service.
  /// Opens ONE persistent connection and polls for cached values.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    debugPrint('[WebMetadata] Starting metadata service for: $streamUrl');

    // Start ONE persistent connection to the stream
    startIcecastMetadataJS(streamUrl, (title) {
      // Real-time callback when metadata changes
      if (_isRunning && title.isNotEmpty && title != _lastMetadata) {
        _lastMetadata = title;
        debugPrint('[WebMetadata] Real-time update: $title');
        onUpdate(title);
      }
    });

    // Also poll for cached values (in case callback doesn't fire immediately)
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(updateInterval, (_) {
      if (_isRunning) {
        _readCachedMetadata();
      }
    });
  }

  /// Stop metadata service and close connection.
  void stop() {
    _isRunning = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _lastMetadata = '';
    // Close the persistent connection
    stopIcecastMetadataJS();
  }

  /// Read cached metadata (no new connection, just reads existing value).
  void _readCachedMetadata() {
    final title = fetchIcecastMetadataJS(streamUrl);
    if (title != null && title.isNotEmpty && title != _lastMetadata) {
      _lastMetadata = title;
      debugPrint('[WebMetadata] Cached update: $title');
      onUpdate(title);
    }
  }

  void dispose() {
    stop();
  }
}
