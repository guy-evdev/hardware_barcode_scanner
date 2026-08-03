import 'dart:async';

import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// In-memory stand-in for the native Android scanner integration.
///
/// [emit] pushes a payload through the same path a real broadcast intent takes,
/// so tests can exercise the broadcast transport without a device.
class FakeHardwareBarcodeScannerPlatform
    with MockPlatformInterfaceMixin
    implements HardwareBarcodeScannerPlatform {
  /// Sink backing [broadcastScans].
  final controller = StreamController<Map<String, Object?>>.broadcast();

  /// Whether [startAndroidBroadcasts] has been called.
  var started = false;

  /// Whether [stopAndroidBroadcasts] has been called.
  var stopped = false;

  /// Presets passed to the most recent [startAndroidBroadcasts] call.
  List<AndroidScannerBroadcastPreset>? lastPresets;

  /// Error thrown by the next [startAndroidBroadcasts] call, when set.
  Object? startError;

  /// Error thrown by the next [stopAndroidBroadcasts] call, when set.
  Object? stopError;

  @override
  Stream<Map<String, Object?>> get broadcastScans => controller.stream;

  @override
  Future<void> startAndroidBroadcasts({
    required List<AndroidScannerBroadcastPreset> presets,
    bool configureChainwayBroadcastOutput = true,
    bool showLogs = false,
  }) async {
    lastPresets = presets;
    final error = startError;
    if (error != null) throw error;
    started = true;
  }

  @override
  Future<void> stopAndroidBroadcasts() async {
    final error = stopError;
    if (error != null) throw error;
    stopped = true;
  }

  /// Delivers a native broadcast payload to the controller.
  void emit(Map<String, Object?> payload) => controller.add(payload);

  /// Delivers a stream-level failure to the controller.
  void emitError(Object error) => controller.addError(error);

  /// Delivers a decoded barcode with an optional vendor format label.
  void emitScan(String value, {String? format}) {
    emit(<String, Object?>{
      'value': value,
      if (format != null) 'format': format,
      'preset': 'chainway',
    });
  }
}
