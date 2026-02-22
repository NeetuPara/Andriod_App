# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Llama Flutter Android
-keep class com.write4me.llama_flutter_android.** { *; }
-keepclassmembers class com.write4me.llama_flutter_android.** { *; }

# Keep MainActivity for MethodChannel
-keep class com.example.flutter_app.MainActivity { *; }

# Keep Kotlin Metadata (prevents crashes in some reflection use cases)
-keep class kotlin.Metadata { *; }

# Keep Kotlin Functions and Coroutines (prevents JNI crash when calling lambdas)
-keep class kotlin.jvm.functions.** { *; }
-keep class kotlinx.coroutines.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Flutter TTS
-keep class com.tundralabs.fluttertts.** { *; }

# Speech to Text
-keep class com.csdcorp.speech_to_text.** { *; }

# General
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Google Play Services (Deferred Components)
# We don't use dynamic features, but Flutter references these classes.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
