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

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Explicitly register for remote notifications. The firebase_messaging
    // plugin normally does this when requestPermission() is called from Dart,
    // but with the scene-based lifecycle (FlutterImplicitEngineDelegate) the
    // Dart call can happen too late or the callback can be lost. Calling it
    // here ensures APNs registration starts immediately at launch.
    print("[FCM-DEBUG-NATIVE] didFinishLaunchingWithOptions — calling registerForRemoteNotifications()")
    application.registerForRemoteNotifications()

    return result
  }

  // Plugins are registered via the implicit engine delegate (scene-based lifecycle).
  // This runs after the Flutter engine is ready, before Dart main() executes.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    print("[FCM-DEBUG-NATIVE] didInitializeImplicitFlutterEngine — plugins registered")
  }

  // MARK: - APNs Registration Callbacks

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("[FCM-DEBUG-NATIVE] APNs token RECEIVED (\(deviceToken.count) bytes): \(tokenString.prefix(24))...")

    // Forward to super so firebase_messaging's swizzling picks it up
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[FCM-DEBUG-NATIVE] APNs registration FAILED: \(error.localizedDescription)")
    print("[FCM-DEBUG-NATIVE] Full error: \(error)")

    // Forward to super
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
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
    print("[FCM-DEBUG-NATIVE] willPresent notification: \(notification.request.content.title)")
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // Handle notification tap when app is in background or was terminated.
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let content = response.notification.request.content
    print("[FCM-DEBUG-NATIVE] didReceive notification tap: \(content.title), data: \(content.userInfo)")
    completionHandler()
  }
}
