# What's new in 0.1.1

A correctness release. No new API, nothing to migrate, and no configuration to change.

Two of these are the reason to upgrade: on `0.1.0`, scanning **stopped after the first scan** for
any application that did not pause and resume around each one, and scans could arrive **truncated**.
Both affect the usage shown in the README. If you are on `0.1.0`, upgrade.

## Scanning no longer stops after the first scan

A scanner's terminator reaches the platform as a submit action, and a single-line editable responds
to that by giving up focus. The hidden input the widget keeps focused therefore lost its connection
after the first terminated scan, and nothing took focus back — so no second scan ever arrived.

The widget now restores focus after every scan, accepted or rejected.

Nothing to change in your code:

```dart
final scanner = HardwareScannerController();

scanner.scans.listen((scan) {
  print(scan.value); // now fires for the second scan, and the third
});
```

This was invisible to applications that pause while processing a scan and resume afterwards,
because resuming already restored focus:

```dart
scanner.scans.listen((scan) async {
  scanner.pause();          // this pattern hid the problem
  await processScan(scan.value);
  scanner.resume();
});
```

That pattern is still perfectly reasonable — it stops a second scan arriving mid-processing — it was
simply doing more than it looked like it was doing.

## Scans are no longer truncated

Key events and committed text reach an application through two separate channels, and they are not
synchronised. When the text channel lagged, the terminator key was handled while only part of the
barcode had been delivered. The result was two scans from one trigger pull: a short one, then the
real one.

```text
before:  a
         a100014
after:   a100014
```

While committed text is driving a scan, the terminator now comes from that same channel — the
editable's submit action — so it stays ordered with the characters. A platform that sends no submit
action still finishes the scan through `keyboardIdleTimeout`.

## Duplicate suppression compares the value only

A rugged device configured for both keystroke output and intent output sends one physical scan down
both transports. The keyboard transport cannot report a symbology and the broadcast transport can,
so the two arrived with different formats and the old check — value *and* format — let both through.

```dart
// One trigger pull on a device with both outputs enabled.
// 0.1.0: two scans, one with format unknown and one with format code128.
// 0.1.1: one scan; the second is reported as `duplicate` on the events stream.
```

If your application relied on receiving the same value twice within
`duplicateSuppressionWindow` because the formats differed, widen or disable the window:

```dart
HardwareScannerOptions(duplicateSuppressionWindow: Duration.zero)
```

## A paused scan no longer leaks into the next one

Scanning while the controller was paused left the text in the hidden input, so the next accepted
scan arrived as the leftover text followed by the new barcode. Every rejected scan now clears it,
whatever the reason for the rejection.

This mattered most in the pattern above — pause, process, resume — where an operator scanning again
during processing is routine.

## `start()` no longer hangs on the web

The package has no web implementation, and on the web an unimplemented method channel never answers
at all: the call sits unresolved rather than reporting that the plugin is missing. `start()`
therefore never returned.

It now reports `platformUnavailable`, the same as any other platform without the native plugin, and
keyboard scanning continues to work:

```dart
scanner.events.listen((event) {
  if (event.reason == HardwareScannerEventReason.platformUnavailable) {
    // No Android broadcast receiver here — HID scanning still works.
  }
});
```

## Smaller fixes

* `stop()` clears the paused state. `pause()` followed by `stop()` and `start()` previously returned
  a controller that looked started and silently dropped every scan.
* A delimiter received with nothing buffered emits no event. Every scan used to be followed by a
  stray `emptyPayload` on the events stream, which is noise in the stream applications use for
  operator feedback. `emptyPayload` still reports a candidate that existed and held no data.
* A scan submitted after `dispose()` is dropped rather than throwing on the closed stream.

## How these were found

Every one of these was found on real hardware, and the two serious ones only by running the
package's own example app — an application that pauses and resumes around each scan masks both of
them completely. The example app in `example/` shows accepted scans alongside the diagnostic stream
and is the fastest way to check a scanner setup.
