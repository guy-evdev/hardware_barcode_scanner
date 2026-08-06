import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';

import 'support/fake_scanner_platform.dart';

/// Duplicate-suppression and pause/resume behaviour on both transports.
///
/// Both features are time-dependent and both are shared by the keyboard and the
/// Android broadcast path, so each is asserted against both transports rather
/// than against the keyboard alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Builds a started controller and registers its teardown.
  Future<
      ({
        HardwareScannerController controller,
        FakeHardwareBarcodeScannerPlatform platform,
        List<HardwareScanResult> scans,
        List<HardwareScannerEvent> events,
      })> startController({
    Duration duplicateSuppressionWindow = const Duration(milliseconds: 60),
    Duration keyboardIdleTimeout = const Duration(milliseconds: 40),
  }) async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(
      platform: platform,
      options: HardwareScannerOptions(
        duplicateSuppressionWindow: duplicateSuppressionWindow,
        keyboardIdleTimeout: keyboardIdleTimeout,
      ),
    );
    final scans = <HardwareScanResult>[];
    final events = <HardwareScannerEvent>[];
    final scanSubscription = controller.scans.listen(scans.add);
    final eventSubscription = controller.events.listen(events.add);
    addTearDown(() async {
      await scanSubscription.cancel();
      await eventSubscription.cancel();
      await controller.dispose();
      await platform.controller.close();
    });

    await controller.start();
    return (
      controller: controller,
      platform: platform,
      scans: scans,
      events: events,
    );
  }

  group('duplicate suppression', () {
    test('suppresses an identical keyboard value inside the window', () async {
      final harness = await startController();

      harness.controller.acceptRawScan(
        value: 'EV-DUP',
        source: HardwareScannerSource.keyboard,
      );
      harness.controller.acceptRawScan(
        value: 'EV-DUP',
        source: HardwareScannerSource.keyboard,
      );
      await pumpEventQueue();

      expect(harness.scans.map((scan) => scan.value), <String>['EV-DUP']);
      expect(
        harness.events
            .where(
              (event) => event.reason == HardwareScannerEventReason.duplicate,
            )
            .single
            .type,
        HardwareScannerEventType.ignored,
      );
    });

    test('accepts the same value once the window has elapsed', () async {
      final harness = await startController(
        duplicateSuppressionWindow: const Duration(milliseconds: 30),
      );

      harness.controller.acceptRawScan(
        value: 'EV-DUP',
        source: HardwareScannerSource.keyboard,
      );
      await Future<void>.delayed(const Duration(milliseconds: 90));
      harness.controller.acceptRawScan(
        value: 'EV-DUP',
        source: HardwareScannerSource.keyboard,
      );
      await pumpEventQueue();

      expect(harness.scans.map((scan) => scan.value), <String>[
        'EV-DUP',
        'EV-DUP',
      ]);
      expect(
        harness.events.where(
          (event) => event.reason == HardwareScannerEventReason.duplicate,
        ),
        isEmpty,
      );
    });

    test('suppresses a repeated broadcast scan inside the window', () async {
      final harness = await startController();

      harness.platform.emitScan('ABC-123', format: 'CODE_128');
      await pumpEventQueue();
      harness.platform.emitScan('ABC-123', format: 'CODE_128');
      await pumpEventQueue();

      expect(harness.scans.map((scan) => scan.value), <String>['ABC-123']);
      expect(
        harness.events.where(
          (event) => event.reason == HardwareScannerEventReason.duplicate,
        ),
        hasLength(1),
      );
    });

    test('suppresses a repeat that arrives on the other transport', () async {
      final harness = await startController();

      harness.controller.acceptRawScan(
        value: 'ABC-123',
        source: HardwareScannerSource.keyboard,
        rawFormat: 'CODE_128',
      );
      harness.platform.emitScan('ABC-123', format: 'CODE_128');
      await pumpEventQueue();

      expect(harness.scans, hasLength(1));
      expect(harness.scans.single.source, HardwareScannerSource.keyboard);
      expect(
        harness.events
            .where(
              (event) => event.reason == HardwareScannerEventReason.duplicate,
            )
            .single
            .source,
        HardwareScannerSource.androidBroadcast,
      );
    });

    test('suppresses the same value even when the format differs', () async {
      final harness = await startController();

      harness.platform.emitScan('ABC-123', format: 'CODE_128');
      await pumpEventQueue();
      harness.platform.emitScan('ABC-123', format: 'QR_CODE');
      await pumpEventQueue();

      // Suppression is by value alone. It used to require the format to match
      // too, which meant one physical scan reaching the app over both
      // transports was delivered twice — see the cross-transport test below.
      expect(harness.scans, hasLength(1));
      expect(harness.scans.single.format, HardwareScannerFormat.code128);
    });

    test('suppresses one physical scan arriving on both transports', () async {
      final harness = await startController();

      // A rugged device configured for both keystroke output and intent output
      // sends the same scan twice. HID carries no symbology, the broadcast
      // does, so the two arrive with different formats despite being one scan.
      harness.controller.acceptRawScan(
        value: 'ABC-123',
        source: HardwareScannerSource.keyboard,
      );
      harness.platform.emitScan('ABC-123', format: 'CODE_128');
      await pumpEventQueue();

      expect(harness.scans, hasLength(1));
      expect(harness.scans.single.source, HardwareScannerSource.keyboard);
      expect(
        harness.events
            .where(
              (event) => event.reason == HardwareScannerEventReason.duplicate,
            )
            .single
            .source,
        HardwareScannerSource.androidBroadcast,
      );
    });

    test('a different value inside the window is not suppressed', () async {
      final harness = await startController();

      harness.controller.acceptRawScan(
        value: 'EV-1',
        source: HardwareScannerSource.keyboard,
      );
      harness.controller.acceptRawScan(
        value: 'EV-2',
        source: HardwareScannerSource.keyboard,
      );
      await pumpEventQueue();

      expect(harness.scans.map((scan) => scan.value), <String>['EV-1', 'EV-2']);
    });
  });

  group('replaceBuffer contract', () {
    /// Drives the controller the way a consumer-owned text field would.
    Future<List<String>> scanThrough(
      HardwareScannerController controller,
      List<String> barcodes, {
      required bool clearFieldAfterScan,
    }) async {
      final values = <String>[];
      final field = StringBuffer();
      controller.scans.listen((scan) {
        values.add(scan.value);
        if (clearFieldAfterScan) field.clear();
      });

      for (final barcode in barcodes) {
        for (final character in barcode.split('')) {
          field.write(character);
          controller.handleTextInput(field.toString(), replaceBuffer: true);
        }
        controller.handleTextInput('\n');
        await pumpEventQueue();
      }
      return values;
    }

    test('clearing the field between scans keeps values separate', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(
        platform: platform,
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(seconds: 30),
        ),
      );
      addTearDown(() async {
        await controller.dispose();
        await platform.controller.close();
      });
      await controller.start();

      final values = await scanThrough(
        controller,
        ['AAA', 'BBB', 'CCC'],
        clearFieldAfterScan: true,
      );

      expect(values, <String>['AAA', 'BBB', 'CCC']);
    });

    test('not clearing the field concatenates every scan onto the last',
        () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(
        platform: platform,
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(seconds: 30),
        ),
      );
      addTearDown(() async {
        await controller.dispose();
        await platform.controller.close();
      });
      await controller.start();

      final values = await scanThrough(
        controller,
        ['AAA', 'BBB', 'CCC'],
        clearFieldAfterScan: false,
      );

      // Pinned as the documented consequence of breaking the replaceBuffer
      // contract, not as desirable behaviour. The controller replaces its
      // buffer with exactly what it is handed; if the caller's field still
      // holds the previous scan, that is what it gets.
      expect(values, <String>['AAA', 'AAABBB', 'AAABBBCCC']);
    });

    test('forwarding characters needs no clearing', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(
        platform: platform,
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(seconds: 30),
        ),
      );
      final values = <String>[];
      controller.scans.listen((scan) => values.add(scan.value));
      addTearDown(() async {
        await controller.dispose();
        await platform.controller.close();
      });
      await controller.start();

      for (final barcode in ['AAA', 'BBB', 'CCC']) {
        for (final character in barcode.split('')) {
          controller.handleTextInput(character);
        }
        controller.handleTextInput('\n');
        await pumpEventQueue();
      }

      expect(values, <String>['AAA', 'BBB', 'CCC']);
    });
  });

  group('format reporting per transport', () {
    test('keyboard scans never carry a symbology', () async {
      final harness = await startController(
        keyboardIdleTimeout: const Duration(seconds: 30),
      );

      harness.controller.handleTextInput('4006381333931\n');
      await pumpEventQueue();

      final scan = harness.scans.single;
      expect(
        scan.format,
        HardwareScannerFormat.unknown,
        reason: 'a HID scanner sends decoded characters and nothing else',
      );
      expect(scan.rawFormat, isNull);
      expect(scan.hasKnownFormat, isFalse);
      expect(scan.source, HardwareScannerSource.keyboard);
    });

    test('broadcast scans carry the vendor label and its normalization',
        () async {
      final harness = await startController();

      harness.platform.emitScan('4006381333931', format: 'EAN_13');
      await pumpEventQueue();

      final scan = harness.scans.single;
      expect(scan.format, HardwareScannerFormat.ean13);
      expect(scan.rawFormat, 'EAN_13');
      expect(scan.hasKnownFormat, isTrue);
    });

    test('a broadcast scan without a label is unknown, like keyboard',
        () async {
      final harness = await startController();

      harness.platform.emitScan('4006381333931');
      await pumpEventQueue();

      expect(harness.scans.single.format, HardwareScannerFormat.unknown);
      expect(harness.scans.single.rawFormat, isNull);
    });

    test('acceptUnknownFormat false rejects every keyboard scan', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(
        platform: platform,
        options: HardwareScannerOptions(
          acceptUnknownFormat: false,
          keyboardIdleTimeout: const Duration(seconds: 30),
        ),
      );
      final scans = <HardwareScanResult>[];
      final events = <HardwareScannerEvent>[];
      final scanSubscription = controller.scans.listen(scans.add);
      final eventSubscription = controller.events.listen(events.add);
      addTearDown(() async {
        await scanSubscription.cancel();
        await eventSubscription.cancel();
        await controller.dispose();
        await platform.controller.close();
      });

      await controller.start();
      controller.handleTextInput('4006381333931\n');
      await pumpEventQueue();

      expect(
        scans,
        isEmpty,
        reason: 'documented sharp edge: this setting disables HID entirely',
      );
      expect(
        events
            .where((event) => event.type == HardwareScannerEventType.ignored)
            .single
            .reason,
        HardwareScannerEventReason.unsupportedFormat,
      );
    });
  });

  group('pause and resume', () {
    test('a paused broadcast scan is ignored, not queued', () async {
      final harness = await startController();

      harness.controller.pause();
      harness.platform.emitScan('EV-PAUSED');
      await pumpEventQueue();

      expect(harness.scans, isEmpty);
      final ignored = harness.events
          .where((event) => event.type == HardwareScannerEventType.ignored)
          .single;
      expect(ignored.reason, HardwareScannerEventReason.paused);
      expect(ignored.source, HardwareScannerSource.androidBroadcast);

      harness.controller.resume();
      await pumpEventQueue();
      expect(harness.scans, isEmpty, reason: 'resume must not replay the scan');
    });

    test('pause discards a partially buffered keyboard scan', () async {
      final harness = await startController();

      harness.controller.handleTextInput('EV-PARTIAL');
      harness.controller.pause();
      harness.controller.resume();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(harness.scans, isEmpty);
    });

    test('stop discards a partially buffered keyboard scan', () async {
      final harness = await startController();

      harness.controller.handleTextInput('EV-PARTIAL');
      await harness.controller.stop();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(harness.scans, isEmpty);
      expect(harness.controller.isStarted, isFalse);
    });

    test('input is ignored entirely while stopped', () async {
      final harness = await startController();

      await harness.controller.stop();
      harness.controller.handleTextInput('EV-STOPPED\n');
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(harness.scans, isEmpty);
    });

    test('pause and resume are idempotent', () async {
      final harness = await startController();

      harness.controller.pause();
      harness.controller.pause();
      harness.controller.resume();
      harness.controller.resume();
      await pumpEventQueue();

      expect(
        harness.events
            .where(
              (event) => event.reason == HardwareScannerEventReason.paused,
            )
            .length,
        1,
      );
      expect(
        harness.events
            .where(
              (event) => event.reason == HardwareScannerEventReason.resumed,
            )
            .length,
        1,
      );
      expect(harness.controller.isPaused, isFalse);
    });

    test('resume restores acceptance on both transports', () async {
      final harness = await startController();

      harness.controller.pause();
      harness.controller.resume();
      harness.controller.acceptRawScan(
        value: 'EV-KEYBOARD',
        source: HardwareScannerSource.keyboard,
      );
      harness.platform.emitScan('EV-BROADCAST');
      await pumpEventQueue();

      expect(harness.scans.map((scan) => scan.value), <String>[
        'EV-KEYBOARD',
        'EV-BROADCAST',
      ]);
    });

    test('isPaused reflects the current state', () async {
      final harness = await startController();

      expect(harness.controller.isPaused, isFalse);
      harness.controller.pause();
      expect(harness.controller.isPaused, isTrue);
      harness.controller.resume();
      expect(harness.controller.isPaused, isFalse);
    });
  });

  group('keyboard buffer timing', () {
    test('flushes after the idle timeout with no delimiter', () async {
      final harness = await startController(
        keyboardIdleTimeout: const Duration(milliseconds: 40),
      );

      harness.controller.handleTextInput('EV-IDLE');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(harness.scans, isEmpty, reason: 'must wait out the idle timeout');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(harness.scans.single.value, 'EV-IDLE');
    });

    test('a delimiter flushes without waiting for the timeout', () async {
      final harness = await startController(
        keyboardIdleTimeout: const Duration(seconds: 30),
      );

      harness.controller.handleTextInput('EV-DELIMITED\n');
      await pumpEventQueue();

      expect(harness.scans.single.value, 'EV-DELIMITED');
    });

    test('each keystroke restarts the idle timeout', () async {
      final harness = await startController(
        keyboardIdleTimeout: const Duration(milliseconds: 60),
      );

      harness.controller.handleTextInput('EV');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      harness.controller.handleTextInput('-1');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(harness.scans, isEmpty, reason: 'the timer must have restarted');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(harness.scans.single.value, 'EV-1');
    });

    test('a trailing delimiter submits only the buffered value', () async {
      final harness = await startController(
        keyboardIdleTimeout: const Duration(seconds: 30),
      );

      harness.controller.handleTextInput('EV-1\nEV-2\n');
      await pumpEventQueue();

      expect(harness.scans.map((scan) => scan.value), <String>['EV-1', 'EV-2']);
    });

    test('a delimiter with nothing buffered submits nothing', () async {
      final harness = await startController();

      harness.controller.handleTextInput('\n');
      await pumpEventQueue();

      expect(harness.scans, isEmpty);
      expect(
        harness.events.where(
          (event) => event.type == HardwareScannerEventType.ignored,
        ),
        isEmpty,
        reason: 'there was no candidate to reject',
      );
    });

    test('a repeated delimiter does not report an empty payload', () async {
      final harness = await startController(
        keyboardIdleTimeout: const Duration(seconds: 30),
      );

      // The widget can see one Enter twice — once as a key event and once as
      // the platform's submit action — so the second flush finds an empty
      // buffer. That must not put a junk event in the diagnostics stream,
      // which is the stream consumers use for operator feedback.
      harness.controller.handleTextInput('EV-1\n');
      harness.controller.handleTextInput('\n');
      await pumpEventQueue();

      expect(harness.scans.single.value, 'EV-1');
      expect(
        harness.events.where(
          (event) => event.reason == HardwareScannerEventReason.emptyPayload,
        ),
        isEmpty,
      );
    });

    test('a whitespace-only value is still an empty payload', () async {
      final harness = await startController();

      harness.controller.handleTextInput('   \n');
      await pumpEventQueue();

      expect(harness.scans, isEmpty);
      expect(
        harness.events
            .where(
              (event) =>
                  event.reason == HardwareScannerEventReason.emptyPayload,
            )
            .single
            .type,
        HardwareScannerEventType.ignored,
        reason: 'a candidate did exist, it just had no data',
      );
    });
  });
}
