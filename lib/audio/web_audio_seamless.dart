/// Conditional import: loads web implementation on web, stub on other platforms.
library;

export 'web_audio_seamless_stub.dart'
    if (dart.library.js_interop) 'web_audio_seamless_impl.dart';
