import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';

import 'support/fake_scanner_platform.dart';

/// Lifecycle, platform-failure, and filtering paths of the controller.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lifecycle', () {
    test('start emits a started lifecycle event and registers presets',
        () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      expect(controller.isStarted, isFalse);
      await controller.start();
      await pumpEventQueue();

      expect(controller.isStarted, isTrue);
      expect(platform.started, isTrue);
      expect(
        platform.lastPresets,
        same(AndroidScannerBroadcastPreset.defaults),
      );
      expect(events.single.reason, HardwareScannerEventReason.started);
    });

    test('a second start is a no-op', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      await controller.start();
      await controller.start();
      await pumpEventQueue();

      expect(
        events.where(
          (event) => event.reason == HardwareScannerEventReason.started,
        ),
        hasLength(1),
      );
    });

    test('stop while stopped is a no-op', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      await controller.stop();
      await pumpEventQueue();

      expect(events, isEmpty);
      expect(platform.stopped, isFalse);
    });

    test('a stopped controller can be started again', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);

      await controller.start();
      await controller.stop();
      expect(controller.isStarted, isFalse);

      await controller.start();
      expect(controller.isStarted, isTrue);
    });

    test('dispose stops the controller and closes both streams', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);

      await controller.start();
      await controller.dispose();

      expect(platform.stopped, isTrue);
      expect(controller.events, emitsDone);
      expect(controller.scans, emitsDone);
    });

    test('dispose twice is a no-op', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);

      await controller.dispose();
      await expectLater(controller.dispose(), completes);
    });

    test('start after dispose throws a StateError', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);

      await controller.dispose();

      expect(controller.start, throwsStateError);
    });
  });

  group('platform failures', () {
    test('a start failure is reported as a platform error', () async {
      final platform = FakeHardwareBarcodeScannerPlatform()
        ..startError = Exception('start failed');
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      await controller.start();
      await pumpEventQueue();

      final event = events.single;
      expect(event.type, HardwareScannerEventType.rejected);
      expect(event.reason, HardwareScannerEventReason.platformError);
      expect(event.source, HardwareScannerSource.androidBroadcast);
      expect(event.error, isA<Exception>());
      expect(
        controller.isStarted,
        isTrue,
        reason: 'keyboard input stays available when the native side fails',
      );
    });

    test('a missing native plugin reports platformUnavailable', () async {
      final platform = FakeHardwareBarcodeScannerPlatform()
        ..startError = MissingPluginException('no implementation');
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      await controller.start();
      await pumpEventQueue();

      final event = events.single;
      expect(event.type, HardwareScannerEventType.lifecycle);
      expect(event.reason, HardwareScannerEventReason.platformUnavailable);
    });

    test('keyboard input still works without the native plugin', () async {
      final platform = FakeHardwareBarcodeScannerPlatform()
        ..startError = MissingPluginException('no implementation');
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);

      await controller.start();
      final scanFuture = controller.scans.first;
      controller.handleTextInput('EV-KEYBOARD-ONLY\n');

      expect(await scanFuture.then((scan) => scan.value), 'EV-KEYBOARD-ONLY');
    });

    test('a stop failure is reported as a platform error', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      await controller.start();
      platform.stopError = Exception('stop failed');
      await controller.stop();
      await pumpEventQueue();

      expect(
        events
            .where(
              (event) => event.type == HardwareScannerEventType.rejected,
            )
            .single
            .reason,
        HardwareScannerEventReason.platformError,
      );
      expect(
        events.last.reason,
        HardwareScannerEventReason.stopped,
        reason: 'the controller still reports that it stopped',
      );
    });

    test('a missing plugin on stop is silent', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      await controller.start();
      platform.stopError = MissingPluginException('no implementation');
      await controller.stop();
      await pumpEventQueue();

      expect(
        events.where(
          (event) => event.type == HardwareScannerEventType.rejected,
        ),
        isEmpty,
      );
      expect(events.last.reason, HardwareScannerEventReason.stopped);
    });

    test('a broadcast stream error is reported, not thrown', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      await controller.start();
      platform.emitError(Exception('receiver died'));
      await pumpEventQueue();

      final event = events
          .where((event) => event.type == HardwareScannerEventType.rejected)
          .single;
      expect(event.reason, HardwareScannerEventReason.platformError);
      expect(event.source, HardwareScannerSource.androidBroadcast);
      expect(event.error, isA<Exception>());
    });

    test('a payload carrying an error never becomes a scan', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      final scans = <HardwareScanResult>[];
      controller.events.listen(events.add);
      controller.scans.listen(scans.add);

      await controller.start();
      platform.emit(<String, Object?>{
        'error': 'Unexpected native event: 42',
        'value': 'ABC-123',
      });
      await pumpEventQueue();

      expect(scans, isEmpty);
      final event = events
          .where((event) => event.type == HardwareScannerEventType.rejected)
          .single;
      expect(event.reason, HardwareScannerEventReason.platformError);
      expect(event.error, 'Unexpected native event: 42');
      expect(event.metadata['value'], 'ABC-123');
    });
  });

  group('filtering', () {
    test('unknown formats are rejected when opted out', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(
        platform: platform,
        options: HardwareScannerOptions(acceptUnknownFormat: false),
      );
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      final scans = <HardwareScanResult>[];
      controller.events.listen(events.add);
      controller.scans.listen(scans.add);

      await controller.start();
      controller.acceptRawScan(
        value: 'EV-NO-FORMAT',
        source: HardwareScannerSource.keyboard,
      );
      await pumpEventQueue();

      expect(scans, isEmpty);
      expect(
        events
            .where((event) => event.type == HardwareScannerEventType.ignored)
            .single
            .reason,
        HardwareScannerEventReason.unsupportedFormat,
      );
    });

    test('a known supported format still passes when opted out', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(
        platform: platform,
        options: HardwareScannerOptions(acceptUnknownFormat: false),
      );
      addTearDown(controller.dispose);

      await controller.start();
      final scanFuture = controller.scans.first;
      controller.acceptRawScan(
        value: 'ABC-123',
        source: HardwareScannerSource.androidBroadcast,
        rawFormat: 'CODE_128',
      );

      expect(await scanFuture.then((scan) => scan.format),
          HardwareScannerFormat.code128);
    });

    test('whitespace-only values are ignored as empty payloads', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      await controller.start();
      controller.acceptRawScan(
        value: '   ',
        source: HardwareScannerSource.keyboard,
      );
      controller.acceptRawScan(
        value: null,
        source: HardwareScannerSource.keyboard,
      );
      await pumpEventQueue();

      expect(
        events.where(
          (event) => event.reason == HardwareScannerEventReason.emptyPayload,
        ),
        hasLength(2),
      );
    });

    test('accepted values are trimmed and carry their raw format', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);

      await controller.start();
      final scanFuture = controller.scans.first;
      controller.acceptRawScan(
        value: '  ABC-123  ',
        source: HardwareScannerSource.androidBroadcast,
        rawFormat: 'CODE_128',
        metadata: const <String, Object?>{'preset': 'chainway'},
      );

      final scan = await scanFuture;
      expect(scan.value, 'ABC-123');
      expect(scan.rawFormat, 'CODE_128');
      expect(scan.format, HardwareScannerFormat.code128);
      expect(scan.hasKnownFormat, isTrue);
      expect(scan.metadata['preset'], 'chainway');
    });

    test('an accepted event carries the same result as the scan', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);

      await controller.start();
      final scanFuture = controller.scans.first;
      final eventFuture = controller.events.firstWhere(
        (event) => event.isAccepted,
      );
      controller.acceptRawScan(
        value: 'ABC-123',
        source: HardwareScannerSource.keyboard,
      );

      final event = await eventFuture;
      expect(event.result, same(await scanFuture));
      expect(event.reason, HardwareScannerEventReason.accepted);
    });
  });

  group('key events', () {
    test('key events are ignored before start', () {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);

      expect(
        controller.handleKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            character: 'a',
            timeStamp: Duration.zero,
          ),
        ),
        isNull,
      );
    });

    test('key-up events are ignored', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);

      await controller.start();

      expect(
        controller.handleKeyEvent(
          const KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
          ),
        ),
        isNull,
      );
    });

    test('a key without a character is ignored', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);

      await controller.start();

      expect(
        controller.handleKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.shiftLeft,
            logicalKey: LogicalKeyboardKey.shiftLeft,
            timeStamp: Duration.zero,
          ),
        ),
        isNull,
      );
    });

    test('both enter keys submit the buffered value', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);

      await controller.start();

      expect(
        controller.characterForKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.numpadEnter,
            logicalKey: LogicalKeyboardKey.numpadEnter,
            timeStamp: Duration.zero,
          ),
        ),
        '\n',
      );
      expect(
        controller.characterForKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.enter,
            logicalKey: LogicalKeyboardKey.enter,
            timeStamp: Duration.zero,
          ),
        ),
        '\n',
      );
    });

    test('empty text input is ignored', () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];

      await controller.start();
      controller.events.listen(events.add);
      controller.handleTextInput('');
      await pumpEventQueue();

      expect(events, isEmpty);
    });

    group('preferPhysicalKeyboardInput', () {
      late HardwareScannerController controller;

      setUp(() async {
        controller = HardwareScannerController(
          platform: FakeHardwareBarcodeScannerPlatform(),
          options: HardwareScannerOptions(preferPhysicalKeyboardInput: true),
        );
        addTearDown(controller.dispose);
        await controller.start();
      });

      String? characterFor(
        PhysicalKeyboardKey key,
        LogicalKeyboardKey logicalKey, {
        String? character,
        bool isShiftPressed = false,
      }) {
        return controller.characterForKeyEvent(
          KeyDownEvent(
            physicalKey: key,
            logicalKey: logicalKey,
            character: character,
            timeStamp: Duration.zero,
          ),
          isShiftPressed: isShiftPressed,
        );
      }

      test('maps unshifted physical keys to US-layout characters', () {
        expect(
          characterFor(
            PhysicalKeyboardKey.keyA,
            LogicalKeyboardKey.keyA,
            character: 'ש',
          ),
          'a',
        );
        expect(
          characterFor(
            PhysicalKeyboardKey.digit4,
            LogicalKeyboardKey.digit4,
            character: '4',
          ),
          '4',
        );
        expect(
          characterFor(
            PhysicalKeyboardKey.numpad7,
            LogicalKeyboardKey.numpad7,
          ),
          '7',
        );
      });

      test('maps shifted physical keys to their shifted characters', () {
        expect(
          characterFor(
            PhysicalKeyboardKey.keyA,
            LogicalKeyboardKey.keyA,
            character: 'ש',
            isShiftPressed: true,
          ),
          'A',
        );
        expect(
          characterFor(
            PhysicalKeyboardKey.digit4,
            LogicalKeyboardKey.digit4,
            character: '4',
            isShiftPressed: true,
          ),
          r'$',
        );
      });

      test('shifted keys with no shifted mapping fall back to unshifted', () {
        expect(
          characterFor(
            PhysicalKeyboardKey.numpadAdd,
            LogicalKeyboardKey.numpadAdd,
            isShiftPressed: true,
          ),
          '+',
        );
      });

      test('unmapped physical keys fall back to the reported character', () {
        expect(
          characterFor(
            PhysicalKeyboardKey.f1,
            LogicalKeyboardKey.f1,
            character: '§',
          ),
          '§',
        );
      });
    });
  });

  group('showLogs', () {
    test('is silent by default', () async {
      final logs = <String?>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      addTearDown(() => debugPrint = originalDebugPrint);

      final controller = HardwareScannerController(
        platform: FakeHardwareBarcodeScannerPlatform(),
      );
      addTearDown(controller.dispose);

      await controller.start();
      controller.acceptRawScan(
        value: 'EV-SECRET',
        source: HardwareScannerSource.keyboard,
      );
      await pumpEventQueue();

      expect(logs, isEmpty);
    });

    test('prints diagnostic events when explicitly enabled', () async {
      final logs = <String?>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => logs.add(message);
      addTearDown(() => debugPrint = originalDebugPrint);

      final controller = HardwareScannerController(
        platform: FakeHardwareBarcodeScannerPlatform(),
        options: HardwareScannerOptions(showLogs: true),
      );
      addTearDown(controller.dispose);

      await controller.start();
      await pumpEventQueue();

      expect(logs, isNotEmpty);
      expect(logs.first, contains('[HardwareBarcodeScanner]'));
    });
  });

  group('default platform', () {
    test('falls back to the method-channel implementation', () async {
      final controller = HardwareScannerController();
      addTearDown(controller.dispose);
      final events = <HardwareScannerEvent>[];
      controller.events.listen(events.add);

      await controller.start();
      await pumpEventQueue();

      expect(controller.isStarted, isTrue);
      expect(
        events.map((event) => event.reason),
        contains(HardwareScannerEventReason.platformUnavailable),
        reason: 'no native plugin is registered under flutter test',
      );
    });
  });
}
