import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../hardware_barcode_scanner_platform_interface.dart';
import 'hardware_scanner_models.dart';

/// Coordinates keyboard and native Android scanner input.
///
/// Call [start] before accepting input and [dispose] when the controller is no
/// longer needed. Accepted scans are published through [scans], while [events]
/// includes lifecycle, filtering, and platform diagnostics.
class HardwareScannerController {
  /// Creates a scanner controller.
  ///
  /// The default platform implementation uses Flutter method and event
  /// channels. A custom [platform] is primarily useful for testing.
  HardwareScannerController({
    HardwareScannerOptions? options,
    HardwareBarcodeScannerPlatform? platform,
  })  : options = options ?? HardwareScannerOptions(),
        _platform = platform ?? HardwareBarcodeScannerPlatform.instance;

  /// The immutable reference to the options used by this controller.
  final HardwareScannerOptions options;
  final HardwareBarcodeScannerPlatform _platform;

  final _eventsController = StreamController<HardwareScannerEvent>.broadcast();
  final _scansController = StreamController<HardwareScanResult>.broadcast();

  StreamSubscription<Map<String, Object?>>? _platformSubscription;
  Timer? _keyboardIdleTimer;
  final StringBuffer _keyboardBuffer = StringBuffer();
  bool _isStarted = false;
  bool _isPaused = false;
  bool _isDisposed = false;
  String? _lastAcceptedValue;
  HardwareScannerFormat? _lastAcceptedFormat;
  DateTime? _lastAcceptedAt;

  static final _physicalKeyCharacters = <PhysicalKeyboardKey, String>{
    PhysicalKeyboardKey.keyA: 'a',
    PhysicalKeyboardKey.keyB: 'b',
    PhysicalKeyboardKey.keyC: 'c',
    PhysicalKeyboardKey.keyD: 'd',
    PhysicalKeyboardKey.keyE: 'e',
    PhysicalKeyboardKey.keyF: 'f',
    PhysicalKeyboardKey.keyG: 'g',
    PhysicalKeyboardKey.keyH: 'h',
    PhysicalKeyboardKey.keyI: 'i',
    PhysicalKeyboardKey.keyJ: 'j',
    PhysicalKeyboardKey.keyK: 'k',
    PhysicalKeyboardKey.keyL: 'l',
    PhysicalKeyboardKey.keyM: 'm',
    PhysicalKeyboardKey.keyN: 'n',
    PhysicalKeyboardKey.keyO: 'o',
    PhysicalKeyboardKey.keyP: 'p',
    PhysicalKeyboardKey.keyQ: 'q',
    PhysicalKeyboardKey.keyR: 'r',
    PhysicalKeyboardKey.keyS: 's',
    PhysicalKeyboardKey.keyT: 't',
    PhysicalKeyboardKey.keyU: 'u',
    PhysicalKeyboardKey.keyV: 'v',
    PhysicalKeyboardKey.keyW: 'w',
    PhysicalKeyboardKey.keyX: 'x',
    PhysicalKeyboardKey.keyY: 'y',
    PhysicalKeyboardKey.keyZ: 'z',
    PhysicalKeyboardKey.digit0: '0',
    PhysicalKeyboardKey.digit1: '1',
    PhysicalKeyboardKey.digit2: '2',
    PhysicalKeyboardKey.digit3: '3',
    PhysicalKeyboardKey.digit4: '4',
    PhysicalKeyboardKey.digit5: '5',
    PhysicalKeyboardKey.digit6: '6',
    PhysicalKeyboardKey.digit7: '7',
    PhysicalKeyboardKey.digit8: '8',
    PhysicalKeyboardKey.digit9: '9',
    PhysicalKeyboardKey.numpad0: '0',
    PhysicalKeyboardKey.numpad1: '1',
    PhysicalKeyboardKey.numpad2: '2',
    PhysicalKeyboardKey.numpad3: '3',
    PhysicalKeyboardKey.numpad4: '4',
    PhysicalKeyboardKey.numpad5: '5',
    PhysicalKeyboardKey.numpad6: '6',
    PhysicalKeyboardKey.numpad7: '7',
    PhysicalKeyboardKey.numpad8: '8',
    PhysicalKeyboardKey.numpad9: '9',
    PhysicalKeyboardKey.space: ' ',
    PhysicalKeyboardKey.minus: '-',
    PhysicalKeyboardKey.equal: '=',
    PhysicalKeyboardKey.bracketLeft: '[',
    PhysicalKeyboardKey.bracketRight: ']',
    PhysicalKeyboardKey.backslash: r'\',
    PhysicalKeyboardKey.semicolon: ';',
    PhysicalKeyboardKey.quote: "'",
    PhysicalKeyboardKey.backquote: '`',
    PhysicalKeyboardKey.comma: ',',
    PhysicalKeyboardKey.period: '.',
    PhysicalKeyboardKey.slash: '/',
    PhysicalKeyboardKey.numpadDecimal: '.',
    PhysicalKeyboardKey.numpadAdd: '+',
    PhysicalKeyboardKey.numpadSubtract: '-',
    PhysicalKeyboardKey.numpadMultiply: '*',
    PhysicalKeyboardKey.numpadDivide: '/',
  };

  static final _shiftedPhysicalKeyCharacters = <PhysicalKeyboardKey, String>{
    PhysicalKeyboardKey.keyA: 'A',
    PhysicalKeyboardKey.keyB: 'B',
    PhysicalKeyboardKey.keyC: 'C',
    PhysicalKeyboardKey.keyD: 'D',
    PhysicalKeyboardKey.keyE: 'E',
    PhysicalKeyboardKey.keyF: 'F',
    PhysicalKeyboardKey.keyG: 'G',
    PhysicalKeyboardKey.keyH: 'H',
    PhysicalKeyboardKey.keyI: 'I',
    PhysicalKeyboardKey.keyJ: 'J',
    PhysicalKeyboardKey.keyK: 'K',
    PhysicalKeyboardKey.keyL: 'L',
    PhysicalKeyboardKey.keyM: 'M',
    PhysicalKeyboardKey.keyN: 'N',
    PhysicalKeyboardKey.keyO: 'O',
    PhysicalKeyboardKey.keyP: 'P',
    PhysicalKeyboardKey.keyQ: 'Q',
    PhysicalKeyboardKey.keyR: 'R',
    PhysicalKeyboardKey.keyS: 'S',
    PhysicalKeyboardKey.keyT: 'T',
    PhysicalKeyboardKey.keyU: 'U',
    PhysicalKeyboardKey.keyV: 'V',
    PhysicalKeyboardKey.keyW: 'W',
    PhysicalKeyboardKey.keyX: 'X',
    PhysicalKeyboardKey.keyY: 'Y',
    PhysicalKeyboardKey.keyZ: 'Z',
    PhysicalKeyboardKey.digit0: ')',
    PhysicalKeyboardKey.digit1: '!',
    PhysicalKeyboardKey.digit2: '@',
    PhysicalKeyboardKey.digit3: '#',
    PhysicalKeyboardKey.digit4: r'$',
    PhysicalKeyboardKey.digit5: '%',
    PhysicalKeyboardKey.digit6: '^',
    PhysicalKeyboardKey.digit7: '&',
    PhysicalKeyboardKey.digit8: '*',
    PhysicalKeyboardKey.digit9: '(',
    PhysicalKeyboardKey.minus: '_',
    PhysicalKeyboardKey.equal: '+',
    PhysicalKeyboardKey.bracketLeft: '{',
    PhysicalKeyboardKey.bracketRight: '}',
    PhysicalKeyboardKey.backslash: '|',
    PhysicalKeyboardKey.semicolon: ':',
    PhysicalKeyboardKey.quote: '"',
    PhysicalKeyboardKey.backquote: '~',
    PhysicalKeyboardKey.comma: '<',
    PhysicalKeyboardKey.period: '>',
    PhysicalKeyboardKey.slash: '?',
  };

  /// Broadcasts lifecycle, filtering, accepted-scan, and error events.
  Stream<HardwareScannerEvent> get events => _eventsController.stream;

  /// Broadcasts scans that pass all configured filters.
  Stream<HardwareScanResult> get scans => _scansController.stream;

  /// Whether input candidates are currently ignored because the controller is
  /// paused.
  bool get isPaused => _isPaused;

  /// Whether the controller is listening for scanner input.
  bool get isStarted => _isStarted;

  /// Starts keyboard acceptance and native Android broadcast listening.
  ///
  /// Calling this method more than once without an intervening [stop] has no
  /// effect. On platforms without the native plugin, keyboard input remains
  /// available and a `platformUnavailable` event is emitted.
  Future<void> start() async {
    _assertNotDisposed();
    if (_isStarted) return;

    _isStarted = true;
    _platformSubscription = _platform.broadcastScans.listen(
      _handleNativeBroadcast,
      onError: (Object error) {
        _emit(
          HardwareScannerEvent(
            type: HardwareScannerEventType.rejected,
            reason: HardwareScannerEventReason.platformError,
            source: HardwareScannerSource.androidBroadcast,
            timestamp: DateTime.now(),
            error: error,
          ),
        );
      },
    );

    try {
      await _platform.startAndroidBroadcasts(
        presets: options.androidBroadcastPresets,
        configureChainwayBroadcastOutput:
            options.configureChainwayBroadcastOutput,
        showLogs: options.showLogs,
      );
      _emitLifecycle(HardwareScannerEventReason.started);
    } on MissingPluginException {
      _emit(
        HardwareScannerEvent(
          type: HardwareScannerEventType.lifecycle,
          reason: HardwareScannerEventReason.platformUnavailable,
          source: HardwareScannerSource.unknown,
          timestamp: DateTime.now(),
        ),
      );
    } on Object catch (error) {
      _emit(
        HardwareScannerEvent(
          type: HardwareScannerEventType.rejected,
          reason: HardwareScannerEventReason.platformError,
          source: HardwareScannerSource.androidBroadcast,
          timestamp: DateTime.now(),
          error: error,
        ),
      );
    }
  }

  /// Stops native listening and clears pending keyboard input.
  ///
  /// Calling this method while stopped has no effect. The controller can be
  /// started again until [dispose] is called.
  Future<void> stop() async {
    if (!_isStarted) return;

    _keyboardIdleTimer?.cancel();
    _keyboardBuffer.clear();
    await _platformSubscription?.cancel();
    _platformSubscription = null;

    try {
      await _platform.stopAndroidBroadcasts();
    } on MissingPluginException {
      // Keyboard-only platforms are expected to have no native receiver.
    } on Object catch (error) {
      _emit(
        HardwareScannerEvent(
          type: HardwareScannerEventType.rejected,
          reason: HardwareScannerEventReason.platformError,
          source: HardwareScannerSource.androidBroadcast,
          timestamp: DateTime.now(),
          error: error,
        ),
      );
    }

    _isStarted = false;
    _emitLifecycle(HardwareScannerEventReason.stopped);
  }

  /// Pauses candidate acceptance and clears pending keyboard input.
  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    _keyboardIdleTimer?.cancel();
    _keyboardBuffer.clear();
    _emitLifecycle(HardwareScannerEventReason.paused);
  }

  /// Resumes candidate acceptance after [pause].
  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    _emitLifecycle(HardwareScannerEventReason.resumed);
  }

  /// Processes one Flutter hardware-key event.
  ///
  /// Returns the decoded character when the event was handled, or `null` for
  /// non-key-down and unsupported events. [isShiftPressed] can override the
  /// global keyboard state in tests or custom integrations.
  String? handleKeyEvent(KeyEvent event, {bool? isShiftPressed}) {
    if (!_isStarted || event is! KeyDownEvent) return null;
    final character = characterForKeyEvent(
      event,
      isShiftPressed: isShiftPressed,
    );
    if (character == null || character.isEmpty) return null;

    handleTextInput(character);
    return character;
  }

  /// Adds committed keyboard [text] to the current scan candidate.
  ///
  /// Delimiter characters immediately submit the buffered candidate. Otherwise
  /// it is submitted after [HardwareScannerOptions.keyboardIdleTimeout]. Set
  /// [replaceBuffer] when [text] represents the complete current value of an
  /// editable control rather than a newly appended fragment.
  void handleTextInput(String text, {bool replaceBuffer = false}) {
    if (!_isStarted || text.isEmpty) return;

    if (replaceBuffer) {
      _keyboardBuffer.clear();
      _keyboardIdleTimer?.cancel();
    }

    _emit(
      HardwareScannerEvent(
        type: HardwareScannerEventType.lifecycle,
        reason: HardwareScannerEventReason.keyboardInputReceived,
        source: HardwareScannerSource.keyboard,
        timestamp: DateTime.now(),
        rawValue: text,
      ),
    );

    for (final codePoint in text.runes) {
      final character = String.fromCharCode(codePoint);
      if (options.keyboardDelimiters.contains(character)) {
        _flushKeyboardBuffer();
      } else {
        _keyboardBuffer.write(character);
      }
    }

    _keyboardIdleTimer?.cancel();
    _keyboardIdleTimer = null;
    if (_keyboardBuffer.isEmpty) return;
    _keyboardIdleTimer = Timer(
      options.keyboardIdleTimeout,
      _flushKeyboardBuffer,
    );
  }

  /// Stops input and permanently closes [events] and [scans].
  Future<void> dispose() async {
    if (_isDisposed) return;
    await stop();
    _isDisposed = true;
    await _eventsController.close();
    await _scansController.close();
  }

  /// Converts a Flutter key event to scanner text without buffering it.
  ///
  /// When [HardwareScannerOptions.preferPhysicalKeyboardInput] is enabled,
  /// supported physical keys use a US keyboard mapping. Other keys fall back to
  /// [KeyEvent.character].
  String? characterForKeyEvent(KeyEvent event, {bool? isShiftPressed}) {
    final physicalKey = event.physicalKey;
    if (physicalKey == PhysicalKeyboardKey.enter ||
        physicalKey == PhysicalKeyboardKey.numpadEnter) {
      return '\n';
    }

    if (options.preferPhysicalKeyboardInput) {
      if (isShiftPressed ?? HardwareKeyboard.instance.isShiftPressed) {
        final shiftedCharacter = _shiftedPhysicalKeyCharacters[physicalKey];
        if (shiftedCharacter != null) return shiftedCharacter;
      }

      final physicalCharacter = _physicalKeyCharacters[physicalKey];
      if (physicalCharacter != null) return physicalCharacter;
    }

    return event.character;
  }

  /// Injects a raw candidate directly into the filtering pipeline.
  ///
  /// This method is exposed for package and consumer tests. Production input
  /// should normally use [handleTextInput] or the configured native platform.
  @visibleForTesting
  void acceptRawScan({
    required String? value,
    required HardwareScannerSource source,
    String? rawFormat,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    _acceptCandidate(
      value: value,
      source: source,
      rawFormat: rawFormat,
      metadata: metadata,
    );
  }

  void _flushKeyboardBuffer() {
    _keyboardIdleTimer?.cancel();
    _keyboardIdleTimer = null;
    final value = _keyboardBuffer.toString();
    _keyboardBuffer.clear();
    _acceptCandidate(value: value, source: HardwareScannerSource.keyboard);
  }

  void _handleNativeBroadcast(Map<String, Object?> payload) {
    if (payload['error'] != null) {
      _emit(
        HardwareScannerEvent(
          type: HardwareScannerEventType.rejected,
          reason: HardwareScannerEventReason.platformError,
          source: HardwareScannerSource.androidBroadcast,
          timestamp: DateTime.now(),
          error: payload['error'],
          metadata: payload,
        ),
      );
      return;
    }

    _emit(
      HardwareScannerEvent(
        type: HardwareScannerEventType.lifecycle,
        reason: HardwareScannerEventReason.nativeBroadcastReceived,
        source: HardwareScannerSource.androidBroadcast,
        timestamp: DateTime.now(),
        rawValue: payload['value']?.toString(),
        rawFormat: payload['format']?.toString(),
        metadata: payload,
      ),
    );

    _acceptCandidate(
      value: payload['value']?.toString(),
      source: HardwareScannerSource.androidBroadcast,
      rawFormat: payload['format']?.toString(),
      metadata: payload,
    );
  }

  void _acceptCandidate({
    required String? value,
    required HardwareScannerSource source,
    String? rawFormat,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    final timestamp = DateTime.now();
    final trimmedValue = value?.trim() ?? '';
    final format = HardwareScannerFormat.fromRaw(rawFormat);

    if (_isPaused) {
      _emitIgnored(
        HardwareScannerEventReason.paused,
        source,
        timestamp,
        rawValue: value,
        rawFormat: rawFormat,
        format: format,
        metadata: metadata,
      );
      return;
    }

    if (trimmedValue.isEmpty) {
      _emitIgnored(
        HardwareScannerEventReason.emptyPayload,
        source,
        timestamp,
        rawValue: value,
        rawFormat: rawFormat,
        format: format,
        metadata: metadata,
      );
      return;
    }

    if (!options.validCharacterPattern.hasMatch(trimmedValue)) {
      _emitIgnored(
        HardwareScannerEventReason.invalidCharacters,
        source,
        timestamp,
        rawValue: trimmedValue,
        rawFormat: rawFormat,
        format: format,
        metadata: metadata,
      );
      return;
    }

    if (format == HardwareScannerFormat.unknown) {
      if (!options.acceptUnknownFormat) {
        _emitIgnored(
          HardwareScannerEventReason.unsupportedFormat,
          source,
          timestamp,
          rawValue: trimmedValue,
          rawFormat: rawFormat,
          format: format,
          metadata: metadata,
        );
        return;
      }
    } else if (!options.supportedFormats.contains(format)) {
      _emitIgnored(
        HardwareScannerEventReason.unsupportedFormat,
        source,
        timestamp,
        rawValue: trimmedValue,
        rawFormat: rawFormat,
        format: format,
        metadata: metadata,
      );
      return;
    }

    if (_isDuplicate(trimmedValue, format, timestamp)) {
      _emitIgnored(
        HardwareScannerEventReason.duplicate,
        source,
        timestamp,
        rawValue: trimmedValue,
        rawFormat: rawFormat,
        format: format,
        metadata: metadata,
      );
      return;
    }

    final result = HardwareScanResult(
      value: trimmedValue,
      source: source,
      format: format,
      rawFormat: rawFormat,
      timestamp: timestamp,
      metadata: metadata,
    );

    _lastAcceptedValue = trimmedValue;
    _lastAcceptedFormat = format;
    _lastAcceptedAt = timestamp;

    _scansController.add(result);
    _emit(
      HardwareScannerEvent(
        type: HardwareScannerEventType.accepted,
        reason: HardwareScannerEventReason.accepted,
        source: source,
        timestamp: timestamp,
        result: result,
        rawValue: trimmedValue,
        format: format,
        rawFormat: rawFormat,
        metadata: metadata,
      ),
    );
  }

  bool _isDuplicate(
    String value,
    HardwareScannerFormat format,
    DateTime timestamp,
  ) {
    final lastAcceptedAt = _lastAcceptedAt;
    if (lastAcceptedAt == null || _lastAcceptedValue != value) return false;
    if (_lastAcceptedFormat != format) return false;
    return timestamp.difference(lastAcceptedAt) <=
        options.duplicateSuppressionWindow;
  }

  void _emitIgnored(
    HardwareScannerEventReason reason,
    HardwareScannerSource source,
    DateTime timestamp, {
    String? rawValue,
    String? rawFormat,
    HardwareScannerFormat format = HardwareScannerFormat.unknown,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    _emit(
      HardwareScannerEvent(
        type: HardwareScannerEventType.ignored,
        reason: reason,
        source: source,
        timestamp: timestamp,
        rawValue: rawValue,
        rawFormat: rawFormat,
        format: format,
        metadata: metadata,
      ),
    );
  }

  void _emitLifecycle(HardwareScannerEventReason reason) {
    _emit(
      HardwareScannerEvent(
        type: HardwareScannerEventType.lifecycle,
        reason: reason,
        source: HardwareScannerSource.unknown,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _emit(HardwareScannerEvent event) {
    if (_isDisposed) return;
    if (options.showLogs) {
      debugPrint('[HardwareBarcodeScanner] $event');
    }
    _eventsController.add(event);
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('HardwareScannerController has been disposed.');
    }
  }
}
