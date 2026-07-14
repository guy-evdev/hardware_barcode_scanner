/// Method-channel implementation of the hardware scanner platform contract.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hardware_barcode_scanner_platform_interface.dart';
import 'src/hardware_scanner_models.dart';

/// Default scanner platform implementation backed by Flutter channels.
class MethodChannelHardwareBarcodeScanner
    extends HardwareBarcodeScannerPlatform {
  /// Channel used to start and stop the native scanner integration.
  @visibleForTesting
  final methodChannel = const MethodChannel('hardware_barcode_scanner/methods');

  /// Channel that delivers native scanner broadcasts.
  @visibleForTesting
  final eventChannel = const EventChannel('hardware_barcode_scanner/events');

  Stream<Map<String, Object?>>? _broadcastScans;

  /// Native broadcast scan events converted to string-keyed maps.
  @override
  Stream<Map<String, Object?>> get broadcastScans {
    return _broadcastScans ??= eventChannel.receiveBroadcastStream().map((
      dynamic event,
    ) {
      if (event is Map) {
        return event.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, Object?>{'error': 'Unexpected native event: $event'};
    });
  }

  /// Starts the native Android receiver with the supplied [presets].
  @override
  Future<void> startAndroidBroadcasts({
    required List<AndroidScannerBroadcastPreset> presets,
    bool configureChainwayBroadcastOutput = true,
    bool showLogs = false,
  }) async {
    await methodChannel.invokeMethod<void>('startBroadcasts', <String, Object?>{
      'presets': presets.map((preset) => preset.toMap()).toList(),
      'configureChainwayBroadcastOutput': configureChainwayBroadcastOutput,
      'showLogs': showLogs,
    });
  }

  /// Stops the native Android broadcast receiver.
  @override
  Future<void> stopAndroidBroadcasts() async {
    await methodChannel.invokeMethod<void>('stopBroadcasts');
  }
}
