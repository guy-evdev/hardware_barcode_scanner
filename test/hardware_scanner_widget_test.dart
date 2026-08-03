import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';

import 'support/fake_scanner_platform.dart';

/// Input capture, focus, and reconfiguration behaviour of the widget.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Builds a controller with a short idle timeout and registers its teardown.
  HardwareScannerController buildController({
    HardwareScannerOptions? options,
    List<HardwareScanResult>? scans,
  }) {
    final controller = HardwareScannerController(
      platform: FakeHardwareBarcodeScannerPlatform(),
      options: options ??
          HardwareScannerOptions(
            keyboardIdleTimeout: const Duration(milliseconds: 10),
          ),
    );
    if (scans != null) {
      controller.scans.listen(scans.add);
    }
    addTearDown(controller.dispose);
    return controller;
  }

  Widget wrap(Widget child) {
    return Directionality(textDirection: TextDirection.ltr, child: child);
  }

  /// Sends one hardware key press through the global keyboard pipeline.
  Future<void> pressKey(
    WidgetTester tester,
    LogicalKeyboardKey logicalKey, {
    required PhysicalKeyboardKey physicalKey,
    String? character,
  }) async {
    await tester.sendKeyDownEvent(
      logicalKey,
      character: character,
      physicalKey: physicalKey,
    );
    await tester.sendKeyUpEvent(logicalKey, physicalKey: physicalKey);
  }

  Future<void> pressEnter(WidgetTester tester) {
    return pressKey(
      tester,
      LogicalKeyboardKey.enter,
      physicalKey: PhysicalKeyboardKey.enter,
    );
  }

  Future<void> settleTimers(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Lets a pending [HardwareScannerController.stop] finish.
  ///
  /// `stop` awaits the cancellation of a broadcast-stream subscription, and
  /// that future only completes under real async — `pump` alone leaves it
  /// pending no matter how far the fake clock is advanced.
  Future<void> settleControllerStop(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  String hiddenText(WidgetTester tester) {
    return tester
        .widget<EditableText>(find.byType(EditableText))
        .controller
        .text;
  }

  group('hardware key fallback', () {
    testWidgets('buffers keys and submits them after the idle timeout', (
      tester,
    ) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(scans: scans);

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      await pressKey(
        tester,
        LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
        character: 'a',
      );
      await pressKey(
        tester,
        LogicalKeyboardKey.keyB,
        physicalKey: PhysicalKeyboardKey.keyB,
        character: 'b',
      );
      expect(scans, isEmpty, reason: 'the fallback buffer has not flushed yet');

      await settleTimers(tester);

      expect(scans.single.value, 'ab');
      expect(scans.single.source, HardwareScannerSource.keyboard);
    });

    testWidgets('a delimiter key submits the buffer immediately', (
      tester,
    ) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(seconds: 30),
        ),
        scans: scans,
      );

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      await pressKey(
        tester,
        LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
        character: 'a',
      );
      await pressEnter(tester);
      await tester.pump();

      expect(scans.single.value, 'a');
    });

    testWidgets('an enter key submits text already in the hidden field', (
      tester,
    ) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(seconds: 30),
        ),
        scans: scans,
      );

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'EV-12345');
      await pressEnter(tester);
      await tester.pump();

      expect(scans.single.value, 'EV-12345');
    });

    testWidgets('a submit action from the platform closes the scan', (
      tester,
    ) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(seconds: 30),
        ),
        scans: scans,
      );

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'EV-SUBMITTED');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(scans.single.value, 'EV-SUBMITTED');
    });
  });

  group('hidden field housekeeping', () {
    testWidgets('an accepted scan clears the hidden field', (tester) async {
      final controller = buildController();

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'EV-ACCEPTED');
      await settleTimers(tester);

      expect(hiddenText(tester), isEmpty);
    });

    testWidgets('a rejected scan also clears the hidden field', (tester) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(milliseconds: 10),
          validCharacterPattern: RegExp(r'^\d+$'),
        ),
        scans: scans,
      );

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'NOT-A-NUMBER');
      await settleTimers(tester);

      expect(scans, isEmpty);
      expect(
        hiddenText(tester),
        isEmpty,
        reason: 'a rejected value must not leak into the next scan',
      );
    });

    testWidgets('a duplicate scan clears the hidden field', (tester) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(milliseconds: 10),
          duplicateSuppressionWindow: const Duration(seconds: 30),
        ),
        scans: scans,
      );

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'EV-DUP');
      await settleTimers(tester);
      await tester.enterText(find.byType(EditableText), 'EV-DUP');
      await settleTimers(tester);

      expect(scans, hasLength(1));
      expect(hiddenText(tester), isEmpty);
    });
  });

  group('preferPhysicalKeyboardInput', () {
    testWidgets('reads physical keys and discards hidden platform text', (
      tester,
    ) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(
        options: HardwareScannerOptions(
          keyboardIdleTimeout: const Duration(seconds: 30),
          preferPhysicalKeyboardInput: true,
        ),
        scans: scans,
      );

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      // The platform reports the value under a non-US layout; it is dropped in
      // favour of the physical keys below.
      await tester.enterText(find.byType(EditableText), 'שק');
      await tester.pump();
      expect(hiddenText(tester), isEmpty);

      await pressKey(
        tester,
        LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
        character: 'ש',
      );
      await pressKey(
        tester,
        LogicalKeyboardKey.digit1,
        physicalKey: PhysicalKeyboardKey.digit1,
        character: '1',
      );
      await pressEnter(tester);
      await tester.pump();

      expect(scans.single.value, 'a1');
    });
  });

  group('focus', () {
    testWidgets('keys are ignored while another node holds focus', (
      tester,
    ) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(scans: scans);
      final scannerFocusNode = FocusNode();
      final otherFocusNode = FocusNode();
      addTearDown(() {
        scannerFocusNode.dispose();
        otherFocusNode.dispose();
      });

      await tester.pumpWidget(
        wrap(
          Column(
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

      await pressKey(
        tester,
        LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
        character: 'a',
      );
      await settleTimers(tester);

      expect(scans, isEmpty);
    });

    testWidgets('resume restores focus to the scanner', (tester) async {
      final controller = buildController();
      final otherFocusNode = FocusNode();
      addTearDown(otherFocusNode.dispose);

      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              HardwareScannerWidget(controller: controller),
              Focus(focusNode: otherFocusNode, child: const SizedBox()),
            ],
          ),
        ),
      );
      await tester.pump();

      otherFocusNode.requestFocus();
      await tester.pump();
      expect(otherFocusNode.hasFocus, isTrue);

      controller
        ..pause()
        ..resume();
      await tester.pump();
      await tester.pump();

      expect(otherFocusNode.hasFocus, isFalse);
    });
  });

  group('reconfiguration', () {
    testWidgets('a replaced focus node keeps input working', (tester) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(scans: scans);
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(() {
        first.dispose();
        second.dispose();
      });

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller, focusNode: first)),
      );
      await tester.pump();

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller, focusNode: second)),
      );
      await tester.pump();

      expect(second.hasFocus, isTrue);

      await pressKey(
        tester,
        LogicalKeyboardKey.keyZ,
        physicalKey: PhysicalKeyboardKey.keyZ,
        character: 'z',
      );
      await settleTimers(tester);

      expect(scans.single.value, 'z');
    });

    testWidgets('an owned focus node is replaced by a supplied one', (
      tester,
    ) async {
      final controller = buildController();
      final supplied = FocusNode();
      addTearDown(supplied.dispose);

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      await tester.pumpWidget(
        wrap(
          HardwareScannerWidget(controller: controller, focusNode: supplied),
        ),
      );
      await tester.pump();

      expect(supplied.hasFocus, isTrue);
    });

    testWidgets('a replaced controller receives subsequent input', (
      tester,
    ) async {
      final firstScans = <HardwareScanResult>[];
      final secondScans = <HardwareScanResult>[];
      final first = buildController(scans: firstScans);
      final second = buildController(scans: secondScans);

      await tester.pumpWidget(
        wrap(
          HardwareScannerWidget(controller: first, stopOnDispose: true),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        wrap(
          HardwareScannerWidget(controller: second, stopOnDispose: true),
        ),
      );
      await settleControllerStop(tester);

      expect(first.isStarted, isFalse);
      expect(second.isStarted, isTrue);

      await pressKey(
        tester,
        LogicalKeyboardKey.keyQ,
        physicalKey: PhysicalKeyboardKey.keyQ,
        character: 'q',
      );
      await settleTimers(tester);

      expect(firstScans, isEmpty);
      expect(secondScans.single.value, 'q');
    });

    testWidgets('enabling lifecycle focus restores focus on resume', (
      tester,
    ) async {
      final controller = buildController();
      final otherFocusNode = FocusNode();
      addTearDown(otherFocusNode.dispose);

      Widget build({required bool requestFocusOnLifecycleEvents}) {
        return wrap(
          Column(
            children: [
              HardwareScannerWidget(
                controller: controller,
                requestFocusOnLifecycleEvents: requestFocusOnLifecycleEvents,
              ),
              Focus(focusNode: otherFocusNode, child: const SizedBox()),
            ],
          ),
        );
      }

      await tester.pumpWidget(build(requestFocusOnLifecycleEvents: false));
      await tester.pump();
      otherFocusNode.requestFocus();
      await tester.pump();

      await tester.pumpWidget(build(requestFocusOnLifecycleEvents: true));
      await tester.pump();
      await tester.pump();

      expect(otherFocusNode.hasFocus, isFalse);
    });

    testWidgets('disabling hardware capture detaches the global handler', (
      tester,
    ) async {
      final scans = <HardwareScanResult>[];
      final controller = buildController(scans: scans);

      Widget build({required bool captureHardwareKeyboard}) {
        return wrap(
          HardwareScannerWidget(
            controller: controller,
            captureHardwareKeyboard: captureHardwareKeyboard,
          ),
        );
      }

      await tester.pumpWidget(build(captureHardwareKeyboard: true));
      await tester.pump();

      await tester.pumpWidget(build(captureHardwareKeyboard: false));
      await tester.pump();

      await pressKey(
        tester,
        LogicalKeyboardKey.keyA,
        physicalKey: PhysicalKeyboardKey.keyA,
        character: 'a',
      );
      await settleTimers(tester);

      expect(scans, isEmpty);

      await tester.pumpWidget(build(captureHardwareKeyboard: true));
      await tester.pump();

      await pressKey(
        tester,
        LogicalKeyboardKey.keyB,
        physicalKey: PhysicalKeyboardKey.keyB,
        character: 'b',
      );
      await settleTimers(tester);

      expect(scans.single.value, 'b');
    });
  });

  group('start and stop wiring', () {
    testWidgets('the controller starts with the widget by default', (
      tester,
    ) async {
      final controller = buildController();

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();

      expect(controller.isStarted, isTrue);
    });

    testWidgets('startOnInit false leaves the controller stopped', (
      tester,
    ) async {
      final controller = buildController();

      await tester.pumpWidget(
        wrap(
          HardwareScannerWidget(controller: controller, startOnInit: false),
        ),
      );
      await tester.pump();

      expect(controller.isStarted, isFalse);
    });

    testWidgets('a shared controller survives disposal by default', (
      tester,
    ) async {
      final controller = buildController();

      await tester.pumpWidget(
        wrap(HardwareScannerWidget(controller: controller)),
      );
      await tester.pump();
      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.pump();

      expect(controller.isStarted, isTrue);
    });

    testWidgets('stopOnDispose stops the controller with the widget', (
      tester,
    ) async {
      final controller = buildController();

      await tester.pumpWidget(
        wrap(
          HardwareScannerWidget(controller: controller, stopOnDispose: true),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(wrap(const SizedBox()));
      await settleControllerStop(tester);

      expect(controller.isStarted, isFalse);
    });
  });

  group('child rendering', () {
    testWidgets('the child is displayed with the hidden field', (tester) async {
      final controller = buildController();

      await tester.pumpWidget(
        wrap(
          HardwareScannerWidget(
            controller: controller,
            child: const Text('scan a badge'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('scan a badge'), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('captureTextInput false renders no hidden field', (
      tester,
    ) async {
      final controller = buildController();

      await tester.pumpWidget(
        wrap(
          HardwareScannerWidget(
            controller: controller,
            captureTextInput: false,
            child: const Text('scan a badge'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('scan a badge'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(KeyboardListener), findsOneWidget);
    });
  });
}
