import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
  ) -> Bool {

    // Firebase 初期化
    FirebaseApp.configure()

    // デリゲート設定
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self

    // 通知の許可をリクエスト
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      if let error = error {
        print("🔔 通知許可リクエストエラー: \(error.localizedDescription)")
      } else {
        print("🔔 通知許可: \(granted ? "許可" : "拒否")")
      }
    }

    // APNs登録
    application.registerForRemoteNotifications()

    // FlutterFire プラグイン登録
    GeneratedPluginRegistrant.register(with: self)

    // MethodChannel設定（windowが設定された後に実行）
    DispatchQueue.main.async { [weak self] in
      guard let self = self,
            let controller = self.window?.rootViewController as? FlutterViewController else {
        return
      }
      
      let settingsChannel = FlutterMethodChannel(
        name: "com.example.spotlight/settings",
        binaryMessenger: controller.binaryMessenger
      )
      
      settingsChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        guard call.method == "openAppSettings" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.openAppSettings()
        result(nil)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func openAppSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
    }
  }

  // MARK: - APNs Token

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("🔔 APNsデバイストークン取得成功")
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("🔔 APNsデバイストークン取得失敗: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // MARK: - UNUserNotificationCenterDelegate

  // アプリがフォアグラウンドの時にも通知を表示
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("🔔 フォアグラウンド通知受信: \(userInfo)")

    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }

  // 通知タップ時の動作
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("🔔 通知タップ: \(userInfo)")
    completionHandler()
  }

  // MARK: - Firebase Messaging Delegate

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔔 FCMトークン取得: \(fcmToken ?? "nil")")

    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: ["token": fcmToken ?? ""]
    )
  }
}
