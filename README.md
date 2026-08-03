# hardware_barcode_scanner

[![pub package](https://img.shields.io/pub/v/hardware_barcode_scanner.svg)](https://pub.dev/packages/hardware_barcode_scanner)
[![CI](https://github.com/guy-evdev/hardware_barcode_scanner/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/guy-evdev/hardware_barcode_scanner/actions/workflows/ci.yml)

Unified scanner input for Flutter apps that support HID keyboard scanners and
rugged Android devices that deliver scans through broadcast intents.

## When to use this package

- The barcodes are read by **dedicated scanner hardware** — USB, Bluetooth, or built-in — rather
  than by the device camera.
- The app has to support both HID keyboard scanners and rugged Android devices that deliver scans
  through broadcast intents, **without branching on the transport**.
- No runtime permission, manifest entry, or camera access is wanted: the plugin registers its
  broadcast receiver only while a controller is started.
- Scanner input has to keep working while the UI has focus elsewhere, with duplicate suppression
  and format filtering handled for you.

**Not a fit if** the barcodes are read from the device camera — this package never decodes an
image, it only normalizes input that scanner hardware has already decoded.

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

**A HID scanner never reports a barcode format.** It presents itself as a
keyboard and sends the decoded characters, so `format` is always
`HardwareScannerFormat.unknown` and `rawFormat` is always `null` for those
scans. This is not a limitation of the package — there is nothing in a keystroke
stream to read a symbology from. Only Android broadcast scanners can report a
format, and only when the scanner service includes one.

Two consequences worth knowing before you configure filtering:

- `supportedFormats` has no effect on HID scans. They carry no format, so
  nothing is there to match.
- **`acceptUnknownFormat: false` rejects every HID scan.** It is on by default
  for exactly this reason. Turn it off only in a deployment that is exclusively
  broadcast scanners.

Reported native formats are normalized and checked against `supportedFormats`.
Surrounding whitespace is removed from accepted values. Anchor
`validCharacterPattern` with `^` and `$` when the whole value must match.

Call `pause()` before processing a scan if subsequent scanner input should be
ignored temporarily, then call `resume()` when processing is complete.

## Advanced usage

The following live in [`doc/recipes.md`](doc/recipes.md):

- [Unicode and keyboard layouts](doc/recipes.md#unicode-and-keyboard-layouts) — preserving Unicode
  values, and the opt-in physical US-keyboard mode for ASCII-only scanners.
- [Android broadcast scanners](doc/recipes.md#android-broadcast-scanners) — the bundled vendor
  presets, defining your own, and why broadcasts are not an authenticated transport.
- [Optional Chainway SDK](doc/recipes.md#optional-chainway-sdk) — reflection-based configuration
  for devices that need it.
- [Logging](doc/recipes.md#logging) — diagnostics, and the data-handling caveat.

See the [`example`](example/lib/main.dart) for a complete runnable app.
