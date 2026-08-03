import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner_method_channel.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner_platform_interface.dart';

/// A platform implementation that overrides nothing but the required getter.
class _UnimplementedPlatform extends HardwareBarcodeScannerPlatform {
  @override
  Stream<Map<String, Object?>> get broadcastScans =>
      const Stream<Map<String, Object?>>.empty();
}

/// A platform implementation that does not extend the base class.
class _UntokenedPlatform implements HardwareBarcodeScannerPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final defaultInstance = HardwareBarcodeScannerPlatform.instance;
  tearDown(() {
    HardwareBarcodeScannerPlatform.instance = defaultInstance;
  });

  test('the default instance is the method-channel implementation', () {
    expect(
      HardwareBarcodeScannerPlatform.instance,
      isA<MethodChannelHardwareBarcodeScanner>(),
    );
  });

  test('a verified implementation can replace the default instance', () {
    final replacement = _UnimplementedPlatform();

    HardwareBarcodeScannerPlatform.instance = replacement;

    expect(HardwareBarcodeScannerPlatform.instance, same(replacement));
  });

  test('an implementation without the token is rejected', () {
    expect(
      () => HardwareBarcodeScannerPlatform.instance = _UntokenedPlatform(),
      throwsA(isA<AssertionError>()),
    );
  });

  test('startAndroidBroadcasts is unimplemented by default', () {
    expect(
      () => _UnimplementedPlatform().startAndroidBroadcasts(
        presets: const [],
      ),
      throwsUnimplementedError,
    );
  });

  test('stopAndroidBroadcasts is unimplemented by default', () {
    expect(
      _UnimplementedPlatform().stopAndroidBroadcasts,
      throwsUnimplementedError,
    );
  });
}
