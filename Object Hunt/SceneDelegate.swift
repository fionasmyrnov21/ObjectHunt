import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.attachWindow(window)
        } else {
            window.rootViewController = LaunchLoaderViewController()
            window.makeKeyAndVisible()
        }

        if let response = connectionOptions.notificationResponse {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.handleSceneNotificationResponse(response)
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NotificationHandler.shared.clearBadgeOnly()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NotificationHandler.shared.clearBadgeOnly()
    }
}
