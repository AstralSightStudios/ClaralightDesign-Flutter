import Cocoa
import FlutterMacOS

public final class ClaralightUiPlugin: NSObject, FlutterPlugin {
  private static let channelName = "dev.claralight.ui/haptics"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    let instance = ClaralightUiPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "selectionClick":
      NSHapticFeedbackManager.defaultPerformer.perform(
        .alignment,
        performanceTime: .now
      )
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
