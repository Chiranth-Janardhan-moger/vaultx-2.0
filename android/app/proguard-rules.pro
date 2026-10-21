# Flutter wrapper and core engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn javax.annotation.**

# Preserve annotations and signature reflection
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod

# Google ML Kit & Text Recognition
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# AndroidX Biometric & Local Auth
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn androidx.biometric.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Camera & Mobile Scanner
-keep class androidx.camera.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class io.flutter.plugins.camera.** { *; }
-dontwarn androidx.camera.**

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Bonsoir (Zeroconf / NSD network discovery)
-keep class fr.skyost.bonsoir.** { *; }
-dontwarn fr.skyost.bonsoir.**

# Cryptography & KeyStore Native Ciphers
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn com.google.crypto.tink.**
