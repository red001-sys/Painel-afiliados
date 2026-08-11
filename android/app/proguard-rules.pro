# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Supabase / Gotrue / Realtime (usam reflection/serialization)
-keep class io.github.jan.supabase.** { *; }
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keep,includedescriptorclasses class com.redstar.painel.**$$serializer { *; }
-keepclassmembers class com.redstar.painel.** {
    *** Companion;
}
-keepclasseswithmembers class com.redstar.painel.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# image_picker / file_picker / video_player (usam reflection nos plugins nativos)
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
