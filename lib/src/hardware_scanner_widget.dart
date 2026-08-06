import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'hardware_scanner_controller.dart';
import 'hardware_scanner_models.dart';

/// Captures HID scanner input while displaying [child].
///
/// The widget keeps a small hidden editable control focused so scanners can use
/// the platform text-input pipeline, including Unicode and keyboard-layout
/// handling. It can also capture physical keys as a fallback.
class HardwareScannerWidget extends StatefulWidget {
  /// Creates a scanner input region.
  const HardwareScannerWidget({
    required this.controller,
    this.child = const SizedBox.shrink(),
    this.focusNode,
    this.autofocus = true,
    this.requestFocusOnLifecycleEvents = true,
    this.captureHardwareKeyboard = true,
    this.captureTextInput = true,
    this.startOnInit = true,
    this.stopOnDispose = false,
    super.key,
  });

  /// Controller that receives captured input.
  final HardwareScannerController controller;

  /// Content displayed by the scanner input region.
  final Widget child;

  /// Optional focus node used to control scanner input focus.
  ///
  /// The widget creates and disposes its own node when this is `null`.
  final FocusNode? focusNode;

  /// Whether scanner focus is requested after the first frame.
  final bool autofocus;

  /// Whether start and resume events should restore scanner focus.
  final bool requestFocusOnLifecycleEvents;

  /// Whether Flutter hardware-key events are captured.
  final bool captureHardwareKeyboard;

  /// Whether committed platform text is captured through a hidden editable.
  final bool captureTextInput;

  /// Whether [controller] is started when the widget is initialized.
  final bool startOnInit;

  /// Whether [controller] is stopped when the widget is disposed.
  ///
  /// Leave this `false` when the controller is shared with another widget or
  /// owned by a longer-lived object.
  final bool stopOnDispose;

  @override
  State<HardwareScannerWidget> createState() => _HardwareScannerWidgetState();
}

class _HardwareScannerWidgetState extends State<HardwareScannerWidget> {
  late FocusNode _focusNode;
  late final TextEditingController _textController;
  late bool _ownsFocusNode;
  StreamSubscription<HardwareScannerEvent>? _eventSubscription;
  final StringBuffer _hardwareFallbackBuffer = StringBuffer();
  Timer? _hardwareFallbackTimer;
  bool _textInputActive = false;
  bool _hardwareKeyboardHandlerAttached = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _textController = TextEditingController();
    _subscribeToLifecycleEvents();
    _attachHardwareKeyboardHandlerIfNeeded();
    if (widget.startOnInit) {
      unawaited(widget.controller.start());
    }
    if (widget.autofocus) {
      _requestFocusAfterFrame();
    }
  }

  @override
  void didUpdateWidget(covariant HardwareScannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachHardwareKeyboardHandler();
      _cancelHardwareFallback();
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      _ownsFocusNode = widget.focusNode == null;
      _focusNode = widget.focusNode ?? FocusNode();
      _attachHardwareKeyboardHandlerIfNeeded();
      if (widget.autofocus) {
        _requestFocusAfterFrame();
      }
    }
    if (oldWidget.controller != widget.controller) {
      _eventSubscription?.cancel();
      if (oldWidget.stopOnDispose) {
        unawaited(oldWidget.controller.stop());
      }
      _subscribeToLifecycleEvents();
      if (widget.startOnInit) {
        unawaited(widget.controller.start());
      }
    }
    if (!oldWidget.requestFocusOnLifecycleEvents &&
        widget.requestFocusOnLifecycleEvents) {
      _requestFocusAfterFrame();
    }
    if (oldWidget.captureHardwareKeyboard != widget.captureHardwareKeyboard ||
        oldWidget.captureTextInput != widget.captureTextInput) {
      if (widget.captureHardwareKeyboard && widget.captureTextInput) {
        _attachHardwareKeyboardHandlerIfNeeded();
      } else {
        _detachHardwareKeyboardHandler();
      }
    }
  }

  @override
  void dispose() {
    _detachHardwareKeyboardHandler();
    _cancelHardwareFallback();
    _eventSubscription?.cancel();
    if (widget.stopOnDispose) {
      unawaited(widget.controller.stop());
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.captureTextInput)
          widget.child
        else
          KeyboardListener(
            autofocus: widget.autofocus,
            focusNode: _focusNode,
            onKeyEvent: (event) {
              widget.controller.handleKeyEvent(event);
            },
            child: widget.child,
          ),
        if (widget.captureTextInput)
          Positioned(
            width: 1,
            height: 1,
            left: -1000,
            top: -1000,
            child: EditableText(
              controller: _textController,
              focusNode: _focusNode,
              style: const TextStyle(fontSize: 1, color: Color(0x00000000)),
              cursorColor: const Color(0x00000000),
              backgroundCursorColor: const Color(0x00000000),
              enableInteractiveSelection: false,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.none,
              onChanged: _handleTextChanged,
              onSubmitted: (_) => widget.controller.handleTextInput('\n'),
            ),
          ),
      ],
    );
  }

  void _handleTextChanged(String value) {
    if (value.isEmpty) return;
    if (widget.controller.options.preferPhysicalKeyboardInput) {
      _textController.clear();
      return;
    }
    _cancelHardwareFallback();
    _textInputActive = true;
    widget.controller.handleTextInput(value, replaceBuffer: true);
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (!widget.captureHardwareKeyboard) return false;
    if (!_focusNode.hasFocus) return false;
    if (event is! KeyDownEvent) return false;

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final character = widget.controller.characterForKeyEvent(
      event,
      isShiftPressed: isShiftPressed,
    );
    if (character == null || character.isEmpty) return false;

    if (!widget.captureTextInput ||
        widget.controller.options.preferPhysicalKeyboardInput) {
      widget.controller.handleTextInput(character);
      return false;
    }

    if (_textInputActive) {
      // The platform text pipeline is driving this scan, so the key-event
      // channel is a second, unordered copy of the same input — including the
      // terminator. Ignore it entirely.
      //
      // The two channels are not synchronised. Committed text can lag behind
      // key events, and acting on a terminator key that arrives early flushes a
      // partial buffer: on iOS this produced a truncated scan immediately
      // followed by the complete one, because only the first character had been
      // committed when the terminator landed.
      //
      // Terminating from the same pipeline that delivers the characters — the
      // editable's submit action — keeps the terminator ordered with respect to
      // them. A platform that somehow delivers no submit action still finishes
      // the scan through `keyboardIdleTimeout`.
      return false;
    }

    _bufferHardwareFallbackCharacter(character);
    return false;
  }

  void _bufferHardwareFallbackCharacter(String character) {
    _hardwareFallbackTimer?.cancel();

    if (widget.controller.options.keyboardDelimiters.contains(character)) {
      _flushHardwareFallback();
      widget.controller.handleTextInput(character);
      return;
    }

    _hardwareFallbackBuffer.write(character);
    _hardwareFallbackTimer = Timer(
      widget.controller.options.keyboardIdleTimeout,
      _flushHardwareFallback,
    );
  }

  void _flushHardwareFallback() {
    _hardwareFallbackTimer?.cancel();
    _hardwareFallbackTimer = null;
    final value = _hardwareFallbackBuffer.toString();
    _hardwareFallbackBuffer.clear();
    if (value.isEmpty) return;
    widget.controller.handleTextInput(value);
  }

  void _cancelHardwareFallback() {
    _hardwareFallbackTimer?.cancel();
    _hardwareFallbackTimer = null;
    _hardwareFallbackBuffer.clear();
  }

  void _clearHiddenTextInput() {
    _textInputActive = false;
    if (_textController.text.isNotEmpty) {
      _textController.clear();
    }

    // Take focus back, because finishing a scan can take it away.
    //
    // A scanner's terminator reaches the platform as a submit action, and
    // `EditableText.performAction` finalizes a single-line field by calling
    // `focusNode.unfocus()`. The hidden editable then has no input connection
    // and `_handleHardwareKeyEvent` bails on `hasFocus`, so **scanning stops
    // dead after the first terminated scan** and never recovers — focus was
    // only ever re-requested on `started` and `resumed`.
    //
    // Consumers that pause and resume around each scan never saw this, because
    // `resumed` happened to restore focus for them.
    _requestFocusAfterFrame();
  }

  bool _shouldClearTextInputForEvent(HardwareScannerEvent event) {
    if (!widget.captureTextInput) return false;
    if (event.source != HardwareScannerSource.keyboard) return false;

    // Accepted and ignored are both terminal decisions on the candidate, so
    // the editable must not keep holding it either way.
    //
    // Deliberately not a list of specific ignore reasons. It used to be, and
    // `paused` was missing from it: a scan arriving while the controller was
    // paused left its text in the field, and the next accepted scan came
    // through as `leftover + newScan`. Testing the category rather than
    // enumerating reasons means a future reason cannot reintroduce that.
    return event.type == HardwareScannerEventType.accepted ||
        event.type == HardwareScannerEventType.ignored;
  }

  void _subscribeToLifecycleEvents() {
    _eventSubscription = widget.controller.events.listen((event) {
      if (_shouldClearTextInputForEvent(event)) {
        _clearHiddenTextInput();
      }

      if (!widget.autofocus || !widget.requestFocusOnLifecycleEvents) return;
      if (event.type != HardwareScannerEventType.lifecycle) return;
      if (event.reason == HardwareScannerEventReason.started ||
          event.reason == HardwareScannerEventReason.resumed) {
        _requestFocusAfterFrame();
      }
    });
  }

  void _attachHardwareKeyboardHandlerIfNeeded() {
    if (!widget.captureHardwareKeyboard ||
        !widget.captureTextInput ||
        _hardwareKeyboardHandlerAttached) {
      return;
    }
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
    _hardwareKeyboardHandlerAttached = true;
  }

  void _detachHardwareKeyboardHandler() {
    if (!_hardwareKeyboardHandlerAttached) return;
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _hardwareKeyboardHandlerAttached = false;
  }

  void _requestFocusAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.autofocus) return;
      _focusNode.requestFocus();
    });
  }
}
