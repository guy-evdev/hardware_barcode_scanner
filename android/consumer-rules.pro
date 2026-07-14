# Optional rugged-device vendor SDKs used through reflection.
#
# These rules are shipped as consumer rules so Android apps using this plugin
# keep the reflected classes/methods when R8/ProGuard minification is enabled.

-keep class com.barcode.** { *; }
-keep class com.rscja.** { *; }
-keep class com.scanner.** { *; }
-keep class com.zebra.adc.decoder.** { *; }
-keep class com.hsm.barcode.** { *; }

-dontwarn com.barcode.**
-dontwarn com.rscja.**
-dontwarn com.scanner.**
-dontwarn com.zebra.adc.decoder.**
-dontwarn com.hsm.barcode.**
