/// Stub implementation for non-web platforms.
/// Does nothing - metadata polling is only for web.
class WebMetadataService {
  final String streamUrl;
  final void Function(String streamTitle) onUpdate;
  final Duration updateInterval;

  WebMetadataService({
    required this.streamUrl,
    required this.onUpdate,
    this.updateInterval = const Duration(seconds: 10),
  });

  void start() {}

  void stop() {}

  void dispose() {}
}
