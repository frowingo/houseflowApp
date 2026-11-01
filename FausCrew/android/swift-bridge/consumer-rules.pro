# jextract JNI names are looked up at runtime and must survive R8.
-keep class com.fauscrew.androidbridge.** { *; }

# SwiftKitCore uses these JDK Flight Recorder annotations as metadata only.
# Android has no JFR runtime; R8 can safely ignore the absent annotation types.
-dontwarn jdk.jfr.Description
-dontwarn jdk.jfr.Label
