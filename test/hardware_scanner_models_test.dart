import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';

void main() {
  group('HardwareScannerFormat.fromRaw', () {
    const cases = <String, HardwareScannerFormat>{
      'QR_CODE': HardwareScannerFormat.qrCode,
      'qr': HardwareScannerFormat.qrCode,
      'CODE_128': HardwareScannerFormat.code128,
      'code128a': HardwareScannerFormat.code128,
      'CODE-128-B': HardwareScannerFormat.code128,
      'code128c': HardwareScannerFormat.code128,
      'CODE_39': HardwareScannerFormat.code39,
      'Code 3 of 9': HardwareScannerFormat.code39,
      'CODE_93': HardwareScannerFormat.code93,
      'EAN_13': HardwareScannerFormat.ean13,
      'EAN/JAN-13': HardwareScannerFormat.ean13,
      'EAN_8': HardwareScannerFormat.ean8,
      'EAN/JAN-8': HardwareScannerFormat.ean8,
      'UPC_A': HardwareScannerFormat.upcA,
      'UPC/EAN extension': HardwareScannerFormat.upcA,
      'UPC_E': HardwareScannerFormat.upcE,
      'ITF': HardwareScannerFormat.itf,
      'I2/5': HardwareScannerFormat.itf,
      'Interleaved 2 of 5': HardwareScannerFormat.itf,
      'interleaved25': HardwareScannerFormat.itf,
      'PDF_417': HardwareScannerFormat.pdf417,
      'pdf': HardwareScannerFormat.pdf417,
      'DATA_MATRIX': HardwareScannerFormat.dataMatrix,
      'DM': HardwareScannerFormat.dataMatrix,
      'AZTEC': HardwareScannerFormat.aztec,
    };

    cases.forEach((raw, expected) {
      test('maps "$raw" to $expected', () {
        expect(HardwareScannerFormat.fromRaw(raw), expected);
      });
    });

    test('matching ignores case, spacing, and punctuation', () {
      expect(
        HardwareScannerFormat.fromRaw('  data-matrix  '),
        HardwareScannerFormat.dataMatrix,
      );
    });

    test('null, empty, and whitespace labels resolve to unknown', () {
      expect(
          HardwareScannerFormat.fromRaw(null), HardwareScannerFormat.unknown);
      expect(HardwareScannerFormat.fromRaw(''), HardwareScannerFormat.unknown);
      expect(
        HardwareScannerFormat.fromRaw('   '),
        HardwareScannerFormat.unknown,
      );
    });

    test('an unrecognized vendor label resolves to unknown', () {
      expect(
        HardwareScannerFormat.fromRaw('MAXICODE'),
        HardwareScannerFormat.unknown,
      );
    });

    test('allKnown covers every enum value except unknown', () {
      expect(
        HardwareScannerFormat.allKnown,
        HardwareScannerFormat.values.toSet()
          ..remove(HardwareScannerFormat.unknown),
      );
    });
  });

  group('HardwareScanResult', () {
    test('hasKnownFormat reflects the resolved symbology', () {
      final known = HardwareScanResult(
        value: 'ABC',
        source: HardwareScannerSource.androidBroadcast,
        format: HardwareScannerFormat.code128,
        timestamp: DateTime(2026, 8, 2),
      );
      final unknown = HardwareScanResult(
        value: 'ABC',
        source: HardwareScannerSource.keyboard,
        format: HardwareScannerFormat.unknown,
        timestamp: DateTime(2026, 8, 2),
      );

      expect(known.hasKnownFormat, isTrue);
      expect(unknown.hasKnownFormat, isFalse);
    });

    test('metadata defaults to empty', () {
      final result = HardwareScanResult(
        value: 'ABC',
        source: HardwareScannerSource.keyboard,
        format: HardwareScannerFormat.unknown,
        timestamp: DateTime(2026, 8, 2),
      );

      expect(result.metadata, isEmpty);
      expect(result.rawFormat, isNull);
    });

    test('toString reports the value, source, and formats', () {
      final result = HardwareScanResult(
        value: 'ABC-123',
        source: HardwareScannerSource.androidBroadcast,
        format: HardwareScannerFormat.code128,
        rawFormat: 'CODE_128',
        timestamp: DateTime(2026, 8, 2),
      );

      expect(
        result.toString(),
        'HardwareScanResult(value: ABC-123, '
        'source: HardwareScannerSource.androidBroadcast, '
        'format: HardwareScannerFormat.code128, rawFormat: CODE_128)',
      );
    });
  });

  group('HardwareScannerEvent', () {
    test('isAccepted is true only for accepted events', () {
      final accepted = HardwareScannerEvent(
        type: HardwareScannerEventType.accepted,
        reason: HardwareScannerEventReason.accepted,
        source: HardwareScannerSource.keyboard,
        timestamp: DateTime(2026, 8, 2),
      );
      final ignored = HardwareScannerEvent(
        type: HardwareScannerEventType.ignored,
        reason: HardwareScannerEventReason.duplicate,
        source: HardwareScannerSource.keyboard,
        timestamp: DateTime(2026, 8, 2),
      );

      expect(accepted.isAccepted, isTrue);
      expect(ignored.isAccepted, isFalse);
    });

    test('format defaults to unknown and metadata to empty', () {
      final event = HardwareScannerEvent(
        type: HardwareScannerEventType.lifecycle,
        reason: HardwareScannerEventReason.started,
        source: HardwareScannerSource.unknown,
        timestamp: DateTime(2026, 8, 2),
      );

      expect(event.format, HardwareScannerFormat.unknown);
      expect(event.metadata, isEmpty);
      expect(event.error, isNull);
      expect(event.result, isNull);
    });

    test('toString reports the type, reason, source, and raw value', () {
      final event = HardwareScannerEvent(
        type: HardwareScannerEventType.ignored,
        reason: HardwareScannerEventReason.duplicate,
        source: HardwareScannerSource.keyboard,
        timestamp: DateTime(2026, 8, 2),
        rawValue: 'ABC-123',
      );

      expect(
        event.toString(),
        'HardwareScannerEvent(type: HardwareScannerEventType.ignored, '
        'reason: HardwareScannerEventReason.duplicate, '
        'source: HardwareScannerSource.keyboard, '
        'rawValue: ABC-123, result: null)',
      );
    });
  });

  group('HardwareScannerOptions', () {
    test('zero-config defaults match the documented behaviour', () {
      final options = HardwareScannerOptions();

      expect(options.supportedFormats, HardwareScannerFormat.allKnown);
      expect(options.acceptUnknownFormat, isTrue);
      expect(options.keyboardDelimiters, <String>{'\n', '\r'});
      expect(options.keyboardIdleTimeout, const Duration(milliseconds: 250));
      expect(
        options.duplicateSuppressionWindow,
        const Duration(milliseconds: 750),
      );
      expect(options.preferPhysicalKeyboardInput, isFalse);
      expect(options.configureChainwayBroadcastOutput, isTrue);
      expect(options.showLogs, isFalse);
    });

    test('the default pattern accepts any non-empty value', () {
      final pattern = HardwareScannerOptions().validCharacterPattern;

      expect(pattern.hasMatch('ABC-123'), isTrue);
      expect(pattern.hasMatch('1836.35חגצה'), isTrue);
      expect(pattern.hasMatch(''), isFalse);
    });

    test('supplied values replace the defaults', () {
      final options = HardwareScannerOptions(
        supportedFormats: {HardwareScannerFormat.qrCode},
        acceptUnknownFormat: false,
        validCharacterPattern: RegExp(r'^\d+$'),
        keyboardDelimiters: {'\t'},
        preferPhysicalKeyboardInput: true,
        showLogs: true,
      );

      expect(options.supportedFormats, {HardwareScannerFormat.qrCode});
      expect(options.acceptUnknownFormat, isFalse);
      expect(options.validCharacterPattern.hasMatch('ABC'), isFalse);
      expect(options.keyboardDelimiters, <String>{'\t'});
      expect(options.preferPhysicalKeyboardInput, isTrue);
      expect(options.showLogs, isTrue);
    });
  });
}
