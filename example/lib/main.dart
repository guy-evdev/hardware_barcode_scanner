import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hardware_barcode_scanner/hardware_barcode_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const ScannerPage(),
    );
  }
}

/// Shows accepted scans alongside the diagnostic stream.
///
/// The diagnostics half exists because the reason a scan was *not* accepted —
/// a duplicate, an unsupported format, a paused controller — is the thing worth
/// seeing while setting up a new scanner.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late HardwareScannerController _controller;
  StreamSubscription<HardwareScanResult>? _scanSubscription;
  StreamSubscription<HardwareScannerEvent>? _eventSubscription;

  final _scans = <HardwareScanResult>[];
  final _diagnostics = <String>[];

  /// Interprets HID keys by their physical US-keyboard position.
  ///
  /// Only useful for ASCII-only scanners on a device whose keyboard layout is
  /// not US. It does not preserve arbitrary Unicode, so it stays off here.
  bool _preferPhysicalKeyboardInput = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  @override
  void dispose() {
    unawaited(_scanSubscription?.cancel());
    unawaited(_eventSubscription?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  HardwareScannerController _createController() {
    final controller = HardwareScannerController(
      options: HardwareScannerOptions(
        preferPhysicalKeyboardInput: _preferPhysicalKeyboardInput,
        // Off by default in the package, and it can print scanned values.
        // Enabled here because this app exists to diagnose a scanner setup.
        showLogs: true,
      ),
    );

    _scanSubscription = controller.scans.listen((scan) {
      setState(() => _scans.insert(0, scan));
    });
    _eventSubscription = controller.events.listen((event) {
      if (event.type == HardwareScannerEventType.accepted) return;
      setState(() {
        _diagnostics.insert(0, '${event.type.name} · ${event.reason.name}');
        if (_diagnostics.length > 20) _diagnostics.removeLast();
      });
    });

    return controller;
  }

  /// Rebuilds the controller, because options are immutable once it exists.
  Future<void> _setPreferPhysicalKeyboardInput(bool value) async {
    final previous = _controller;
    await _scanSubscription?.cancel();
    await _eventSubscription?.cancel();

    setState(() {
      _preferPhysicalKeyboardInput = value;
      _isPaused = false;
      _controller = _createController();
    });

    // The widget has already switched to the new controller.
    await previous.dispose();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      _isPaused ? _controller.pause() : _controller.resume();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware scanner input'),
        actions: [
          IconButton(
            tooltip: _isPaused ? 'Resume scanning' : 'Pause scanning',
            onPressed: _togglePause,
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
          ),
        ],
      ),
      body: HardwareScannerWidget(
        controller: _controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              value: _preferPhysicalKeyboardInput,
              onChanged: _setPreferPhysicalKeyboardInput,
              title: const Text('Physical US-keyboard mode'),
              subtitle:
                  const Text('For ASCII-only scanners on a non-US layout'),
            ),
            const Divider(height: 1),
            Expanded(child: _ScanList(scans: _scans)),
            const Divider(height: 1),
            SizedBox(height: 140, child: _DiagnosticList(lines: _diagnostics)),
          ],
        ),
      ),
    );
  }
}

class _ScanList extends StatelessWidget {
  const _ScanList({required this.scans});

  final List<HardwareScanResult> scans;

  @override
  Widget build(BuildContext context) {
    if (scans.isEmpty) {
      return const Center(child: Text('Scan a barcode'));
    }

    return ListView.builder(
      itemCount: scans.length,
      itemBuilder: (context, index) {
        final scan = scans[index];
        return ListTile(
          title: Text(scan.value),
          subtitle: Text(
            '${scan.format.name} · ${scan.source.name}'
            '${scan.rawFormat == null ? '' : ' · raw: ${scan.rawFormat}'}',
          ),
        );
      },
    );
  }
}

class _DiagnosticList extends StatelessWidget {
  const _DiagnosticList({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: lines.length,
      itemBuilder: (context, index) => Text(lines[index], style: style),
    );
  }
}
