import Flutter
import UIKit

public class HardwareBarcodeScannerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "hardware_barcode_scanner/methods",
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: "hardware_barcode_scanner/events",
      binaryMessenger: registrar.messenger()
    )
    let instance = HardwareBarcodeScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startBroadcasts", "stopBroadcasts":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
