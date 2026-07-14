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
}
