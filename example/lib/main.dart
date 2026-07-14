import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _controller = HardwareScannerController();
  StreamSubscription<HardwareScanResult>? _subscription;
  String _lastScan = 'No scan yet';

  @override
  void initState() {
    super.initState();
    _subscription = _controller.scans.listen((scan) {
      setState(() {
        _lastScan = '${scan.value} (${scan.format.name}, ${scan.source.name})';
      });
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Hardware scanner input')),
        body: HardwareScannerWidget(
          controller: _controller,
          child: Center(child: Text(_lastScan)),
        ),
      ),
    );
  }
}
