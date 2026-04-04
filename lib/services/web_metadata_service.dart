// Conditional import for web-specific functionality
export 'web_metadata_service_stub.dart'
    if (dart.library.js_interop) 'web_metadata_service_web.dart';
