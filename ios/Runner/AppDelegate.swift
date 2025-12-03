import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Firebase 初期化
    FirebaseApp.configure()

    // プッシュ通知のデリゲートを設定
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self

    // プッシュ通知の許可をリクエスト
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if let error = error {
        print("🔔 プッシュ通知の許可リクエストエラー: \(error.localizedDescription)")
      } else {
        print("🔔 プッシュ通知の許可: \(granted ? "許可" : "拒否")")
      }
    }

    // リモート通知の登録
    application.registerForRemoteNotifications()

    // FlutterFire 自動生成プラグインを登録
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNsトークンの取得成功時
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("🔔 APNsデバイストークン取得成功")
    Messaging.messaging().apnsToken = deviceToken
  }

  // APNsトークンの取得失敗時
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("🔔 APNsデバイストークン取得失敗: \(error.localizedDescription)")
  }

  // フォアグラウンドで通知を受信した時
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("🔔 フォアグラウンドで通知を受信: \(userInfo)")

    // フォアグラウンドでも通知を表示
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      completionHandler([[.alert, .badge, .sound]])
    }
  }

  // 通知をタップした時
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("🔔 通知をタップ: \(userInfo)")
    completionHandler()
  }

  // FCMトークンの取得時
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🔔 FCMトークン取得: \(fcmToken ?? "nil")")
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}
