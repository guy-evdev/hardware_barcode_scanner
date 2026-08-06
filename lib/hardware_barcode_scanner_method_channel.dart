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
  /// Creates the default platform implementation.
  ///
  /// [HardwareBarcodeScannerPlatform.instance] already holds one of these, so
  /// applications rarely need to construct it themselves.
  ///
  /// [isWeb] exists only so tests can exercise the web path; `kIsWeb` is a
  /// compile-time constant that a VM test can never make true.
  MethodChannelHardwareBarcodeScanner({@visibleForTesting bool? isWeb})
      : _isWeb = isWeb ?? kIsWeb;

  /// Whether this implementation is running under the web embedder.
  final bool _isWeb;

  /// Channel used to start and stop the native scanner integration.
  @visibleForTesting
  final methodChannel = const MethodChannel('hardware_barcode_scanner/methods');

  /// Channel that delivers native scanner broadcasts.
  @visibleForTesting
  final eventChannel = const EventChannel('hardware_barcode_scanner/events');

  Stream<Map<String, Object?>>? _broadcastScans;

  /// Native broadcast scan events converted to string-keyed maps.
  ///
  /// Always empty on the web, where there is no native receiver to listen to.
  @override
  Stream<Map<String, Object?>> get broadcastScans {
    if (_isWeb) return const Stream<Map<String, Object?>>.empty();

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
  ///
  /// Throws [MissingPluginException] on the web, which
  /// [HardwareScannerController] reports as `platformUnavailable`.
  @override
  Future<void> startAndroidBroadcasts({
    required List<AndroidScannerBroadcastPreset> presets,
    bool configureChainwayBroadcastOutput = true,
    bool showLogs = false,
  }) async {
    _throwIfWeb('startBroadcasts');

    await methodChannel.invokeMethod<void>('startBroadcasts', <String, Object?>{
      'presets': presets.map((preset) => preset.toMap()).toList(),
      'configureChainwayBroadcastOutput': configureChainwayBroadcastOutput,
      'showLogs': showLogs,
    });
  }

  /// Stops the native Android broadcast receiver.
  ///
  /// Throws [MissingPluginException] on the web, which
  /// [HardwareScannerController] swallows.
  @override
  Future<void> stopAndroidBroadcasts() async {
    _throwIfWeb('stopBroadcasts');

    await methodChannel.invokeMethod<void>('stopBroadcasts');
  }

  /// Refuses to touch the method channel on the web.
  ///
  /// The channel has no web implementation, and an unimplemented channel on the
  /// web does not answer with `notImplemented` the way every other platform
  /// does. The message lands in a one-message buffer and the returned future
  /// **never completes** — see https://github.com/flutter/flutter/issues/52780.
  /// A caller awaiting `start()` would therefore hang forever rather than
  /// receive the [MissingPluginException] it is written to expect. Throwing it
  /// here keeps the documented contract on a platform that cannot deliver it.
  void _throwIfWeb(String method) {
    if (!_isWeb) return;

    throw MissingPluginException(
      'hardware_barcode_scanner has no web implementation, so $method is '
      'unavailable. Keyboard (HID) scanning still works on the web; only '
      'Android scanner broadcasts require the native plugin.',
    );
  }
}
