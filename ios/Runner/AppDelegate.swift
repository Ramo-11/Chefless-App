import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set this AppDelegate as the UNUserNotificationCenter delegate.
    //
    // This is required for two things:
    //   1. Firebase Messaging's onMessage Dart stream to fire when a push
    //      arrives while the app is in the foreground.
    //   2. The system to display notification banners (sound + badge) while
    //      the app is foregrounded — iOS suppresses them by default.
    //
    // Must be set BEFORE super.application(...) so that FlutterAppDelegate
    // can forward delegate callbacks to registered plugins (firebase_messaging).
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Plugins are registered via the implicit engine delegate (scene-based lifecycle).
  // This runs after the Flutter engine is ready, before Dart main() executes.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Present notifications as visible banners with sound and badge even when
  // the app is in the foreground. Without this override iOS silently drops
  // them and firebase_messaging's onMessage callback never fires.
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
