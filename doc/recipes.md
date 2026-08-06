# Recipes

Advanced usage for `hardware_barcode_scanner`. Start with the
[README](../README.md) — it covers installation, the common scanning flow, and filtering.

## Contents

- [Unicode and keyboard layouts](#unicode-and-keyboard-layouts)
- [Barcode formats over HID](#barcode-formats-over-hid)
- [Android broadcast scanners](#android-broadcast-scanners)
- [Optional Chainway SDK](#optional-chainway-sdk)
- [Logging](#logging)

## Unicode and keyboard layouts

The default mode preserves text committed by the operating system, including Hebrew, emoji, and
mixed Unicode values such as `1836.35חגצהsvsk`.

Some ASCII-only scanners identify as a US keyboard while the device uses a different keyboard
layout. In that case, punctuation can be transformed before Flutter receives it. Opt into physical
US-key interpretation for those scanners:

```dart
final scanner = HardwareScannerController(
  options: HardwareScannerOptions(preferPhysicalKeyboardInput: true),
);
```

Do not enable this option for values that contain real Unicode text. Native scanner broadcasts are
the most reliable option when exact decoded data is available from the device.

## Barcode formats over HID

A HID scanner is a keyboard. It sends the decoded characters and nothing else, so every scan with
`source == HardwareScannerSource.keyboard` reports `format == HardwareScannerFormat.unknown` and
`rawFormat == null`. No configuration changes this, because there is no symbology in the keystroke
stream to read.

If the application genuinely needs to know the symbology, there are three options, in order of
preference:

1. **Use an Android broadcast scanner.** Its service sends the label alongside the data, which is
   the only transport here that can report a format at all.
2. **Infer it from the value.** For fixed-layout barcodes this is usually enough — a 13-digit
   numeric value is an EAN-13, a known prefix identifies your own value format, and so on. Do this
   in your own code, against your own data, rather than expecting the package to guess.
3. **Enable the scanner's Code ID or AIM identifier prefix** — and read the warning below first.

⚠️ **The package does not parse symbology prefixes.** Many handheld scanners can be configured to
transmit an AIM identifier (`]C1` for Code 128, `]Q0` for QR, `]E0` for EAN-13) or a vendor Code ID
ahead of the data. If you turn that on, the prefix arrives as ordinary keystrokes and becomes part
of `value` — `]C1ABC-123` rather than `ABC-123`. It does **not** populate `format`. Strip it
yourself before using the value:

```dart
final aimIdentifier = RegExp(r'^\].{2}');

scanner.scans.listen((scan) {
  final value = scan.value.replaceFirst(aimIdentifier, '');
  // Map the stripped prefix to a symbology here if you need one.
});
```

Prefer option 1 or 2. Option 3 trades a clean value for a format you then have to decode by hand.

## Android broadcast scanners

Broadcast scanning is **Android only**. On iOS, and on any other platform, the HID keyboard path is
the only transport.

The default presets cover commonly used actions and extra names for Chainway, Zebra DataWedge,
Honeywell, Datalogic, Unitech, CipherLab, Urovo/Seuic, and generic scanner services. Scanner
services differ by model and configuration, so configure the device to emit one of the preset
actions or provide your own:

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

**Android scanner broadcasts are not an authenticated transport.** Any application on the device
can emit a matching intent. Use application validation appropriate for your barcode format,
especially if a scanned value can trigger a sensitive operation.

## Optional Chainway SDK

The package does not require vendor JARs when a device is already configured to emit broadcasts.
If a Chainway device needs programmatic configuration, add the vendor-provided `cw-deviceapi*.jar`
to the consuming app:

```text
android/app/libs/cw-deviceapi20191022.jar
```

Then include local JARs in `android/app/build.gradle`:

```groovy
dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
}
```

The plugin detects the SDK through reflection when `configureChainwayBroadcastOutput` is enabled.
Do not redistribute a vendor JAR unless its license allows it. Consumer R8/ProGuard rules for the
reflected classes are bundled with the plugin.

**Scan-failure broadcasts are left off deliberately.** Chainway can broadcast when a trigger pull
fails to decode, but it sends those on the same action and the same data key as a successful scan,
with a marker value such as `cancel`. Nothing downstream can distinguish them from a barcode that
genuinely reads that way, so the package does not ask for them — otherwise a failed trigger pull
arrives as a scan whose value is `cancel`.

If a device has been configured for failure broadcasts through the vendor's own settings app
rather than by this package, it will still send them and they will arrive as ordinary scans. Turn
that setting off on the device, or filter the value in your own code.

## Logging

Set `HardwareScannerOptions(showLogs: true)` to print diagnostics to the Flutter console and
Android logcat. Logging is off by default and **can include scanned values**, so enable it only
when appropriate for your data-handling policy.
