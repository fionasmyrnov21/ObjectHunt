import UIKit

final class OrientationController {
    static let shared = OrientationController()

    private var currentToken: UInt64 = 0

    private init() {}

    func lockToPortrait() {
        applyOrientationMask(.portrait)
    }

    func unlockAllOrientations() {
        applyOrientationMask(contentFlowMask())
    }

    func setOrientationLock(_ mask: UIInterfaceOrientationMask) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.orientationLock = mask
    }

    private func applyOrientationMask(_ mask: UIInterfaceOrientationMask) {
        setOrientationLock(mask)

        currentToken &+= 1
        let token = currentToken

        let work: () -> Void = { [weak self] in
            self?.applyIfStillCurrent(mask: mask, token: token)
        }

        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.applyIfStillCurrent(mask: mask, token: token)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.applyIfStillCurrent(mask: mask, token: token)
        }
    }

    private func applyIfStillCurrent(mask: UIInterfaceOrientationMask, token: UInt64) {
        guard token == currentToken else { return }
        notifyControllersAndScene(mask: mask)
    }

    private func notifyControllersAndScene(mask: UIInterfaceOrientationMask) {
        guard let scene = activeWindowScene() else { return }

        for window in scene.windows {
            if let root = window.rootViewController {
                visit(root) { vc in
                    vc.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        }

        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
        scene.requestGeometryUpdate(preferences) { _ in }
    }

    private func visit(_ controller: UIViewController, _ action: (UIViewController) -> Void) {
        action(controller)
        for child in controller.children {
            visit(child, action)
        }
        if let presented = controller.presentedViewController {
            visit(presented, action)
        }
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return active
        }
        return scenes.first
    }

    private func contentFlowMask() -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}
