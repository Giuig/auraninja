# Flutter-specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep class structure
-keepattributes *Annotation*,InnerClasses,EnclosingMethod

# Google Play Core classes (for deferred components)
# These classes are provided by Google Play Store at runtime
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# audio_service and just_audio
-dontwarn com.ryanheise.audioservice.**
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.audioservice.AudioService { *; }
-keep class com.ryanheise.audioservice.AudioServiceMediaBrowserCompat { *; }

# flutter_soloud (SoLoud native FFI bindings)
-keep class com.soloud.** { *; }
-dontwarn com.soloud.**
