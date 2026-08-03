import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';

/// Pins the wire contract of every bundled preset.
///
/// These constants are the only thing standing between a typo and a scanner
/// that silently never fires: an action or extra key that no longer matches the
/// vendor's is indistinguishable at runtime from a device that was never
/// scanned. Update these expectations deliberately, alongside a device that
/// proves the new value.
void main() {
  test('chainway preset pins its actions and extra keys', () {
    const preset = AndroidScannerBroadcastPreset.chainway;

    expect(preset.name, 'chainway');
    expect(preset.actions, <String>{
      'com.scanner.broadcast',
      'scan.rcv.message',
      'com.geomobile.se4500barcode',
    });
    expect(
      preset.dataKeys,
      orderedEquals(<String>['data', 'scannerdata', 'barcode', 'SCAN_DATA']),
    );
    expect(
      preset.formatKeys,
      orderedEquals(<String>['barcodeType', 'codetype', 'format', 'type']),
    );
  });

  test('generic scanner service preset pins its actions and extra keys', () {
    const preset = AndroidScannerBroadcastPreset.genericScannerService;

    expect(preset.name, 'generic_scanner_service');
    expect(preset.actions, <String>{
      'com.android.server.scannerservice.broadcast',
      'com.android.intent.action.SCAN_RESULT',
      'com.android.intent.action.SCAN_DATA',
      'com.android.intent.action.BARCODE_RESULT',
      'com.android.intent.action.BARCODE_DATA',
      'com.android.scanner.RESULT',
      'com.android.scanner.DATA',
    });
    expect(
      preset.dataKeys,
      orderedEquals(<String>[
        'scannerdata',
        'data',
        'barcode',
        'barcode_string',
        'SCAN_DATA',
        'BARCODE_DATA',
        'result',
        'RESULT',
      ]),
    );
    expect(
      preset.formatKeys,
      orderedEquals(<String>[
        'barcodeType',
        'codetype',
        'format',
        'FORMAT',
        'type',
      ]),
    );
  });

  test('zebra datawedge preset pins its actions and extra keys', () {
    const preset = AndroidScannerBroadcastPreset.zebraDataWedge;

    expect(preset.name, 'zebra_datawedge');
    expect(preset.actions, <String>{
      'com.symbol.datawedge.api.RESULT_ACTION',
      'com.symbol.datawedge.decode_action',
      'com.eventer.hardware_barcode_scanner.SCAN',
    });
    expect(
      preset.dataKeys,
      orderedEquals(<String>[
        'com.symbol.datawedge.data_string',
        'com.symbol.datawedge.decode_data',
        'data',
      ]),
    );
    expect(
      preset.formatKeys,
      orderedEquals(<String>[
        'com.symbol.datawedge.label_type',
        'com.symbol.datawedge.source',
        'format',
      ]),
    );
  });

  test('honeywell preset pins its actions and extra keys', () {
    const preset = AndroidScannerBroadcastPreset.honeywell;

    expect(preset.name, 'honeywell');
    expect(preset.actions, <String>{
      'com.honeywell.decode.intent.action.ACTION_DECODE',
      'com.honeywell.decode.intent.action.ACTION_DECODE_RESULT',
      'com.honeywell.decode.intent.action.ACTION_DECODE_DATA',
    });
    expect(
      preset.dataKeys,
      orderedEquals(<String>[
        'com.honeywell.decode.intent.extra.DATA_STRING',
        'com.honeywell.decode.intent.extra.DECODE_DATA',
        'data',
        'barcode',
      ]),
    );
    expect(
      preset.formatKeys,
      orderedEquals(<String>[
        'com.honeywell.decode.intent.extra.CODE_ID',
        'com.honeywell.decode.intent.extra.SYMBOLOGY',
        'format',
      ]),
    );
  });

  test('datalogic preset pins its actions and extra keys', () {
    const preset = AndroidScannerBroadcastPreset.datalogic;

    expect(preset.name, 'datalogic');
    expect(preset.actions, <String>{
      'com.datalogic.decode.intent.action.DECODE',
      'com.datalogic.decode.intent.action.DECODE_RESULT',
      'com.datalogic.decode.intent.action.DECODE_DATA',
    });
    expect(
      preset.dataKeys,
      orderedEquals(<String>[
        'com.datalogic.decode.intent.extra.DATA',
        'com.datalogic.decode.intent.extra.BARCODE_STRING',
        'data',
        'barcode',
      ]),
    );
    expect(
      preset.formatKeys,
      orderedEquals(<String>[
        'com.datalogic.decode.intent.extra.SYMBOLOGY',
        'format',
      ]),
    );
  });

  test('unitech preset pins its actions and extra keys', () {
    const preset = AndroidScannerBroadcastPreset.unitech;

    expect(preset.name, 'unitech');
    expect(preset.actions, <String>{
      'com.unitech.scanner.action.DECODE',
      'com.unitech.scanner.action.DECODE_RESULT',
      'com.unitech.scanner.action.DECODE_DATA',
    });
    expect(
      preset.dataKeys,
      orderedEquals(<String>['text', 'data', 'barcode', 'scannerdata']),
    );
    expect(
      preset.formatKeys,
      orderedEquals(<String>['type', 'format', 'codetype']),
    );
  });

  test('cipherlab preset pins its actions and extra keys', () {
    const preset = AndroidScannerBroadcastPreset.cipherLab;

    expect(preset.name, 'cipherlab');
    expect(preset.actions, <String>{
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
    });
    expect(
      preset.dataKeys,
      orderedEquals(<String>[
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
      ]),
    );
    expect(
      preset.formatKeys,
      orderedEquals(<String>['format', 'FORMAT', 'barcode_type', 'codeType']),
    );
  });

  test('urovo and seuic preset pins its actions and extra keys', () {
    const preset = AndroidScannerBroadcastPreset.urovoSeuic;

    expect(preset.name, 'urovo_seuic');
    expect(preset.actions, <String>{
      'android.intent.ACTION_DECODE_DATA',
      'com.ubx.scanwedge.data',
      'com.seuic.scan',
      'com.seuic.scanner.action.BARCODE_SEND',
    });
    expect(
      preset.dataKeys,
      orderedEquals(<String>[
        'barcode_string',
        'barcode',
        'scannerdata',
        'data',
        'decode_data',
        'SCAN_DATA',
      ]),
    );
    expect(
      preset.formatKeys,
      orderedEquals(<String>['barcodeType', 'codetype', 'format', 'symbology']),
    );
  });

  test('defaults contain every bundled preset in registration order', () {
    expect(
      AndroidScannerBroadcastPreset.defaults,
      orderedEquals(<AndroidScannerBroadcastPreset>[
        AndroidScannerBroadcastPreset.chainway,
        AndroidScannerBroadcastPreset.genericScannerService,
        AndroidScannerBroadcastPreset.zebraDataWedge,
        AndroidScannerBroadcastPreset.honeywell,
        AndroidScannerBroadcastPreset.datalogic,
        AndroidScannerBroadcastPreset.unitech,
        AndroidScannerBroadcastPreset.cipherLab,
        AndroidScannerBroadcastPreset.urovoSeuic,
      ]),
    );
  });

  test('preset names are unique across the defaults', () {
    final names = AndroidScannerBroadcastPreset.defaults
        .map((preset) => preset.name)
        .toList();

    expect(names.toSet(), hasLength(names.length));
  });

  test('every default preset declares at least one action and data key', () {
    for (final preset in AndroidScannerBroadcastPreset.defaults) {
      expect(preset.actions, isNotEmpty,
          reason: '${preset.name} has no action');
      expect(
        preset.dataKeys,
        isNotEmpty,
        reason: '${preset.name} has no data key',
      );
    }
  });

  test('toMap serializes the fields the native receiver reads', () {
    const preset = AndroidScannerBroadcastPreset(
      name: 'custom',
      actions: <String>{'com.example.SCAN'},
      dataKeys: <String>['data'],
      formatKeys: <String>['format'],
    );

    expect(preset.toMap(), <String, Object?>{
      'name': 'custom',
      'actions': <String>['com.example.SCAN'],
      'dataKeys': <String>['data'],
      'formatKeys': <String>['format'],
    });
  });

  test('formatKeys defaults to empty when a preset omits it', () {
    const preset = AndroidScannerBroadcastPreset(
      name: 'no_format',
      actions: <String>{'com.example.SCAN'},
      dataKeys: <String>['data'],
    );

    expect(preset.formatKeys, isEmpty);
    expect(preset.toMap()['formatKeys'], isEmpty);
  });

  test('androidPresetMaps serializes every configured preset', () {
    final options = HardwareScannerOptions(
      androidBroadcastPresets: const <AndroidScannerBroadcastPreset>[
        AndroidScannerBroadcastPreset.chainway,
        AndroidScannerBroadcastPreset.zebraDataWedge,
      ],
    );

    final maps = options.androidPresetMaps;

    expect(maps, hasLength(2));
    expect(maps.first['name'], 'chainway');
    expect(maps.last['name'], 'zebra_datawedge');
    expect(maps.last['dataKeys'], contains('com.symbol.datawedge.data_string'));
  });

  test('default options register every bundled preset', () {
    final options = HardwareScannerOptions();

    expect(
      options.androidBroadcastPresets,
      same(AndroidScannerBroadcastPreset.defaults),
    );
    expect(options.androidPresetMaps, hasLength(8));
  });
}
