/// Barcode symbologies recognized by the package.
enum HardwareScannerFormat {
  /// QR Code.
  qrCode,

  /// Code 128.
  code128,

  /// Code 39.
  code39,

  /// Code 93.
  code93,

  /// EAN-13.
  ean13,

  /// EAN-8.
  ean8,

  /// UPC-A.
  upcA,

  /// UPC-E.
  upcE,

  /// Interleaved 2 of 5.
  itf,

  /// PDF417.
  pdf417,

  /// Data Matrix.
  dataMatrix,

  /// Aztec Code.
  aztec,

  /// An absent or unrecognized symbology label.
  ///
  /// This is the normal, expected value for every scan delivered over the HID
  /// keyboard transport, which carries no symbology at all. It does not
  /// indicate a problem with the scan or the scanner.
  unknown;

  /// All recognized formats, excluding [unknown].
  static Set<HardwareScannerFormat> get allKnown => {
        qrCode,
        code128,
        code39,
        code93,
        ean13,
        ean8,
        upcA,
        upcE,
        itf,
        pdf417,
        dataMatrix,
        aztec,
      };

  /// Converts a vendor-provided symbology label to a known format.
  ///
  /// Matching is case-insensitive and ignores punctuation. Returns [unknown]
  /// for `null`, empty, or unsupported labels.
  static HardwareScannerFormat fromRaw(String? value) {
    if (value == null || value.trim().isEmpty) return unknown;

    final normalized = value.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        );

    return switch (normalized) {
      'qrcode' || 'qr' => qrCode,
      'code128' || 'code128a' || 'code128b' || 'code128c' => code128,
      'code39' || 'code3of9' => code39,
      'code93' => code93,
      'ean13' || 'eanjan13' => ean13,
      'ean8' || 'eanjan8' => ean8,
      'upca' || 'upceanextension' => upcA,
      'upce' => upcE,
      'itf' || 'i25' || 'interleaved2of5' || 'interleaved25' => itf,
      'pdf417' || 'pdf' => pdf417,
      'datamatrix' || 'dm' => dataMatrix,
      'aztec' => aztec,
      _ => unknown,
    };
  }
}

/// The transport that delivered a scanner value.
enum HardwareScannerSource {
  /// A HID device represented as keyboard input.
  keyboard,

  /// An Android broadcast intent from a scanner service.
  androidBroadcast,

  /// No scanner transport applies or the transport is unknown.
  unknown,
}

/// High-level categories emitted by [HardwareScannerEvent].
enum HardwareScannerEventType {
  /// A candidate was accepted and produced a scan result.
  accepted,

  /// A candidate was intentionally filtered out.
  ignored,

  /// A platform operation failed.
  rejected,

  /// A controller or input lifecycle notification.
  lifecycle,
}

/// Detailed reasons for scanner events.
enum HardwareScannerEventReason {
  /// A scan candidate was accepted.
  accepted,

  /// The controller started.
  started,

  /// The controller stopped.
  stopped,

  /// The controller paused or a scan arrived while paused.
  paused,

  /// The controller resumed.
  resumed,

  /// A candidate contained no non-whitespace data.
  emptyPayload,

  /// A candidate did not match the configured validation pattern.
  invalidCharacters,

  /// A candidate's reported format is not enabled.
  unsupportedFormat,

  /// A recently accepted value and format were received again.
  duplicate,

  /// The native plugin is unavailable on the current platform.
  platformUnavailable,

  /// A native platform operation or stream failed.
  platformError,

  /// A matching native Android broadcast was received.
  nativeBroadcastReceived,

  /// Keyboard text was received by the controller.
  keyboardInputReceived,
}

/// An accepted and normalized scanner value.
class HardwareScanResult {
  /// Creates an immutable description of an accepted scan.
  const HardwareScanResult({
    required this.value,
    required this.source,
    required this.format,
    required this.timestamp,
    this.rawFormat,
    this.metadata = const <String, Object?>{},
  });

  /// The scanner value after surrounding whitespace has been removed.
  final String value;

  /// The transport that supplied [value].
  final HardwareScannerSource source;

  /// The normalized barcode format.
  ///
  /// **This is always [HardwareScannerFormat.unknown] when [source] is
  /// [HardwareScannerSource.keyboard].** A HID scanner presents itself as a
  /// keyboard and sends only the decoded characters, so there is no channel on
  /// which a symbology could arrive. Only
  /// [HardwareScannerSource.androidBroadcast] can report a format, and only
  /// when the scanner service includes one.
  ///
  /// Do not branch on this to distinguish barcode types unless the deployment
  /// is broadcast-based. See [hasKnownFormat].
  final HardwareScannerFormat format;

  /// The original vendor-provided format label, when available.
  ///
  /// **Always `null` for [HardwareScannerSource.keyboard] scans**, for the
  /// reason given on [format]. On [HardwareScannerSource.androidBroadcast] it
  /// carries the scanner service's own label — for example `CODE_128` — before
  /// normalization, and is still `null` when the service sends no label.
  final String? rawFormat;

  /// The time at which the controller accepted this scan.
  final DateTime timestamp;

  /// Transport-specific data associated with this scan.
  final Map<String, Object?> metadata;

  /// Whether [format] contains a recognized symbology.
  ///
  /// This is `false` for every [HardwareScannerSource.keyboard] scan — see
  /// [format]. A `false` result means "the transport did not tell us", never
  /// "this barcode has no type".
  bool get hasKnownFormat => format != HardwareScannerFormat.unknown;

  @override
  String toString() {
    return 'HardwareScanResult(value: $value, source: $source, '
        'format: $format, rawFormat: $rawFormat)';
  }
}

/// A diagnostic, filtering, or lifecycle event from the scanner controller.
class HardwareScannerEvent {
  /// Creates a scanner event.
  const HardwareScannerEvent({
    required this.type,
    required this.reason,
    required this.source,
    required this.timestamp,
    this.result,
    this.rawValue,
    this.format = HardwareScannerFormat.unknown,
    this.rawFormat,
    this.metadata = const <String, Object?>{},
    this.error,
  });

  /// The high-level event category.
  final HardwareScannerEventType type;

  /// The detailed reason this event was emitted.
  final HardwareScannerEventReason reason;

  /// The input transport associated with the event.
  final HardwareScannerSource source;

  /// The time at which the event occurred.
  final DateTime timestamp;

  /// The accepted result, present when [type] is
  /// [HardwareScannerEventType.accepted].
  final HardwareScanResult? result;

  /// The value before normalization or filtering, when applicable.
  final String? rawValue;

  /// The normalized format associated with [rawValue].
  final HardwareScannerFormat format;

  /// The original vendor-provided format label, when available.
  final String? rawFormat;

  /// Transport-specific data associated with this event.
  final Map<String, Object?> metadata;

  /// The platform error associated with a rejected event, when available.
  final Object? error;

  /// Whether this event contains an accepted [result].
  bool get isAccepted => type == HardwareScannerEventType.accepted;

  @override
  String toString() {
    return 'HardwareScannerEvent(type: $type, reason: $reason, '
        'source: $source, rawValue: $rawValue, result: $result)';
  }
}

/// Describes Android broadcast actions and extras used by a scanner service.
class AndroidScannerBroadcastPreset {
  /// Creates a broadcast preset.
  const AndroidScannerBroadcastPreset({
    required this.name,
    required this.actions,
    required this.dataKeys,
    this.formatKeys = const <String>[],
  });

  /// Stable name included in scan metadata.
  final String name;

  /// Intent actions registered by the Android broadcast receiver.
  final Set<String> actions;

  /// Intent extra keys checked for decoded barcode data, in priority order.
  final List<String> dataKeys;

  /// Intent extra keys checked for a symbology label, in priority order.
  final List<String> formatKeys;

  /// Serializes this preset for the native Android plugin.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'actions': actions.toList(growable: false),
      'dataKeys': dataKeys,
      'formatKeys': formatKeys,
    };
  }

  /// Common Chainway scanner-service broadcasts.
  static const chainway = AndroidScannerBroadcastPreset(
    name: 'chainway',
    actions: <String>{
      'com.scanner.broadcast',
      'scan.rcv.message',
      'com.geomobile.se4500barcode',
    },
    dataKeys: <String>['data', 'scannerdata', 'barcode', 'SCAN_DATA'],
    formatKeys: <String>['barcodeType', 'codetype', 'format', 'type'],
  );

  /// Common actions used by generic Android scanner services.
  static const genericScannerService = AndroidScannerBroadcastPreset(
    name: 'generic_scanner_service',
    actions: <String>{
      'com.android.server.scannerservice.broadcast',
      'com.android.intent.action.SCAN_RESULT',
      'com.android.intent.action.SCAN_DATA',
      'com.android.intent.action.BARCODE_RESULT',
      'com.android.intent.action.BARCODE_DATA',
      'com.android.scanner.RESULT',
      'com.android.scanner.DATA',
    },
    dataKeys: <String>[
      'scannerdata',
      'data',
      'barcode',
      'barcode_string',
      'SCAN_DATA',
      'BARCODE_DATA',
      'result',
      'RESULT',
    ],
    formatKeys: <String>['barcodeType', 'codetype', 'format', 'FORMAT', 'type'],
  );

  /// Zebra DataWedge broadcast output.
  static const zebraDataWedge = AndroidScannerBroadcastPreset(
    name: 'zebra_datawedge',
    actions: <String>{
      'com.symbol.datawedge.api.RESULT_ACTION',
      'com.symbol.datawedge.decode_action',
      'com.eventer.hardware_barcode_scanner.SCAN',
    },
    dataKeys: <String>[
      'com.symbol.datawedge.data_string',
      'com.symbol.datawedge.decode_data',
      'data',
    ],
    formatKeys: <String>[
      'com.symbol.datawedge.label_type',
      'com.symbol.datawedge.source',
      'format',
    ],
  );

  /// Honeywell scanner-service broadcasts.
  static const honeywell = AndroidScannerBroadcastPreset(
    name: 'honeywell',
    actions: <String>{
      'com.honeywell.decode.intent.action.ACTION_DECODE',
      'com.honeywell.decode.intent.action.ACTION_DECODE_RESULT',
      'com.honeywell.decode.intent.action.ACTION_DECODE_DATA',
    },
    dataKeys: <String>[
      'com.honeywell.decode.intent.extra.DATA_STRING',
      'com.honeywell.decode.intent.extra.DECODE_DATA',
      'data',
      'barcode',
    ],
    formatKeys: <String>[
      'com.honeywell.decode.intent.extra.CODE_ID',
      'com.honeywell.decode.intent.extra.SYMBOLOGY',
      'format',
    ],
  );

  /// Datalogic scanner-service broadcasts.
  static const datalogic = AndroidScannerBroadcastPreset(
    name: 'datalogic',
    actions: <String>{
      'com.datalogic.decode.intent.action.DECODE',
      'com.datalogic.decode.intent.action.DECODE_RESULT',
      'com.datalogic.decode.intent.action.DECODE_DATA',
    },
    dataKeys: <String>[
      'com.datalogic.decode.intent.extra.DATA',
      'com.datalogic.decode.intent.extra.BARCODE_STRING',
      'data',
      'barcode',
    ],
    formatKeys: <String>[
      'com.datalogic.decode.intent.extra.SYMBOLOGY',
      'format',
    ],
  );

  /// Unitech scanner-service broadcasts.
  static const unitech = AndroidScannerBroadcastPreset(
    name: 'unitech',
    actions: <String>{
      'com.unitech.scanner.action.DECODE',
      'com.unitech.scanner.action.DECODE_RESULT',
      'com.unitech.scanner.action.DECODE_DATA',
    },
    dataKeys: <String>['text', 'data', 'barcode', 'scannerdata'],
    formatKeys: <String>['type', 'format', 'codetype'],
  );

  /// CipherLab scanner-service broadcasts.
  static const cipherLab = AndroidScannerBroadcastPreset(
    name: 'cipherlab',
    actions: <String>{
      'com.cipherlab.barcodebaseapi.GET_DATA',
      'com.cipherlab.barcodebaseapi.DATA',
      'com.cipherlab.barcodebaseapi.RESULT',
      'com.cipherlab.scanner.ACTION',
      'com.cipherlab.decode.ACTION',
      'com.cipherlab.barcode.ACTION',
      'sw.reader.scan.result',
      'sw.reader.scan.data',
      'sw.reader.decode.result',
      'sw.reader.decode.data',
      'sw.reader.barcode.result',
      'sw.reader.barcode.data',
      'sw.reader.ACTION',
      'sw.reader.RESULT',
      'sw.reader.DATA',
    },
    dataKeys: <String>[
      'data',
      'barcode',
      'scan_data',
      'SCAN_DATA',
      'barcode_data',
      'BARCODE_DATA',
      'com.cipherlab.barcodebaseapi.DATA',
      'sw.reader.scan.result',
      'sw.reader.scan.data',
      'sw.reader.DATA',
      'sw.reader.RESULT',
      'BarcodeData',
    ],
    formatKeys: <String>['format', 'FORMAT', 'barcode_type', 'codeType'],
  );

  /// Urovo and Seuic scanner-service broadcasts.
  static const urovoSeuic = AndroidScannerBroadcastPreset(
    name: 'urovo_seuic',
    actions: <String>{
      'android.intent.ACTION_DECODE_DATA',
      'com.ubx.scanwedge.data',
      'com.seuic.scan',
      'com.seuic.scanner.action.BARCODE_SEND',
    },
    dataKeys: <String>[
      'barcode_string',
      'barcode',
      'scannerdata',
      'data',
      'decode_data',
      'SCAN_DATA',
    ],
    formatKeys: <String>['barcodeType', 'codetype', 'format', 'symbology'],
  );

  /// Presets enabled by default.
  static const defaults = <AndroidScannerBroadcastPreset>[
    chainway,
    genericScannerService,
    zebraDataWedge,
    honeywell,
    datalogic,
    unitech,
    cipherLab,
    urovoSeuic,
  ];
}

/// Configuration used by a [HardwareScannerController].
class HardwareScannerOptions {
  /// Creates scanner options.
  ///
  /// By default, all known formats and unknown formats are accepted, scanner
  /// values must be non-empty, and duplicate values are suppressed briefly.
  HardwareScannerOptions({
    Set<HardwareScannerFormat>? supportedFormats,
    this.acceptUnknownFormat = true,
    RegExp? validCharacterPattern,
    this.keyboardDelimiters = const <String>{'\n', '\r'},
    this.keyboardIdleTimeout = const Duration(milliseconds: 250),
    this.duplicateSuppressionWindow = const Duration(milliseconds: 750),
    this.preferPhysicalKeyboardInput = false,
    this.androidBroadcastPresets = AndroidScannerBroadcastPreset.defaults,
    this.configureChainwayBroadcastOutput = true,
    this.showLogs = false,
  })  : supportedFormats = supportedFormats ?? HardwareScannerFormat.allKnown,
        validCharacterPattern = validCharacterPattern ?? RegExp(r'^[\s\S]+$');

  /// Recognized formats that may be accepted.
  ///
  /// This filter only ever applies to scans that arrive with a symbology, which
  /// in practice means [HardwareScannerSource.androidBroadcast]. HID keyboard
  /// scans always report [HardwareScannerFormat.unknown] — see
  /// [HardwareScanResult.format] — so they are governed by
  /// [acceptUnknownFormat] instead and pass this set untouched.
  final Set<HardwareScannerFormat> supportedFormats;

  /// Whether values without a recognized format may be accepted.
  ///
  /// Defaults to `true`, and changing it is a decision about the HID transport
  /// rather than about unusual barcodes.
  ///
  /// ⚠️ **Setting this to `false` rejects every HID keyboard scan**, because
  /// those always report [HardwareScannerFormat.unknown]. Use it only when the
  /// deployment is exclusively Android broadcast scanners whose service is
  /// known to label every scan; otherwise the scanner appears to stop working
  /// and the reason surfaces only as an
  /// [HardwareScannerEventReason.unsupportedFormat] diagnostic.
  final bool acceptUnknownFormat;

  /// Pattern used to validate a trimmed candidate value.
  ///
  /// Use anchors if the entire value must match, for example `RegExp(r'^\d+$')`.
  final RegExp validCharacterPattern;

  /// Characters that finish the current keyboard scan.
  final Set<String> keyboardDelimiters;

  /// Inactivity duration after which buffered keyboard data is submitted.
  final Duration keyboardIdleTimeout;

  /// Time during which an identical value and format are ignored.
  final Duration duplicateSuppressionWindow;

  /// Whether HID keys are interpreted using their physical US-keyboard layout.
  ///
  /// Enable this only for ASCII scanners whose configured keyboard layout does
  /// not match the device layout. It does not preserve arbitrary Unicode input.
  final bool preferPhysicalKeyboardInput;

  /// Android scanner broadcast configurations to register.
  final List<AndroidScannerBroadcastPreset> androidBroadcastPresets;

  /// Whether the optional Chainway SDK should be configured when available.
  ///
  /// **Android and Chainway devices only**, and only when the consuming app
  /// supplies the vendor `cw-deviceapi` JAR — the package never ships one. It
  /// is a no-op everywhere else, including on Android devices from other
  /// vendors, and no error is reported when the SDK is absent.
  ///
  /// When it does apply, the package puts the scanner into broadcast output
  /// mode and **deliberately leaves scan-failure broadcasts off**. Chainway
  /// emits those on the same action and data key as a successful scan, with a
  /// marker value such as `cancel`, so enabling them would deliver a phantom
  /// scan every time a trigger pull failed to decode.
  ///
  /// Note the limit of that: this option controls what *this package* asks the
  /// scanner for. A device already configured for failure broadcasts through
  /// the vendor's own settings app will still send them, and they will arrive
  /// as ordinary scans. Set this to `false` if you configure the scanner
  /// yourself and do not want the package touching its output settings.
  final bool configureChainwayBroadcastOutput;

  /// Whether diagnostic events are printed to the Flutter and Android logs.
  final bool showLogs;

  /// Native-channel representations of [androidBroadcastPresets].
  List<Map<String, Object?>> get androidPresetMaps {
    return androidBroadcastPresets
        .map((preset) => preset.toMap())
        .toList(growable: false);
  }
}
