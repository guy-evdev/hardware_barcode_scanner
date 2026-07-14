/// Platform contract for native hardware scanner integrations.
library;

import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hardware_barcode_scanner_method_channel.dart';
import 'src/hardware_scanner_models.dart';

/// Contract implemented by platform-specific scanner integrations.
abstract class HardwareBarcodeScannerPlatform extends PlatformInterface {
  /// Creates a platform implementation with token verification enabled.
  HardwareBarcodeScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static HardwareBarcodeScannerPlatform _instance =
      MethodChannelHardwareBarcodeScanner();

  /// The active platform implementation.
  static HardwareBarcodeScannerPlatform get instance => _instance;

  /// Replaces the active platform implementation.
  ///
  /// Implementations must extend this class or use
  /// `MockPlatformInterfaceMixin` in tests.
  static set instance(HardwareBarcodeScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Native scanner events received from Android broadcast intents.
  Stream<Map<String, Object?>> get broadcastScans;

  /// Registers Android broadcast actions from [presets].
  ///
  /// [configureChainwayBroadcastOutput] attempts to configure a compatible
  /// Chainway scanner service when its optional SDK is present. [showLogs]
  /// controls native Android diagnostic logging.
  Future<void> startAndroidBroadcasts({
    required List<AndroidScannerBroadcastPreset> presets,
    bool configureChainwayBroadcastOutput = true,
    bool showLogs = false,
  }) {
    throw UnimplementedError(
      'startAndroidBroadcasts() has not been implemented.',
    );
  }

  /// Unregisters Android scanner broadcasts and closes optional vendor output.
  Future<void> stopAndroidBroadcasts() {
    throw UnimplementedError(
      'stopAndroidBroadcasts() has not been implemented.',
    );
  }
}
