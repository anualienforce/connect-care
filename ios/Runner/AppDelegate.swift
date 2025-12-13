import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Disable dynamic type scaling
    if #available(iOS 11.0, *) {
      let window = UIApplication.shared.windows.first
      window?.overrideUserInterfaceStyle = .light
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
