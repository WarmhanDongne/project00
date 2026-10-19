import Flutter
import CoreMotion
import Foundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YutMotionPlugin") {
      YutMotionPlugin.register(with: registrar)
    }
  }
}

final class YutMotionPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let motionManager = CMMotionManager()
  private var eventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = YutMotionPlugin()
    let channel = FlutterEventChannel(
      name: "mosigame/yut_motion/events",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(instance)
    registrar.publish(instance)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard motionManager.isAccelerometerAvailable else {
      return FlutterError(code: "motion_unavailable", message: "Accelerometer unavailable", details: nil)
    }
    eventSink = events
    motionManager.accelerometerUpdateInterval = 0.05
    motionManager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] data, error in
      guard let self = self, let acceleration = data?.acceleration, error == nil else { return }
      let scale = 9.80665
      self.eventSink?([
        acceleration.x * scale,
        acceleration.y * scale,
        acceleration.z * scale
      ])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motionManager.stopAccelerometerUpdates()
    eventSink = nil
    return nil
  }
}
