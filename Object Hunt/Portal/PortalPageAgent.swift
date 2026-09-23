import WebKit

final class PortalPageAgent {
    static let shared = PortalPageAgent()

    private let storageKey = "portal_device_page_agent"
    private var memoryValue: String?
    private var pendingCompletions: [(String) -> Void] = []
    private var isResolving = false

    private init() {}

    func cachedValue() -> String? {
        if let memoryValue, !memoryValue.isEmpty {
            return memoryValue
        }
        guard let stored = UserDefaults.standard.string(forKey: storageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !stored.isEmpty else {
            return nil
        }
        memoryValue = stored
        return stored
    }

    func prewarm() {
        resolve { _ in }
    }

    func resolve(completion: @escaping (String) -> Void) {
        if let cached = cachedValue() {
            completion(cached)
            return
        }

        pendingCompletions.append(completion)
        guard !isResolving else { return }
        isResolving = true

        DispatchQueue.main.async { [weak self] in
            let probe = WKWebView(frame: .zero)
            probe.evaluateJavaScript("navigator.userAgent") { result, error in
                DispatchQueue.main.async {
                    self?.finishResolve(result: result, error: error)
                }
            }
        }
    }

    private func finishResolve(result: Any?, error: Error?) {
        let trimmed = (result as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let agent = trimmed.isEmpty ? systemFallback() : trimmed
        memoryValue = agent
        UserDefaults.standard.set(agent, forKey: storageKey)
        isResolving = false
        let callbacks = pendingCompletions
        pendingCompletions.removeAll()
        callbacks.forEach { $0(agent) }
    }

    private func systemFallback() -> String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}
