import Foundation
import Combine

final class LaunchState: ObservableObject {
    static let shared = LaunchState()

    static let didChangeNotification = NSNotification.Name("LaunchStateDidChange")

    @Published var portalDestination: String? {
        didSet { notifyChange() }
    }
    @Published var isPrePermissionVisible: Bool = false {
        didSet { notifyChange() }
    }
    @Published var noInternetMessage: String? {
        didSet { notifyChange() }
    }

    private func notifyChange() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: LaunchState.didChangeNotification, object: nil)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: LaunchState.didChangeNotification, object: nil)
            }
        }
    }

    private let destinationKey = "saved_portal_destination"
    private let expiresKey = "saved_portal_destination_expires"
    private let payloadKey = "saved_config_payload"
    private let permanentNativeKey = "permanent_native_flow"
    private let pushDestinationKey = "saved_push_destination"
    private let lastOpenedDestinationKey = "last_opened_destination"
    private let installMarkerKey = "app_install_initialized"
    private let firstServerDecisionRecordedKey = "first_server_decision_recorded"
    private let firstServerDecisionHasLinkKey = "first_server_decision_has_link"

    private(set) var pendingDestination: String?
    private(set) var didOpenPushDestination = false
    private var shouldForcePortalReload = false

    private init() {}

    func resetPersistentStateOnFreshInstallIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: installMarkerKey) else { return }

        defaults.set(true, forKey: installMarkerKey)

        defaults.removeObject(forKey: destinationKey)
        defaults.removeObject(forKey: expiresKey)
        defaults.removeObject(forKey: payloadKey)
        defaults.removeObject(forKey: permanentNativeKey)
        defaults.removeObject(forKey: pushDestinationKey)
        defaults.removeObject(forKey: lastOpenedDestinationKey)
        defaults.removeObject(forKey: firstServerDecisionRecordedKey)
        defaults.removeObject(forKey: firstServerDecisionHasLinkKey)
        defaults.removeObject(forKey: "push_permission_last_decline")
        defaults.removeObject(forKey: "stored_fcm_token")
        defaults.removeObject(forKey: "last_sent_push_token_in_config")
        defaults.removeObject(forKey: "push_permission_granted")

        pendingDestination = nil
        portalDestination = nil
        isPrePermissionVisible = false
        noInternetMessage = nil
        didOpenPushDestination = false
        shouldForcePortalReload = false
    }

    func markDidOpenPushDestination() {
        didOpenPushDestination = true
    }

    func requestForcePortalReload() {
        shouldForcePortalReload = true
    }

    func consumeForcePortalReload() -> Bool {
        let value = shouldForcePortalReload
        shouldForcePortalReload = false
        return value
    }

    func activateStoredDestinationIfValid() -> Bool {
        if isPermanentNativeFlow() {
            clearStoredDestination()
            clearLastOpenedDestination()
            portalDestination = nil
            return false
        }

        if let pushAddress = consumePushDestination() {
            markDidOpenPushDestination()
            requestForcePortalReload()
            saveLastOpenedDestination(pushAddress)
            portalDestination = pushAddress
            return true
        }

        if let lastOpened = lastOpenedDestination(), !lastOpened.isEmpty {
            portalDestination = lastOpened
            return true
        }

        guard let destination = UserDefaults.standard.string(forKey: destinationKey),
              !destination.isEmpty else {
            portalDestination = nil
            return false
        }

        saveLastOpenedDestination(destination)
        portalDestination = destination
        return true
    }

    func isStoredDestinationExpired(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard UserDefaults.standard.string(forKey: destinationKey) != nil else { return true }
        return UserDefaults.standard.double(forKey: expiresKey) <= now
    }

    func saveDestination(_ destination: String, expires: TimeInterval) {
        guard !isPermanentNativeFlow() else { return }
        if didOpenPushDestination {
            persistDestinationWithoutOpening(destination, expires: expires)
            return
        }
        UserDefaults.standard.set(destination, forKey: destinationKey)
        UserDefaults.standard.set(expires, forKey: expiresKey)
        saveLastOpenedDestination(destination)
        prepareToOpenPortal(destination)
    }

    func persistDestinationWithoutOpening(_ destination: String, expires: TimeInterval) {
        guard !isPermanentNativeFlow() else { return }
        UserDefaults.standard.set(destination, forKey: destinationKey)
        UserDefaults.standard.set(expires, forKey: expiresKey)
    }

    func hasStoredDestination() -> Bool {
        guard !isPermanentNativeFlow() else { return false }
        guard let destination = UserDefaults.standard.string(forKey: destinationKey) else {
            return false
        }
        return !destination.isEmpty
    }

    func hasOpenableDestination() -> Bool {
        guard !isPermanentNativeFlow() else { return false }
        if let lastOpened = lastOpenedDestination(), !lastOpened.isEmpty {
            return true
        }
        return hasStoredDestination()
    }

    func lastOpenedDestination() -> String? {
        UserDefaults.standard.string(forKey: lastOpenedDestinationKey)
    }

    func saveLastOpenedDestination(_ address: String) {
        UserDefaults.standard.set(address, forKey: lastOpenedDestinationKey)
    }

    func clearLastOpenedDestination() {
        UserDefaults.standard.removeObject(forKey: lastOpenedDestinationKey)
    }

    func clearStoredDestination() {
        UserDefaults.standard.removeObject(forKey: destinationKey)
        UserDefaults.standard.removeObject(forKey: expiresKey)
    }

    func saveConfigPayload(_ payload: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        UserDefaults.standard.set(data, forKey: payloadKey)
    }

    func storedConfigPayload() -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: payloadKey),
              let json = try? JSONSerialization.jsonObject(with: data),
              let payload = json as? [String: Any] else { return nil }
        return payload
    }

    func isPermanentNativeFlow() -> Bool {
        UserDefaults.standard.bool(forKey: permanentNativeKey)
    }

    func lockPermanentNativeFlow() {
        UserDefaults.standard.set(true, forKey: permanentNativeKey)
        clearStoredDestination()
        clearLastOpenedDestination()
        portalDestination = nil
    }

    func recordFirstServerDecision(hasValidLink: Bool) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstServerDecisionRecordedKey) else { return }

        defaults.set(true, forKey: firstServerDecisionRecordedKey)
        defaults.set(hasValidLink, forKey: firstServerDecisionHasLinkKey)

        if !hasValidLink {
            lockPermanentNativeFlow()
        }
    }

    func showNoInternetMessage() {
        if portalDestination != nil { return }
        if activateStoredDestinationIfValid() { return }
        noInternetMessage = "No internet connection. Please turn on the internet and open the app again."
    }

    func savePushDestination(_ address: String) {
        UserDefaults.standard.set(address, forKey: pushDestinationKey)
        saveLastOpenedDestination(address)
        markDidOpenPushDestination()
    }

    func consumePushDestination() -> String? {
        let address = UserDefaults.standard.string(forKey: pushDestinationKey)
        UserDefaults.standard.removeObject(forKey: pushDestinationKey)
        return address
    }

    func handleIncomingPushAddress(_ address: String) {
        guard !isPermanentNativeFlow() else { return }

        markDidOpenPushDestination()
        requestForcePortalReload()
        UserDefaults.standard.removeObject(forKey: pushDestinationKey)
        saveLastOpenedDestination(address)
        prepareToOpenPortal(address)
    }

    func prepareToOpenPortal(_ destination: String) {
        NotificationHandler.shared.shouldShowPrePermission { [weak self] shouldShow in
            guard let self = self else { return }
            if shouldShow {
                self.pendingDestination = destination
                self.portalDestination = nil
                self.isPrePermissionVisible = true
            } else {
                self.pendingDestination = nil
                self.isPrePermissionVisible = false
                self.portalDestination = destination
            }
        }
    }

    func confirmPrePermissionAndOpen() {
        let target = pendingDestination
        pendingDestination = nil
        isPrePermissionVisible = false
        if let target = target {
            portalDestination = target
        }
    }
}
