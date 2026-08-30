# Flutter নির্দিষ্ট রুলস
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase নির্দিষ্ট রুলস
-keep class com.google.firebase.** { *; }

# AdMob নির্দিষ্ট রুলস
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Google Play Core সম্পর্কিত রুলস (যাতে R8 এরর না দেয়)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
