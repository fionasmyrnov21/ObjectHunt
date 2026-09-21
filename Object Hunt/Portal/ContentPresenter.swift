import UIKit

final class ContentPresenter {
    static let shared = ContentPresenter()

    private weak var presentedController: ContentPortalController?
    private var pendingDestination: String?
    private var pendingForceReload = false
    private var retryAttempts = 0

    private init() {}

    func present(destination: String, forceReload: Bool = false) {
        pendingDestination = destination
        pendingForceReload = forceReload
        retryAttempts = 0
        DispatchQueue.main.async { [weak self] in
            self?.attemptPresent()
        }
    }

    func dismiss() {
        pendingDestination = nil
        pendingForceReload = false
        if let controller = presentedController, controller.presentingViewController != nil {
            controller.dismiss(animated: false)
        }
        presentedController = nil
    }

    private func attemptPresent() {
        guard let destination = pendingDestination else { return }
        let forceReload = pendingForceReload

        if let existing = presentedController, existing.presentingViewController != nil {
            reloadIfNeeded(controller: existing, destination: destination, forceReload: forceReload)
            pendingDestination = nil
            pendingForceReload = false
            return
        }

        guard let topVC = topmostController() else {
            scheduleRetry()
            return
        }

        if let existing = topVC as? ContentPortalController {
            presentedController = existing
            reloadIfNeeded(controller: existing, destination: destination, forceReload: forceReload)
            pendingDestination = nil
            pendingForceReload = false
            return
        }

        if topVC.isBeingPresented || topVC.isBeingDismissed {
            scheduleRetry()
            return
        }

        let controller = ContentPortalController()
        controller.destination = destination
        controller.modalPresentationStyle = .fullScreen
        controller.modalTransitionStyle = .crossDissolve

        OrientationController.shared.unlockAllOrientations()

        topVC.present(controller, animated: false) { [weak self] in
            OrientationController.shared.unlockAllOrientations()
            controller.setNeedsUpdateOfSupportedInterfaceOrientations()
            UIViewController.attemptRotationToDeviceOrientation()
            self?.presentedController = controller
            self?.pendingDestination = nil
            self?.pendingForceReload = false
        }
    }

    private func reloadIfNeeded(controller: ContentPortalController, destination: String, forceReload: Bool) {
        guard forceReload || controller.destination != destination,
              let address = URL(string: destination) else { return }
        controller.destination = destination
        controller.reload(address: address)
    }

    private func scheduleRetry() {
        retryAttempts += 1
        guard retryAttempts < 30 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.attemptPresent()
        }
    }

    private func topmostController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first

        guard let scene = activeScene else { return nil }

        let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        guard var top = keyWindow?.rootViewController else { return nil }

        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
