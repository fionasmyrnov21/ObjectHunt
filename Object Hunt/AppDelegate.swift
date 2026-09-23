import UIKit
import SwiftUI
import UserNotifications
import Network
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var orientationLock: UIInterfaceOrientationMask = .portrait

    private var conversionData: [String: Any]?
    private var deepLinkData: [String: Any]?
    private var didPrintMergedPayload = false
    private var isWaitingForGCDConversion = false
    private var mergeTimerWorkItem: DispatchWorkItem?
    private var didStartAppsFlyer = false
    private var launchInternetMonitor: NWPathMonitor?
    private var launchStateObservation: NSKeyValueObservation?
    private var mainNavigationController: UINavigationController?
    private weak var rootPortal: ContentPortalController?
    private var isLaunchLoaderActive = true
    private var launchLoaderFinishWorkItem: DispatchWorkItem?
    private var launchLoaderDuration: TimeInterval { AppConstants.launchLoaderDuration }
    private var didReceiveConfigResponse = false
    private var expectsPortalDestination = false
    private var hasSatisfiedNetworkPath = false
    private var isConfigRequestInFlight = false
    private var consumedLaunchPushAddress: String?
    private var foregroundPushEnrichmentIDs = Set<String>()
    private let richPushIdentifierPrefix = "ar-rich-"

    private let lastSentPushTokenKey = "last_sent_push_token_in_config"
    private var lastSentPushTokenInConfig: String? {
        get { UserDefaults.standard.string(forKey: lastSentPushTokenKey) }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: lastSentPushTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastSentPushTokenKey)
            }
        }
    }

    private var didAttachWindow = false
    private var shouldContinueLaunchAfterAttach = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, directory: nil)
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        LaunchState.shared.resetPersistentStateOnFreshInstallIfNeeded()
        clearTemporaryForceNativeIfNeeded()
        NotificationHandler.shared.clearBadgeOnly()
        NotificationHandler.shared.refreshPushGrantedFromSystem()
        NotificationHandler.shared.registerForRemoteNotificationsIfAuthorized()
        performLaunchInternetCheck()
        observeLaunchState()

        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleLaunchPushNotification(remoteNotification)
        }

        if LaunchState.shared.isPermanentNativeFlow() {
            didReceiveConfigResponse = true
            shouldContinueLaunchAfterAttach = false
        } else {
            shouldContinueLaunchAfterAttach = true
        }

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    private func clearTemporaryForceNativeIfNeeded() {
        let key = "frameonce_cleared_force_native_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
    }

    func attachWindow(_ window: UIWindow) {
        self.window = window
        didAttachWindow = true

        let host = UIHostingController(rootView: RootView())
        let navigationController = UINavigationController(rootViewController: host)
        navigationController.isNavigationBarHidden = true
        mainNavigationController = navigationController

        window.rootViewController = LaunchLoaderViewController()
        window.makeKeyAndVisible()
        PortalPageAgent.shared.prewarm()

        scheduleLaunchLoaderFinish()

        if shouldContinueLaunchAfterAttach {
            shouldContinueLaunchAfterAttach = false
            continueLaunchFlow()
        } else {
            updateLaunchPresentation()
        }
    }

    func handleSceneNotificationResponse(_ response: UNNotificationResponse) {
        handleRemoteNotificationUserInfo(response.notification.request.content.userInfo, fromUserTap: true)
    }

    private func scheduleLaunchLoaderFinish() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let state = LaunchState.shared
            let waitingForPushPortal = state.hasPendingPushDestination()
                || state.didOpenPushDestination
                || state.pendingDestination != nil

            if !self.didReceiveConfigResponse
                && state.portalDestination == nil
                && !self.expectsPortalDestination
                && !waitingForPushPortal {
                if state.activateStoredDestinationIfValid() == false {
                    state.showNoInternetMessage()
                }
            } else if state.portalDestination == nil
                        && (state.hasPendingPushDestination() || state.didOpenPushDestination) {
                _ = state.activateStoredDestinationIfValid()
            }

            self.updateLaunchPresentation()
        }
        launchLoaderFinishWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + launchLoaderDuration, execute: workItem)
    }

    private func cancelLoaderSafetyTimeout() {
        launchLoaderFinishWorkItem?.cancel()
        launchLoaderFinishWorkItem = nil
    }

    private func updateLaunchPresentation() {
        guard let window = window, let navigationController = mainNavigationController else { return }
        let state = LaunchState.shared

        if isLaunchLoaderActive {
            if state.noInternetMessage != nil {
                isLaunchLoaderActive = false
                cancelLoaderSafetyTimeout()
                showNoInternetScreen()
                return
            }

            if let destination = state.portalDestination {
                isLaunchLoaderActive = false
                expectsPortalDestination = false
                cancelLoaderSafetyTimeout()
                OrientationController.shared.unlockAllOrientations()
                switchRootToPortal(
                    window: window,
                    destination: destination,
                    forceReload: LaunchState.shared.consumeForcePortalReload()
                )
                return
            }

            if state.isPrePermissionVisible {
                cancelLoaderSafetyTimeout()
                showNotificationPermissionScreen()
                return
            }

            if expectsPortalDestination || state.pendingDestination != nil {
                return
            }

            if state.hasPendingPushDestination() {
                _ = state.activateStoredDestinationIfValid()
            }
            if state.didOpenPushDestination || state.pendingDestination != nil || state.portalDestination != nil {
                return
            }

            if didReceiveConfigResponse {
                isLaunchLoaderActive = false
                cancelLoaderSafetyTimeout()
                switchRootToNative(window: window, navigationController: navigationController)
                return
            }

            return
        }

        if let destination = state.portalDestination {
            OrientationController.shared.unlockAllOrientations()
            presentPortalDestination(destination, forceReload: LaunchState.shared.consumeForcePortalReload())
        } else if state.isPrePermissionVisible {
            showNotificationPermissionScreen()
        } else if state.noInternetMessage != nil {
            showNoInternetScreen()
        } else {
            ContentPresenter.shared.dismiss()
            OrientationController.shared.lockToPortrait()
        }
    }

    private func switchRootToPortal(window: UIWindow, destination: String, forceReload: Bool = false) {
        OrientationController.shared.unlockAllOrientations()

        if let existing = rootPortal {
            if (forceReload || existing.destination != destination), let address = URL(string: destination) {
                existing.destination = destination
                existing.reload(address: address)
            }
            if window.rootViewController !== existing {
                existing.presentingViewController?.dismiss(animated: false)
                UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
                    window.rootViewController = existing
                })
            }
            return
        }

        let portal = ContentPortalController()
        portal.destination = destination
        rootPortal = portal

        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
            window.rootViewController = portal
        }, completion: { _ in
            OrientationController.shared.unlockAllOrientations()
            portal.setNeedsUpdateOfSupportedInterfaceOrientations()
            UIViewController.attemptRotationToDeviceOrientation()
        })
    }

    private func switchRootToNative(window: UIWindow, navigationController: UINavigationController) {
        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
            window.rootViewController = navigationController
        })
    }

    private func presentPortalDestination(_ destination: String, forceReload: Bool = false) {
        guard let window = window else { return }

        if let portal = window.rootViewController as? ContentPortalController {
            rootPortal = portal
            ContentPresenter.shared.present(destination: destination, forceReload: forceReload)
            return
        }

        if window.rootViewController?.presentedViewController != nil {
            window.rootViewController?.dismiss(animated: false) { [weak self] in
                guard let self = self, let window = self.window else { return }
                self.switchRootToPortal(window: window, destination: destination, forceReload: forceReload)
            }
        } else {
            switchRootToPortal(window: window, destination: destination, forceReload: forceReload)
        }
    }

    private func showNoInternetScreen() {
        guard let window = window else { return }
        if window.rootViewController is NoInternetViewController { return }

        OrientationController.shared.unlockAllOrientations()

        if window.rootViewController?.presentedViewController != nil {
            window.rootViewController?.dismiss(animated: false)
        }

        let noInternetVC = NoInternetViewController()
        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve, animations: {
            window.rootViewController = noInternetVC
        })
    }

    private func observeLaunchState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLaunchStateChange),
            name: LaunchState.didChangeNotification,
            object: nil
        )
    }

    @objc private func handleLaunchStateChange() {
        updateLaunchPresentation()
    }

    private func showNotificationPermissionScreen() {
        guard let topVC = topmostController() else { return }
        guard !topVC.isBeingPresented, !topVC.isBeingDismissed else { return }

        if topVC is PushPermissionViewController { return }
        if topVC.presentedViewController is PushPermissionViewController { return }

        let permissionVC = PushPermissionViewController()
        permissionVC.modalPresentationStyle = .fullScreen
        permissionVC.onAccept = { [weak self, weak permissionVC] in
            NotificationHandler.shared.requestSystemPermission { _ in
                self?.dismissPermissionScreenIfNeeded(permissionVC) {
                    LaunchState.shared.confirmPrePermissionAndOpen()
                }
            }
        }
        permissionVC.onSkip = { [weak self, weak permissionVC] in
            NotificationHandler.shared.registerLastDecline()
            self?.dismissPermissionScreenIfNeeded(permissionVC) {
                LaunchState.shared.confirmPrePermissionAndOpen()
            }
        }

        topVC.present(permissionVC, animated: true)
    }

    private func dismissPermissionScreenIfNeeded(
        _ permissionVC: PushPermissionViewController?,
        completion: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            guard let permissionVC, permissionVC.presentingViewController != nil else {
                completion()
                return
            }
            permissionVC.dismiss(animated: true, completion: completion)
        }
    }

    private func topmostController() -> UIViewController? {
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private func performLaunchInternetCheck() {
        let monitor = NWPathMonitor()
        launchInternetMonitor = monitor
        var didDeliverInitialPath = false

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            guard !didDeliverInitialPath else { return }
            didDeliverInitialPath = true

            self.launchInternetMonitor?.cancel()
            self.launchInternetMonitor = nil

            if path.status == .satisfied {
                DispatchQueue.main.async {
                    self.hasSatisfiedNetworkPath = true
                }
                return
            }

            DispatchQueue.main.async {
                LaunchState.shared.showNoInternetMessage()
                self.updateLaunchPresentation()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.packagepanic.launchInternetCheck"))
    }

    private func continueLaunchFlow() {
        let state = LaunchState.shared

        if state.hasPendingPushDestination() {
            _ = state.activateStoredDestinationIfValid()
            updateLaunchPresentation()
            requestConfigIfStoredLinkExpired(applyDestinationToCurrentSession: false)
            return
        }

        if state.hasUnexpiredStoredDestination() {
            _ = state.activateStoredDestinationIfValid()
            OrientationController.shared.unlockAllOrientations()
            didReceiveConfigResponse = true
            updateLaunchPresentation()
            return
        }

        if state.didOpenPushDestination || state.portalDestination != nil {
            requestConfigIfStoredLinkExpired(applyDestinationToCurrentSession: false)
            return
        }

        requestConfigIfStoredLinkExpired()
    }

    /// Config is requested only after the saved link has expired.
    /// No response keeps the offline screen. A response chooses a new link or native.
    private func requestConfigIfStoredLinkExpired(applyDestinationToCurrentSession: Bool = true) {
        guard !LaunchState.shared.isPermanentNativeFlow() else { return }
        guard !LaunchState.shared.hasUnexpiredStoredDestination() else { return }
        if let storedPayload = LaunchState.shared.storedConfigPayload() {
            sendMergedPayload(storedPayload, applyDestinationToCurrentSession: applyDestinationToCurrentSession)
            return
        }
        configureAppsFlyerAndStart()
    }

    private func configureAppsFlyerAndStart() {
        AppsFlyerLib.shared().appsFlyerDevKey = AppConstants.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = AppConstants.appsFlyerAppleAppID
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sendLaunch),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        sendLaunch()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationHandler.shared.clearBadgeOnly()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationHandler.shared.clearBadgeOnly()
    }

    @objc func sendLaunch() {
        guard !didStartAppsFlyer else { return }
        didStartAppsFlyer = true

        AppsFlyerLib.shared().start { [weak self] dictionary, error in
            if let error = error {
                self?.showNoInternetMessageIfNeeded(error)
                return
            }
            _ = dictionary
        }

    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if LaunchState.shared.portalDestination != nil || isPortalPresented(in: window) {
            return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
        }
        if isRotatableLaunchScreenVisible(in: window) {
            return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
        }
        return orientationLock
    }

    private func isRotatableLaunchScreenVisible(in window: UIWindow?) -> Bool {
        guard var top = window?.rootViewController ?? self.window?.rootViewController else { return false }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top is LaunchLoaderViewController
            || top is PushPermissionViewController
            || top is NoInternetViewController
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        AppsFlyerLib.shared().registerUninstall(deviceToken)
        NotificationHandler.shared.markPushGranted()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        _ = error
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        _ = userInfo
        completionHandler(.newData)
    }

    private func handleRemoteNotificationUserInfo(_ userInfo: [AnyHashable: Any], fromUserTap: Bool) {
        guard fromUserTap else { return }
        guard !LaunchState.shared.isPermanentNativeFlow() else { return }

        guard let addressString = extractPushAddress(from: userInfo) else {
            DispatchQueue.main.async {
                if LaunchState.shared.openStoredConfigDestination() {
                    self.updateLaunchPresentation()
                }
            }
            return
        }

        if consumedLaunchPushAddress == addressString {
            consumedLaunchPushAddress = nil
            return
        }

        DispatchQueue.main.async {
            LaunchState.shared.handleIncomingPushAddress(addressString)
            self.updateLaunchPresentation()
        }
    }

    private func handleLaunchPushNotification(_ userInfo: [AnyHashable: Any]) {
        guard !LaunchState.shared.isPermanentNativeFlow() else {
            return
        }
        // Push without URL: fall through to normal config activation on cold start.
        guard let addressString = extractPushAddress(from: userInfo) else {
            return
        }

        consumedLaunchPushAddress = addressString
        LaunchState.shared.savePushDestination(addressString)
    }

    private func pushImageAddress(in userInfo: [AnyHashable: Any]) -> String? {
        let keys = [
            "image",
            "image_url",
            "imageUrl",
            "picture",
            "thumbnail",
            "media_url",
            "media-url",
            "banner",
            "banner_url",
            "bannerUrl",
            "img",
            "attachment-url",
            "attachment_url",
            "gcm.n.image",
            "gcm.notification.image",
            "google.c.a.c_image"
        ]
        for key in keys {
            if let address = validPushAddress(from: userInfo[key]) {
                return address
            }
        }
        if let fcmOptions = parsedDictionary(userInfo["fcm_options"]) {
            if let address = validPushAddress(from: fcmOptions["image"]) ?? validPushAddress(from: fcmOptions["imageUrl"]) {
                return address
            }
        }
        if let data = parsedDictionary(userInfo["data"]) {
            for key in keys {
                if let address = validPushAddress(from: data[key]) {
                    return address
                }
            }
        }
        if let message = parsedDictionary(userInfo["message"]) {
            if let address = validPushAddress(from: message["image"]) {
                return address
            }
            if let data = parsedDictionary(message["data"]) {
                for key in keys {
                    if let address = validPushAddress(from: data[key]) {
                        return address
                    }
                }
            }
        }
        return recursivePushImageAddress(in: userInfo)
    }

    private func recursivePushImageAddress(in value: Any) -> String? {
        if let dictionary = value as? [AnyHashable: Any] {
            for (key, nestedValue) in dictionary {
                if let key = key as? String,
                   isPushImageKey(key),
                   let address = validPushAddress(from: nestedValue) {
                    return address
                }
                if let address = recursivePushImageAddress(in: nestedValue) {
                    return address
                }
            }
        }

        if let array = value as? [Any] {
            for item in array {
                if let address = recursivePushImageAddress(in: item) {
                    return address
                }
            }
        }

        return nil
    }

    private func isPushImageKey(_ key: String) -> Bool {
        let lowercased = key.lowercased()
        return lowercased.contains("image")
            || lowercased.contains("picture")
            || lowercased.contains("thumbnail")
            || lowercased.contains("banner")
            || lowercased.contains("media")
    }

    private func presentForegroundPushNotification(
        _ notification: UNNotification,
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let requestID = notification.request.identifier

        if requestID.hasPrefix(richPushIdentifierPrefix) || !content.attachments.isEmpty {
            completionHandler([.banner, .list, .sound, .badge])
            return
        }

        guard let imageAddressString = pushImageAddress(in: content.userInfo),
              let imageAddress = URL(string: imageAddressString) else {
            completionHandler([.banner, .list, .sound, .badge])
            return
        }

        guard !foregroundPushEnrichmentIDs.contains(requestID) else {
            completionHandler([.banner, .list, .sound, .badge])
            return
        }

        foregroundPushEnrichmentIDs.insert(requestID)

        completionHandler([.banner, .list, .sound, .badge])

        downloadPushImageAttachment(from: imageAddress) { [weak self] attachment in
            guard let self else { return }
            defer { self.foregroundPushEnrichmentIDs.remove(requestID) }

            guard let attachment else {
                return
            }

            let mutable = UNMutableNotificationContent()
            mutable.title = content.title
            mutable.body = content.body
            mutable.subtitle = content.subtitle
            mutable.userInfo = content.userInfo
            mutable.sound = content.sound
            mutable.badge = content.badge
            mutable.attachments = [attachment]

            let richID = self.richPushIdentifierPrefix + requestID
            let request = UNNotificationRequest(
                identifier: richID,
                content: mutable,
                trigger: nil
            )
            DispatchQueue.main.async {
                UNUserNotificationCenter.current().add(request) { error in
                    if let error {
                        return
                    }
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [requestID])
                }
            }
        }
    }

    private func downloadPushImageAttachment(from address: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        var request = URLRequest(url: address, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.timeoutInterval = 10
        request.setValue(
            PortalPageAgent.shared.cachedValue() ?? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("image/jpeg,image/png,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(nil)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            guard let data,
                  !data.isEmpty,
                  ((200...299).contains(statusCode) || (statusCode < 0 && error == nil)),
                  let image = UIImage(data: data),
                  let jpegData = image.jpegData(compressionQuality: 0.85),
                  jpegData.count <= 10 * 1024 * 1024 else {
                completion(nil)
                return
            }

            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PushAttachments", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let fileAddress = directory.appendingPathComponent("image.jpg")

            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try jpegData.write(to: fileAddress, options: [.atomic])
                let attachment = try UNNotificationAttachment(
                    identifier: "image",
                    url: fileAddress,
                    options: [UNNotificationAttachmentOptionsTypeHintKey: "public.jpeg"]
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    private func extractPushAddress(from userInfo: [AnyHashable: Any]) -> String? {
        if let address = validPushAddress(from: userInfo[AppConstants.pushDataAddressKey]) {
            return address
        }

        if let data = parsedDictionary(userInfo["data"]),
           let address = validPushAddress(from: data[AppConstants.pushDataAddressKey]) {
            return address
        }

        if let message = parsedDictionary(userInfo["message"]) {
            if let address = validPushAddress(from: message[AppConstants.pushDataAddressKey]) {
                return address
            }
            if let data = parsedDictionary(message["data"]),
               let address = validPushAddress(from: data[AppConstants.pushDataAddressKey]) {
                return address
            }
        }

        return nil
    }

    private func parsedDictionary(_ value: Any?) -> [AnyHashable: Any]? {
        if let dictionary = value as? [AnyHashable: Any] {
            return dictionary
        }
        if let string = value as? String,
           let data = string.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let dictionary = json as? [AnyHashable: Any] {
            return dictionary
        }
        return nil
    }

    private func validPushAddress(from value: Any?) -> String? {
        guard let string = value as? String, isValidWebAddress(string) else { return nil }
        return string
    }

    private func isValidWebAddress(_ value: String) -> Bool {
        guard let address = URL(string: value), let scheme = address.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme)
    }

    private func printMergedPayloadIfNeeded(force: Bool = false) {
        guard !didPrintMergedPayload else { return }
        guard !isWaitingForGCDConversion else { return }

        let hasConversion = conversionData != nil
        let hasDeepLink = deepLinkData != nil

        guard hasConversion else {
            return
        }

        let bothReady = hasConversion && hasDeepLink
        let canPrint = bothReady || (force && (hasConversion || hasDeepLink))

        guard canPrint else {
            if hasConversion || hasDeepLink {
                scheduleMergeTimeout()
            }
            return
        }

        mergeTimerWorkItem?.cancel()
        mergeTimerWorkItem = nil
        didPrintMergedPayload = true

        var merged: [String: Any] = deepLinkData ?? [:]
        if let conversion = conversionData {
            for (key, value) in conversion {
                merged[key] = value
            }
        }

        finalizeAndSendMergedPayload(merged)
    }

    private func handleConversionData(_ data: [String: Any], shouldRetryOrganicWithGCD: Bool) {
        let status = data["af_status"] as? String
        let isOrganic = status?.localizedCaseInsensitiveCompare("Organic") == .orderedSame

        if isOrganic && shouldRetryOrganicWithGCD {
            isWaitingForGCDConversion = true
            cancelMergeTimeout()
                        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.gcdRetryDelay) { [weak self] in
                self?.fetchGCDConversionData(fallback: data)
            }
            return
        }

        conversionData = data

        printMergedPayloadIfNeeded()
    }

    private func fetchGCDConversionData(fallback: [String: Any]) {
        fetchGCDConversionData(
            fallback: fallback,
            candidates: gcdDeviceIDCandidates(),
            index: 0
        )
    }

    private func gcdDeviceIDCandidates() -> [(label: String, value: String)] {
        var candidates: [(label: String, value: String)] = [
            ("appsFlyerUID", AppsFlyerLib.shared().getAppsFlyerUID())
        ]

        if let idfv = UIDevice.current.identifierForVendor?.uuidString,
           !idfv.isEmpty {
            candidates.append(("idfv", idfv))
        }

        return candidates
    }

    private func fetchGCDConversionData(fallback: [String: Any], candidates: [(label: String, value: String)], index: Int) {
        guard index < candidates.count else {
            finishGCDConversionData(fallback)
            return
        }

        let candidate = candidates[index]
        var components = URLComponents()
        components.scheme = "https"
        components.host = "gcdsdk.appsflyer.com"
        components.path = "/install_data/v4.0/\(AppConstants.storeID)"
        components.queryItems = [
            URLQueryItem(name: "devkey", value: AppConstants.appsFlyerDevKey),
            URLQueryItem(name: "device_id", value: candidate.value)
        ]

        guard let address = components.url else {
            finishGCDConversionData(fallback)
            return
        }

        var request = URLRequest(url: address, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.showNoInternetMessageIfNeeded(error)
                DispatchQueue.main.async {
                    self?.finishGCDConversionData(fallback)
                }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if statusCode == 404, index + 1 < candidates.count {
                self?.fetchGCDConversionData(fallback: fallback, candidates: candidates, index: index + 1)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data),
                  let payload = json as? [String: Any] else {
                DispatchQueue.main.async {
                    self?.finishGCDConversionData(fallback)
                }
                return
            }

            var safePayload: [String: Any] = [:]
            for (key, value) in payload {
                safePayload[key] = self?.jsonSafeValue(value) ?? value
            }

            DispatchQueue.main.async {
                self?.finishGCDConversionData(safePayload)
            }
        }.resume()
    }

    private func finishGCDConversionData(_ data: [String: Any]) {
        isWaitingForGCDConversion = false
        conversionData = data
        printMergedPayloadIfNeeded()
    }

    private func injectTemplateFields(into merged: inout [String: Any]) {
        let templateKeys: [String: Any] = [
            "af_id": AppsFlyerLib.shared().getAppsFlyerUID(),
            "bundle_id": AppConstants.bundleID,
            "os": AppConstants.osName,
            "store_id": AppConstants.storeID,
            "locale": currentLocaleRFC3066(),
            "push_token": NotificationHandler.shared.currentPushToken(),
            "firebase_project_id": AppConstants.firebaseProjectID
        ]
        for (key, value) in templateKeys {
            merged[key] = value
        }
    }

    private func finalizeAndSendMergedPayload(_ mergedBeforeTemplate: [String: Any]) {
        var merged = mergedBeforeTemplate
        injectTemplateFields(into: &merged)
        
        let flat = flattenedPayload(merged)
        LaunchState.shared.saveConfigPayload(flat)
        sendMergedPayload(flat)
    }

    private func flattenedPayload(_ payload: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (_, value) in payload {
            if let nested = value as? [String: Any] {
                for (nestedKey, nestedValue) in nested {
                    result[nestedKey] = nestedValue
                }
            }
        }
        for (key, value) in payload where !(value is [String: Any]) {
            result[key] = value
        }
        return result
    }

    private func sendMergedPayload(
        _ payload: [String: Any],
        applyDestinationToCurrentSession: Bool = true,
        attempt: Int = 0
    ) {
        guard !LaunchState.shared.isPermanentNativeFlow() else { return }
        guard let address = URL(string: AppConstants.configEndpoint) else { return }
        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return
        }

        if let token = payload["push_token"] as? String,
           !token.isEmpty,
           token != AppConstants.pushTokenPlaceholder {
            lastSentPushTokenInConfig = token
        }

        let timeouts = AppConstants.configRequestTimeouts
        let totalAttempts = max(timeouts.count, 1)
        let timeout = timeouts[min(attempt, totalAttempts - 1)]

        var request = URLRequest(url: address, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.httpBody = body
        request.timeoutInterval = timeout

        isConfigRequestInFlight = true
        print("[Config] POST \(AppConstants.configEndpoint) attempt \(attempt + 1)/\(totalAttempts) timeout=\(Int(timeout))s")
        if let bodyText = String(data: body, encoding: .utf8) {
            print("[Config] request body: \(bodyText)")
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    print("[Config] error attempt \(attempt + 1): \(error.localizedDescription)")
                    self.retryOrFinishConfigRequest(
                        payload: payload,
                        applyDestinationToCurrentSession: applyDestinationToCurrentSession,
                        attempt: attempt,
                        timeouts: timeouts,
                        totalAttempts: totalAttempts
                    )
                    return
                }

                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty>"
                print("[Config] response status=\(status) attempt \(attempt + 1): \(responseText)")

                // Server may return 404 + { "ok": false } when there is no offer —
                // that is a real decision, not a network failure.
                let hasConfigJSON = Self.isConfigJSONResponse(data)
                let isHTTPSuccess = (200...299).contains(status)

                guard isHTTPSuccess || hasConfigJSON else {
                    self.retryOrFinishConfigRequest(
                        payload: payload,
                        applyDestinationToCurrentSession: applyDestinationToCurrentSession,
                        attempt: attempt,
                        timeouts: timeouts,
                        totalAttempts: totalAttempts
                    )
                    return
                }

                self.isConfigRequestInFlight = false
                let expectsPortal = self.handleMergedPayloadResponse(
                    data: data,
                    applyDestinationToCurrentSession: applyDestinationToCurrentSession
                )
                print("[Config] parsed expectsPortal=\(expectsPortal) permanentNative=\(LaunchState.shared.isPermanentNativeFlow())")
                self.didReceiveConfigResponse = true
                self.expectsPortalDestination = expectsPortal
                self.updateLaunchPresentation()
            }
        }.resume()
    }

    private static func isConfigJSONResponse(_ data: Data?) -> Bool {
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["ok"] != nil else {
            return false
        }
        return true
    }

    private func retryOrFinishConfigRequest(
        payload: [String: Any],
        applyDestinationToCurrentSession: Bool,
        attempt: Int,
        timeouts: [TimeInterval],
        totalAttempts: Int
    ) {
        if attempt + 1 < totalAttempts {
            let nextTimeout = timeouts[attempt + 1]
            sendMergedPayload(
                payload,
                applyDestinationToCurrentSession: applyDestinationToCurrentSession,
                attempt: attempt + 1
            )
            return
        }
        finishConfigRetriesWithoutResponse(applyDestinationToCurrentSession: applyDestinationToCurrentSession)
    }

    private func finishConfigRetriesWithoutResponse(applyDestinationToCurrentSession: Bool) {
        isConfigRequestInFlight = false
        if applyDestinationToCurrentSession {
            LaunchState.shared.showNoInternetMessage()
        }
        didReceiveConfigResponse = true
        expectsPortalDestination = false
        updateLaunchPresentation()
    }

    @discardableResult
    private func handleMergedPayloadResponse(
        data: Data?,
        applyDestinationToCurrentSession: Bool = true
    ) -> Bool {
        guard !LaunchState.shared.isPermanentNativeFlow() else {
            return false
        }

        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data),
              let payload = json as? [String: Any] else {
            LaunchState.shared.recordFirstServerDecision(hasValidLink: false)
            return false
        }

        let hasOK = (payload["ok"] as? Bool) == true
        let destination = portalDestination(from: payload)
        let expires = portalDestinationExpires(from: payload)
        let hasValidLink = hasOK && destination != nil

        LaunchState.shared.recordFirstServerDecision(hasValidLink: hasValidLink)
        if LaunchState.shared.isPermanentNativeFlow() {
            return false
        }

        guard hasOK else {
            return false
        }

        guard let destination = destination else {
            return false
        }

        let resolvedExpires = expires ?? 0
        DispatchQueue.main.async {
            if applyDestinationToCurrentSession {
                OrientationController.shared.unlockAllOrientations()
                LaunchState.shared.saveDestination(destination, expires: resolvedExpires)
            } else {
                LaunchState.shared.persistDestinationWithoutOpening(destination, expires: resolvedExpires)
            }
        }
        return applyDestinationToCurrentSession
    }

    private func showNoInternetMessageIfNeeded(_ error: Error) {
        guard let networkError = error as? URLError else { return }
        let offlineCodes: [URLError.Code] = [
            .notConnectedToInternet,
            .networkConnectionLost
        ]
        guard offlineCodes.contains(networkError.code) else { return }
        DispatchQueue.main.async {
            guard !self.hasSatisfiedNetworkPath else { return }
            LaunchState.shared.showNoInternetMessage()
        }
    }

    private func portalDestination(from payload: [String: Any]) -> String? {
        let keys = ["url", "link", "destination", "browser_url", "browserUrl"]
        for key in keys {
            if let value = payload[key] as? String,
               let address = URL(string: value),
               let scheme = address.scheme?.lowercased(),
               ["http", "https"].contains(scheme) {
                return value
            }
        }
        if let data = payload["data"] as? [String: Any] {
            return portalDestination(from: data)
        }
        return nil
    }

    private func portalDestinationExpires(from payload: [String: Any]) -> TimeInterval? {
        if let value = payload["expires"] as? TimeInterval {
            return value
        }
        if let value = payload["expires"] as? Int {
            return TimeInterval(value)
        }
        if let value = payload["expires"] as? String,
           let interval = TimeInterval(value) {
            return interval
        }
        if let data = payload["data"] as? [String: Any] {
            return portalDestinationExpires(from: data)
        }
        return nil
    }

    private func scheduleMergeTimeout() {
        guard mergeTimerWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.mergeTimerWorkItem = nil
            self?.printMergedPayloadIfNeeded(force: true)
        }
        mergeTimerWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.mergeWaitInterval, execute: workItem)
    }

    private func cancelMergeTimeout() {
        mergeTimerWorkItem?.cancel()
        mergeTimerWorkItem = nil
    }

    private func currentLocaleRFC3066() -> String {
        if let preferred = Locale.preferredLanguages.first, !preferred.isEmpty {
            return preferred
        }
        return Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    }

    fileprivate func jsonSafeValue(_ value: Any) -> Any {
        if let date = value as? Date {
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: date)
        }
        if let address = value as? URL {
            return address.absoluteString
        }
        if let dict = value as? [AnyHashable: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dict {
                guard let stringKey = key as? String else { continue }
                result[stringKey] = jsonSafeValue(value)
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map { jsonSafeValue($0) }
        }
        if value is NSNull { return NSNull() }
        if JSONSerialization.isValidJSONObject([value]) {
            return value
        }
        if value is NSNumber || value is String || value is Bool || value is Int || value is Double {
            return value
        }
        return "\(value)"
    }

    private func isPortalPresented(in window: UIWindow?) -> Bool {
        if let root = window?.rootViewController {
            return containsPortalController(in: root)
        }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for sceneWindow in scene.windows where containsPortalController(in: sceneWindow.rootViewController) {
                return true
            }
        }
        return false
    }

    private func containsPortalController(in root: UIViewController?) -> Bool {
        guard var top = root else { return false }
        if top is ContentPortalController {
            return true
        }
        while let presented = top.presentedViewController {
            if presented is ContentPortalController {
                return true
            }
            top = presented
        }
        return false
    }

}

extension AppDelegate: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ installData: [AnyHashable: Any]) {
        var stringKeyed: [String: Any] = [:]
        for (key, value) in installData {
            guard let stringKey = key as? String else { continue }
            stringKeyed[stringKey] = jsonSafeValue(value)
        }
        handleConversionData(stringKeyed, shouldRetryOrganicWithGCD: true)
    }

    func onConversionDataFail(_ error: Error) {
        showNoInternetMessageIfNeeded(error)
        printMergedPayloadIfNeeded()
    }
}

extension AppDelegate: DeepLinkDelegate {
    func didResolveDeepLink(_ result: DeepLinkResult) {
        switch result.status {
        case .notFound, .failure:
            deepLinkData = [:]
            printMergedPayloadIfNeeded()
            return
        case .found:
            break
        @unknown default:
            deepLinkData = [:]
            printMergedPayloadIfNeeded()
            return
        }

        guard let deepLinkObj: DeepLink = result.deepLink else {
            printMergedPayloadIfNeeded()
            return
        }

        var jsonPayload: [String: Any] = [:]
        jsonPayload["isDeferred"] = deepLinkObj.isDeferred
        for (key, value) in deepLinkObj.clickEvent {
            jsonPayload[key] = jsonSafeValue(value)
        }
        if let deepLinkValue = deepLinkObj.deeplinkValue {
            jsonPayload["deep_link_value"] = deepLinkValue
        }
        if let matchType = deepLinkObj.matchType {
            jsonPayload["match_type"] = matchType
        }
        if let mediaSource = deepLinkObj.mediaSource {
            jsonPayload["media_source"] = mediaSource
        }
        if let campaign = deepLinkObj.campaign {
            jsonPayload["campaign"] = campaign
        }
        if let campaignId = deepLinkObj.campaignId {
            jsonPayload["campaign_id"] = campaignId
        }

        deepLinkData = jsonPayload
        printMergedPayloadIfNeeded()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            return
        }
        NotificationHandler.shared.storeFcmToken(fcmToken)
        resendConfigWithUpdatedPushTokenIfNeeded(fcmToken)
    }

    private func resendConfigWithUpdatedPushTokenIfNeeded(_ token: String) {
        guard !LaunchState.shared.isPermanentNativeFlow() else { return }
        guard !LaunchState.shared.hasUnexpiredStoredDestination() else { return }

        guard !token.isEmpty,
              token != AppConstants.pushTokenPlaceholder else {
            return
        }

        guard NotificationHandler.shared.isPushGranted() else {
            return
        }

        if token == lastSentPushTokenInConfig {
            return
        }

        guard var storedPayload = LaunchState.shared.storedConfigPayload() else {
            return
        }

        storedPayload["push_token"] = token
        LaunchState.shared.saveConfigPayload(storedPayload)
        lastSentPushTokenInConfig = token

        sendMergedPayload(storedPayload, applyDestinationToCurrentSession: false)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        presentForegroundPushNotification(notification, completionHandler: completionHandler)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        handleRemoteNotificationUserInfo(content.userInfo, fromUserTap: true)
        completionHandler()
    }
}
