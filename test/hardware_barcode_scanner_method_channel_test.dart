import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelHardwareBarcodeScanner();
  const channel = MethodChannel('hardware_barcode_scanner/methods');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      calls.add(methodCall);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('startAndroidBroadcasts forwards presets to native code', () async {
    await platform.startAndroidBroadcasts(
      presets: [AndroidScannerBroadcastPreset.chainway],
    );

    expect(calls.single.method, 'startBroadcasts');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    final presets = arguments['presets']! as List<Object?>;
    final preset = presets.single! as Map<Object?, Object?>;
    expect(preset['name'], 'chainway');
    expect(preset['actions'], contains('com.scanner.broadcast'));
    expect(arguments['configureChainwayBroadcastOutput'], isTrue);
    expect(arguments['showLogs'], isFalse);
  });

  test('stopAndroidBroadcasts calls native stop', () async {
    await platform.stopAndroidBroadcasts();

    expect(calls.single.method, 'stopBroadcasts');
  });

  test('startAndroidBroadcasts forwards the optional flags', () async {
    await platform.startAndroidBroadcasts(
      presets: [AndroidScannerBroadcastPreset.zebraDataWedge],
      configureChainwayBroadcastOutput: false,
      showLogs: true,
    );

    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments['configureChainwayBroadcastOutput'], isFalse);
    expect(arguments['showLogs'], isTrue);
  });

  group('broadcastScans', () {
    const eventChannel = EventChannel('hardware_barcode_scanner/events');
    late List<Object?> nativeEvents;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            for (final event in nativeEvents) {
              sink.success(event);
            }
            sink.endOfStream();
          },
        ),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('converts native maps to string-keyed maps', () async {
      nativeEvents = <Object?>[
        <Object?, Object?>{
          'value': 'ABC-123',
          'format': 'CODE_128',
          'preset': 'chainway',
        },
      ];

      final scans =
          await MethodChannelHardwareBarcodeScanner().broadcastScans.toList();

      expect(scans.single, <String, Object?>{
        'value': 'ABC-123',
        'format': 'CODE_128',
        'preset': 'chainway',
      });
    });

    test('reports a non-map native event as an error payload', () async {
      nativeEvents = <Object?>[42];

      final scans =
          await MethodChannelHardwareBarcodeScanner().broadcastScans.toList();

      expect(scans.single['error'], 'Unexpected native event: 42');
    });

    test('the stream is created once and reused', () {
      final instance = MethodChannelHardwareBarcodeScanner();
      nativeEvents = <Object?>[];

      expect(instance.broadcastScans, same(instance.broadcastScans));
    });
  });
}
