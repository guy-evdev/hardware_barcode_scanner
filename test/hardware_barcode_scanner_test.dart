import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeHardwareBarcodeScannerPlatform
    with MockPlatformInterfaceMixin
    implements HardwareBarcodeScannerPlatform {
  final controller = StreamController<Map<String, Object?>>.broadcast();
  var started = false;
  var stopped = false;

  @override
  Stream<Map<String, Object?>> get broadcastScans => controller.stream;

  @override
  Future<void> startAndroidBroadcasts({
    required List<AndroidScannerBroadcastPreset> presets,
    bool configureChainwayBroadcastOutput = true,
    bool showLogs = false,
  }) async {
    started = true;
  }

  @override
  Future<void> stopAndroidBroadcasts() async {
    stopped = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default formats include the expected v1 formats', () {
    final options = HardwareScannerOptions();

    expect(options.supportedFormats, contains(HardwareScannerFormat.qrCode));
    expect(options.supportedFormats, contains(HardwareScannerFormat.code128));
    expect(options.supportedFormats, contains(HardwareScannerFormat.code39));
    expect(options.supportedFormats, contains(HardwareScannerFormat.code93));
    expect(options.supportedFormats, contains(HardwareScannerFormat.ean13));
    expect(options.supportedFormats, contains(HardwareScannerFormat.ean8));
    expect(options.supportedFormats, contains(HardwareScannerFormat.upcA));
    expect(options.supportedFormats, contains(HardwareScannerFormat.upcE));
    expect(options.supportedFormats, contains(HardwareScannerFormat.itf));
    expect(options.supportedFormats, contains(HardwareScannerFormat.pdf417));
    expect(
      options.supportedFormats,
      contains(HardwareScannerFormat.dataMatrix),
    );
    expect(options.supportedFormats, contains(HardwareScannerFormat.aztec));
    expect(
      options.supportedFormats,
      isNot(contains(HardwareScannerFormat.unknown)),
    );
  });

  test('unknown format is accepted by default', () async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(platform: platform);
    addTearDown(controller.dispose);

    await controller.start();
    final scanFuture = controller.scans.first;
    controller.acceptRawScan(
      value: 'EV-12345',
      source: HardwareScannerSource.keyboard,
    );

    final scan = await scanFuture;
    expect(scan.value, 'EV-12345');
    expect(scan.format, HardwareScannerFormat.unknown);
  });

  test('reported unsupported formats are ignored', () async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(
      platform: platform,
      options: HardwareScannerOptions(
        supportedFormats: {HardwareScannerFormat.qrCode},
      ),
    );
    addTearDown(controller.dispose);

    await controller.start();
    final eventFuture = controller.events.firstWhere(
      (event) => event.reason == HardwareScannerEventReason.unsupportedFormat,
    );
    controller.acceptRawScan(
      value: '1234567890123',
      source: HardwareScannerSource.androidBroadcast,
      rawFormat: 'EAN_13',
    );

    final event = await eventFuture;
    expect(event.type, HardwareScannerEventType.ignored);
  });

  test('valid character regex rejects invalid values', () async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(
      platform: platform,
      options: HardwareScannerOptions(validCharacterPattern: RegExp(r'^\d+$')),
    );
    addTearDown(controller.dispose);

    await controller.start();
    final eventFuture = controller.events.firstWhere(
      (event) => event.reason == HardwareScannerEventReason.invalidCharacters,
    );
    controller.acceptRawScan(
      value: 'EV-12345',
      source: HardwareScannerSource.keyboard,
    );

    final event = await eventFuture;
    expect(event.type, HardwareScannerEventType.ignored);
  });

  test('pause drops scans and resume accepts scans', () async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(platform: platform);
    addTearDown(controller.dispose);

    await controller.start();
    controller.pause();
    final ignoredFuture = controller.events.firstWhere(
      (event) => event.reason == HardwareScannerEventReason.paused,
    );
    controller.acceptRawScan(
      value: 'EV-PAUSED',
      source: HardwareScannerSource.keyboard,
    );
    expect((await ignoredFuture).type, HardwareScannerEventType.ignored);

    controller.resume();
    final scanFuture = controller.scans.first;
    controller.acceptRawScan(
      value: 'EV-RESUMED',
      source: HardwareScannerSource.keyboard,
    );
    expect((await scanFuture).value, 'EV-RESUMED');
  });

  test('duplicate suppression emits ignored duplicate event', () async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(platform: platform);
    addTearDown(controller.dispose);

    await controller.start();
    controller.acceptRawScan(
      value: 'EV-DUP',
      source: HardwareScannerSource.keyboard,
    );
    final duplicateFuture = controller.events.firstWhere(
      (event) => event.reason == HardwareScannerEventReason.duplicate,
    );
    controller.acceptRawScan(
      value: 'EV-DUP',
      source: HardwareScannerSource.keyboard,
    );

    expect((await duplicateFuture).type, HardwareScannerEventType.ignored);
  });

  test('native broadcast metadata is preserved', () async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(platform: platform);
    addTearDown(controller.dispose);

    await controller.start();
    final scanFuture = controller.scans.first;
    platform.controller.add(<String, Object?>{
      'value': 'ABC-123',
      'format': 'CODE_128',
      'action': 'com.scanner.broadcast',
      'preset': 'chainway',
    });

    final scan = await scanFuture;
    expect(scan.source, HardwareScannerSource.androidBroadcast);
    expect(scan.format, HardwareScannerFormat.code128);
    expect(scan.metadata['preset'], 'chainway');
  });

  test('hardware keyboard input preserves unicode by default', () async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(platform: platform);
    addTearDown(controller.dispose);

    await controller.start();
    final scanFuture = controller.scans.first;

    controller.handleTextInput('1836.35חגצהsvsk');
    controller.handleKeyEvent(
      KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
    );

    expect(await scanFuture.then((scan) => scan.value), '1836.35חגצהsvsk');
  });

  test(
    'text input replaces already dispatched hardware fallback prefix',
    () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(platform: platform);
      addTearDown(controller.dispose);

      await controller.start();
      final scanFuture = controller.scans.first;

      controller.handleTextInput('ic:20');
      controller.handleTextInput('ic:202893:1801600', replaceBuffer: true);
      controller.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),
      );

      expect(await scanFuture.then((scan) => scan.value), 'ic:202893:1801600');
    },
  );

  test('text input replaces cumulative scanner text state', () async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(platform: platform);
    addTearDown(controller.dispose);

    await controller.start();
    final scanFuture = controller.scans.first;

    controller.handleTextInput('ic', replaceBuffer: true);
    controller.handleTextInput('ic:202893:1801600', replaceBuffer: true);
    controller.handleKeyEvent(
      KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
    );

    expect(await scanFuture.then((scan) => scan.value), 'ic:202893:1801600');
  });

  test('text input preserves repeated equal scanner chunks', () async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(platform: platform);
    addTearDown(controller.dispose);

    await controller.start();
    final scanFuture = controller.scans.first;

    controller.handleTextInput('אבc:', replaceBuffer: true);
    controller.handleTextInput('אבc:אבc:', replaceBuffer: true);
    controller.handleKeyEvent(
      KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
    );

    expect(await scanFuture.then((scan) => scan.value), 'אבc:אבc:');
  });

  testWidgets('widget treats hidden text input as the current scan state', (
    tester,
  ) async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(
      platform: platform,
      options: HardwareScannerOptions(
        keyboardIdleTimeout: const Duration(milliseconds: 10),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: HardwareScannerWidget(controller: controller),
      ),
    );
    await tester.pump();

    final scanFuture = controller.scans.first;
    await tester.enterText(find.byType(EditableText), 'ic');
    await tester.enterText(find.byType(EditableText), 'ic:202893:1801600');
    await tester.pump(const Duration(milliseconds: 20));

    expect(await scanFuture.then((scan) => scan.value), 'ic:202893:1801600');
  });

  testWidgets(
    'widget ignores late hardware text once hidden text input is active',
    (tester) async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(
        platform: platform,
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(milliseconds: 10),
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HardwareScannerWidget(controller: controller),
        ),
      );
      await tester.pump();

      final scanFuture = controller.scans.first;
      await tester.enterText(find.byType(EditableText), 'אבc:אבc:');
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyC,
        character: 'c',
        physicalKey: PhysicalKeyboardKey.keyC,
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.keyC,
        physicalKey: PhysicalKeyboardKey.keyC,
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(await scanFuture.then((scan) => scan.value), 'אבc:אבc:');
    },
  );

  testWidgets('widget without hidden text input handles each key once', (
    tester,
  ) async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(platform: platform);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: HardwareScannerWidget(
          controller: controller,
          captureTextInput: false,
        ),
      ),
    );
    await tester.pump();

    final scanFuture = controller.scans.first;
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyA,
      character: 'a',
      physicalKey: PhysicalKeyboardKey.keyA,
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.keyA,
      physicalKey: PhysicalKeyboardKey.keyA,
    );
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
    );

    expect(await scanFuture.then((scan) => scan.value), 'a');
  });

  testWidgets('widget ignores global key events while it is unfocused', (
    tester,
  ) async {
    final platform = FakeHardwareBarcodeScannerPlatform();
    final controller = HardwareScannerController(
      platform: platform,
      options: HardwareScannerOptions(
        keyboardIdleTimeout: const Duration(milliseconds: 10),
      ),
    );
    final scannerFocusNode = FocusNode();
    final otherFocusNode = FocusNode();
    final scans = <HardwareScanResult>[];
    final subscription = controller.scans.listen(scans.add);
    addTearDown(() async {
      await subscription.cancel();
      scannerFocusNode.dispose();
      otherFocusNode.dispose();
      await controller.dispose();
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            HardwareScannerWidget(
              controller: controller,
              focusNode: scannerFocusNode,
            ),
            Focus(focusNode: otherFocusNode, child: const SizedBox()),
          ],
        ),
      ),
    );
    await tester.pump();
    otherFocusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyA,
      character: 'a',
      physicalKey: PhysicalKeyboardKey.keyA,
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.keyA,
      physicalKey: PhysicalKeyboardKey.keyA,
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(scans, isEmpty);
  });

  test(
    'physical keyboard mode uses physical period key for barcode value',
    () async {
      final platform = FakeHardwareBarcodeScannerPlatform();
      final controller = HardwareScannerController(
        platform: platform,
        options: HardwareScannerOptions(preferPhysicalKeyboardInput: true),
      );
      addTearDown(controller.dispose);

      await controller.start();
      final scanFuture = controller.scans.first;

      controller.handleTextInput('91432166293086010010-1');
      controller.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.period,
          logicalKey: LogicalKeyboardKey.period,
          character: 'ץ',
          timeStamp: Duration.zero,
        ),
      );
      controller.handleTextInput('2204603');
      controller.handleKeyEvent(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),
      );

      expect(
        await scanFuture.then((scan) => scan.value),
        '91432166293086010010-1.2204603',
      );
    },
  );
}
