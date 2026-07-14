# hardware_barcode_scanner

[![pub package](https://img.shields.io/pub/v/hardware_barcode_scanner.svg)](https://pub.dev/packages/hardware_barcode_scanner)
[![CI](https://github.com/eventer/hardware_barcode_scanner/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/eventer/hardware_barcode_scanner/actions/workflows/ci.yml)

Unified scanner input for Flutter apps that support HID keyboard scanners and
rugged Android devices that deliver scans through broadcast intents.

## Features

- USB, Bluetooth, and built-in HID scanners through Flutter keyboard events.
- Configurable Android broadcast presets for common rugged-device vendors.
- A single stream of normalized scan results, regardless of transport.
- Diagnostic events for ignored scans, duplicates, lifecycle changes, and
  platform errors.
- Format filtering, regular-expression validation, pause/resume, and duplicate
  suppression.
- Unicode text input by default, with an opt-in physical US-keyboard mode.

## Platform support

| Platform | HID keyboard input | Native scanner broadcasts |
| --- | --- | --- |
| Android | Yes | Yes |
| iOS | Yes | Not applicable |

Other Flutter platforms can use the Dart keyboard path when the platform
provides Flutter hardware-key events. The bundled native plugin targets Android
and iOS.

The package requires Flutter 3.19 or later and Dart 3.3 or later because it uses
Flutter's modern `KeyEvent` and `HardwareKeyboard` APIs. The native projects
support Android API 21+ and iOS 12+; newer Flutter releases can impose higher
deployment targets on the consuming app.

## Installation

Add the package to your app:

```sh
flutter pub add hardware_barcode_scanner
```

No Android permission or manifest entry is required. The plugin registers its
broadcast receiver only while a controller is started.

## Usage

Create and retain one controller, listen to accepted scans, and place the widget
around the part of the UI that should keep scanner focus:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _scanner = HardwareScannerController();
  StreamSubscription<HardwareScanResult>? _subscription;
  String _lastValue = 'Scan a barcode';

  @override
  void initState() {
    super.initState();
    _subscription = _scanner.scans.listen((scan) {
      setState(() => _lastValue = scan.value);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_scanner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HardwareScannerWidget(
      controller: _scanner,
      child: Center(child: Text(_lastValue)),
    );
  }
}
```

`HardwareScannerWidget` starts its controller by default. Set `startOnInit` to
`false` if your application manages `start()` itself. A widget does not stop a
shared controller unless `stopOnDispose` is enabled; the controller owner should
always call `dispose()`.

## Filtering and diagnostics

```dart
final scanner = HardwareScannerController(
  options: HardwareScannerOptions(
    supportedFormats: {
      HardwareScannerFormat.qrCode,
      HardwareScannerFormat.code128,
    },
    acceptUnknownFormat: true,
    validCharacterPattern: RegExp(r'^[A-Za-z0-9:._-]+$'),
    duplicateSuppressionWindow: const Duration(milliseconds: 750),
  ),
);

scanner.events.listen((event) {
  if (event.type == HardwareScannerEventType.ignored) {
    debugPrint('Ignored scan: ${event.reason}');
  }
});
```

Unknown formats are accepted by default because HID scanners normally provide
decoded text without symbology metadata. Reported native formats are normalized
and checked against `supportedFormats`. Surrounding whitespace is removed from
accepted values. Anchor `validCharacterPattern` with `^` and `$` when the whole
value must match.

Call `pause()` before processing a scan if subsequent scanner input should be
ignored temporarily, then call `resume()` when processing is complete.

## Unicode and keyboard layouts

The default mode preserves text committed by the operating system, including
Hebrew, emoji, and mixed Unicode values such as `1836.35חגצהsvsk`.

Some ASCII-only scanners identify as a US keyboard while the device uses a
different keyboard layout. In that case, punctuation can be transformed before
Flutter receives it. Opt into physical US-key interpretation for those scanners:

```dart
final scanner = HardwareScannerController(
  options: HardwareScannerOptions(preferPhysicalKeyboardInput: true),
);
```

Do not enable this option for values that contain real Unicode text. Native
scanner broadcasts are the most reliable option when exact decoded data is
available from the device.

## Android broadcast scanners

The default presets cover commonly used actions and extra names for Chainway,
Zebra DataWedge, Honeywell, Datalogic, Unitech, CipherLab, Urovo/Seuic, and
generic scanner services. Scanner services differ by model and configuration,
so configure the device to emit one of the preset actions or provide your own:

```dart
final scanner = HardwareScannerController(
  options: HardwareScannerOptions(
    androidBroadcastPresets: const [
      AndroidScannerBroadcastPreset(
        name: 'my_scanner',
        actions: {'com.example.scanner.SCAN'},
        dataKeys: ['scan_data'],
        formatKeys: ['scan_type'],
      ),
    ],
  ),
);
```

Android scanner broadcasts are not an authenticated transport. Use application
validation appropriate for your barcode format, especially if a scanned value
can trigger a sensitive operation.

### Optional Chainway SDK

The package does not require vendor JARs when a device is already configured to
emit broadcasts. If a Chainway device needs programmatic configuration, add the
vendor-provided `cw-deviceapi*.jar` to the consuming app:

```text
android/app/libs/cw-deviceapi20191022.jar
```

Then include local JARs in `android/app/build.gradle`:

```groovy
dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
}
```

The plugin detects the SDK through reflection when
`configureChainwayBroadcastOutput` is enabled. Do not redistribute a vendor JAR
unless its license allows it. Consumer R8/ProGuard rules for the reflected
classes are bundled with the plugin.

## Logging

Set `HardwareScannerOptions(showLogs: true)` to print diagnostics to the Flutter
console and Android logcat. Logging is off by default and can include scanned
values, so enable it only when appropriate for your data-handling policy.

See the [`example`](example/lib/main.dart) for a complete runnable app.
