import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static var pendingNotificationAdId: String?
  private static var notificationChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    configureNotificationChannel()

    if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      AppDelegate.openAdFromNotification(remoteNotification)
    }

    return launched
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    AppDelegate.openAdFromNotification(response.notification.request.content.userInfo)
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  private func configureNotificationChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        self.configureNotificationChannel()
      }
      return
    }

    let channel = FlutterMethodChannel(
      name: "yahala/notifications",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      if call.method == "getInitialAdId" {
        result(AppDelegate.pendingNotificationAdId)
        AppDelegate.pendingNotificationAdId = nil
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    AppDelegate.notificationChannel = channel

    if let adId = AppDelegate.pendingNotificationAdId {
      channel.invokeMethod("openAd", arguments: adId)
    }
  }

  private static func openAdFromNotification(_ userInfo: [AnyHashable: Any]) {
    guard let adId = extractAdId(from: userInfo) else {
      return
    }

    pendingNotificationAdId = adId
    notificationChannel?.invokeMethod("openAd", arguments: adId)
  }

  private static func extractAdId(from userInfo: [AnyHashable: Any]) -> String? {
    let value = userInfo["adId"] ?? userInfo["ad_id"] ?? userInfo["id"]
    let adId = "\(value ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)

    return adId.isEmpty ? nil : adId
  }
}
