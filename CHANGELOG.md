## 0.1.1

### August 4, 2026

**Fixed:**

* Scanning no longer stops after the first scan.
* Scans are no longer truncated when the platform delivers characters slowly.
* A scan arriving while the controller is paused no longer leaks into the next one.
* One physical scan reaching the app over both transports is now delivered once.

**Compatibility:**

* Duplicate suppression compares the scanned value only, no longer the value and its format.

See [What's new in 0.1.1](doc/whats_new_0_1_1.md) for details and examples.

## 0.1.0

### August 3, 2026

**New:**

* HID keyboard scanner input over USB, Bluetooth, and built-in scanners, delivered through
  Flutter hardware key events.
* Android broadcast scanner support, with presets for Chainway, Zebra DataWedge, Honeywell,
  Datalogic, Unitech, CipherLab, Urovo/Seuic, and generic scanner services.
* A single normalized `HardwareScanResult` stream, regardless of which transport delivered the
  scan.
* Format filtering, regular-expression validation, duplicate suppression, and pause/resume.
* Diagnostic events for ignored scans, duplicates, lifecycle changes, and platform errors.
* Unicode text input by default, with an opt-in physical US-keyboard mode for ASCII-only scanners
  on non-US keyboard layouts.
* Optional Chainway SDK configuration, detected by reflection so that no vendor JAR ships with the
  package.
