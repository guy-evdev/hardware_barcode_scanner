# What's new in 0.1.2

A build-compatibility patch for Android. No Dart API changes and nothing to migrate in your code.

On Android Gradle Plugin (AGP) 9 with built-in Kotlin enabled, Flutter now warns that plugins that
apply the Kotlin Gradle Plugin will stop building in a future release. `0.1.1` was such a plugin.
`0.1.2` builds with:

| App setup | Supported |
| --- | --- |
| AGP 8.x with the Kotlin Gradle Plugin | Yes |
| AGP 9, `android.builtInKotlin=true` (the AGP 9 default) | Yes |
| AGP 9, `android.builtInKotlin=false` | Yes |

Nothing to change in a typical app: update the package and build.

```sh
flutter pub upgrade hardware_barcode_scanner
```

## What changed in the Android build

- The Kotlin plugin is applied only when the app does not already compile Kotlin through AGP.
- The plugin no longer pins its own AGP (8.11.1) or Kotlin (2.2.20) classpaths, so it cannot
  conflict with the versions your app uses.
- `kotlinOptions { jvmTarget }`, which current Kotlin has removed, is replaced by `compilerOptions`.
- The unused `android/settings.gradle.kts` is removed.

## If your app sets `android.newDsl=true`

Flutter's own Gradle plugin currently fails on AGP 9 with `android.newDsl=true`, before it reaches
any plugin. Keep `android.newDsl=false` (what `flutter create` writes) until Flutter supports it.

## Using AGP 9 built-in Kotlin in your app

AGP 9 bundles Kotlin 2.2.10, which is below Flutter's minimum. If the build reports that your
Kotlin version is too low, raise it by declaring the Kotlin plugin without applying it, in
`android/settings.gradle`:

```groovy
plugins {
    id "org.jetbrains.kotlin.android" version "2.3.20" apply false
}
```

See Flutter's guide for
[plugin authors](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors).
