import UIKit
import WebKit
import AVFoundation
import UniformTypeIdentifiers
import Network

final class ContentPortalController: UIViewController {
    var destination: String = ""

    private var contentView: WKWebView!
    private var loadingOverlay: UIView!
    private var loadingIndicator: UIActivityIndicatorView!
    private var loadingBackgroundImageView: UIImageView!
    private var loadingIndicatorCenterY: NSLayoutConstraint?
    private var navigationCoordinator: ContentNavigationCoordinator!
    private var hasFinishedInitialLoad = false

    private var errorView: UIView?
    private var errorBackgroundImageView: UIImageView?
    private var errorUsesNoInternetArt = false
    private var didAutoRetryAfterFailure = false
    private var hasLoadedMainContent = false
    private var pathMonitor: NWPathMonitor?
    private let pathMonitorQueue = DispatchQueue(label: "com.frameonce.portal.path")

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationCoordinator = ContentNavigationCoordinator(controller: self)
        setupContentView()
        syncCookiesFromStorage()
        setupLoadingOverlay()
        startPathMonitoring()
        applyPageAgentAndLoad()
    }

    deinit {
        pathMonitor?.cancel()
    }

    private func applyPageAgentAndLoad() {
        PortalPageAgent.shared.resolve { [weak self] agent in
            guard let self else { return }
            self.contentView.customUserAgent = agent
            self.loadDestination()
        }
    }

    private func syncCookiesFromStorage() {
        let store = WKWebsiteDataStore.default().httpCookieStore
        for cookie in HTTPCookieStorage.shared.cookies ?? [] {
            store.setCookie(cookie)
        }
    }

    private func startPathMonitoring() {
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: pathMonitorQueue)
    }

    private func handlePathUpdate(_ path: NWPath) {
        if path.status == .satisfied {
            if errorUsesNoInternetArt, errorView?.isHidden == false {
                didAutoRetryAfterFailure = false
                hasFinishedInitialLoad = false
                hasLoadedMainContent = false
                loadingOverlay?.isHidden = false
                loadingOverlay?.alpha = 1
                loadingIndicator?.startAnimating()
                hideErrorView()
                loadDestination()
            }
            return
        }
        showErrorView(noInternet: true)
    }

    private func setupContentView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences

        let disableZoomSource = """
        var meta = document.querySelector('meta[name=viewport]');
        if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            (document.head || document.getElementsByTagName('head')[0]).appendChild(meta);
        }
        meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no');
        """
        let disableZoomScript = WKUserScript(source: disableZoomSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(disableZoomScript)

        contentView = WKWebView(frame: .zero, configuration: configuration)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.navigationDelegate = navigationCoordinator
        contentView.uiDelegate = navigationCoordinator
        contentView.scrollView.contentInsetAdjustmentBehavior = .never
        contentView.allowsBackForwardNavigationGestures = true
        contentView.backgroundColor = .black
        contentView.isOpaque = false
        contentView.scrollView.delegate = navigationCoordinator
        contentView.scrollView.bouncesZoom = false
        contentView.scrollView.pinchGestureRecognizer?.isEnabled = false

        view.backgroundColor = .black
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
    }

    private func setupLoadingOverlay() {
        loadingOverlay = UIView()
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.backgroundColor = .black
        view.addSubview(loadingOverlay)

        loadingBackgroundImageView = UIImageView()
        loadingBackgroundImageView.contentMode = .scaleAspectFill
        loadingBackgroundImageView.clipsToBounds = true
        loadingBackgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingBackgroundImageView)

        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.addSubview(loadingIndicator)

        let centerY = loadingIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        loadingIndicatorCenterY = centerY

        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            loadingBackgroundImageView.topAnchor.constraint(equalTo: loadingOverlay.topAnchor),
            loadingBackgroundImageView.bottomAnchor.constraint(equalTo: loadingOverlay.bottomAnchor),
            loadingBackgroundImageView.leadingAnchor.constraint(equalTo: loadingOverlay.leadingAnchor),
            loadingBackgroundImageView.trailingAnchor.constraint(equalTo: loadingOverlay.trailingAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            centerY
        ])

        loadingIndicator.startAnimating()
        updateLoadingLayout(for: view.bounds.size)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateLoadingLayout(for: size)
        updateErrorBackground(for: size)
    }

    private func updateLoadingLayout(for size: CGSize) {
        let isLandscape = size.width > size.height
        loadingBackgroundImageView?.image = UIImage(named: isLandscape ? "LoadingBackgroundLandscape" : "LoadingBackground")
        loadingIndicatorCenterY?.constant = isLandscape ? 70 : 0
    }

    private func updateErrorBackground(for size: CGSize) {
        guard let imageView = errorBackgroundImageView else { return }
        imageView.image = UIImage(named: backgroundImageName(isLandscape: size.width > size.height, noInternet: true))
    }

    private func backgroundImageName(isLandscape: Bool, noInternet: Bool) -> String {
        if noInternet {
            return isLandscape ? "NoInternetBackgroundLandscape" : "NoInternetBackground"
        }
        return isLandscape ? "LoadingBackgroundLandscape" : "LoadingBackground"
    }

    private func isOfflineError(_ error: NSError) -> Bool {
        guard error.domain == NSURLErrorDomain else { return false }
        switch error.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed:
            return true
        default:
            return false
        }
    }

    private func loadDestination() {
        guard let address = URL(string: destination) else {
            finishInitialLoading()
            return
        }
        hideErrorView()
        hasLoadedMainContent = false
        navigationCoordinator.lastNavigatedAddress = address
        var request = URLRequest(url: address)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        contentView.load(request)

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            if !self.hasLoadedMainContent && self.contentView.url == nil {
                self.showErrorView(noInternet: false)
            } else {
                self.finishInitialLoading()
            }
        }
    }

    func markMainContentLoaded() {
        hasLoadedMainContent = true
        finishInitialLoading()
    }

    func reload(address: URL) {
        var request = URLRequest(url: address)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        contentView.load(request)
    }

    func handleMainFrameLoadFailure(_ error: NSError) {
        if !didAutoRetryAfterFailure {
            didAutoRetryAfterFailure = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                self.reloadDestination()
            }
            return
        }
        showErrorView(noInternet: isOfflineError(error))
    }

    private func reloadDestination() {
        guard let address = navigationCoordinator.lastNavigatedAddress ?? URL(string: destination) else {
            return
        }
        var request = URLRequest(url: address)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        contentView.load(request)
    }

    func finishInitialLoading() {
        guard !hasFinishedInitialLoad else { return }
        hasFinishedInitialLoad = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let overlay = self.loadingOverlay else { return }
            self.loadingIndicator.stopAnimating()
            UIView.animate(withDuration: 0.2, animations: {
                overlay.alpha = 0
            }, completion: { _ in
                overlay.isHidden = true
            })
        }
    }

    func requestCaptureAccess(_ type: WKMediaCaptureType) {
        if type == .camera || type == .cameraAndMicrophone {
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { _ in }
            }
        }
        if type == .microphone || type == .cameraAndMicrophone {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }

    private func showErrorView(noInternet: Bool) {
        finishInitialLoading()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.errorUsesNoInternetArt = noInternet
            let isLandscape = self.view.bounds.width > self.view.bounds.height
            // Always use NoInternet art — LoadingBackground has "LOADING" baked into the image.
            let imageName = self.backgroundImageName(isLandscape: isLandscape, noInternet: true)

            if let existing = self.errorView {
                self.errorBackgroundImageView?.image = UIImage(named: imageName)
                existing.isHidden = false
                self.view.bringSubviewToFront(existing)
                return
            }

            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.backgroundColor = .black

            let backgroundImageView = UIImageView()
            backgroundImageView.contentMode = .scaleAspectFill
            backgroundImageView.clipsToBounds = true
            backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
            backgroundImageView.image = UIImage(named: imageName)
            backgroundImageView.isUserInteractionEnabled = true
            container.addSubview(backgroundImageView)

            let tap = UITapGestureRecognizer(target: self, action: #selector(self.retryButtonTapped))
            backgroundImageView.addGestureRecognizer(tap)

            self.view.addSubview(container)
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: self.view.topAnchor),
                container.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                container.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),

                backgroundImageView.topAnchor.constraint(equalTo: container.topAnchor),
                backgroundImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                backgroundImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                backgroundImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])

            self.errorView = container
            self.errorBackgroundImageView = backgroundImageView
        }
    }

    private func hideErrorView() {
        errorView?.isHidden = true
    }

    @objc private func retryButtonTapped() {
        didAutoRetryAfterFailure = false
        hasFinishedInitialLoad = false
        hasLoadedMainContent = false
        loadingOverlay?.isHidden = false
        loadingOverlay?.alpha = 1
        loadingIndicator?.startAnimating()
        hideErrorView()
        loadDestination()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        OrientationController.shared.unlockAllOrientations()
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        OrientationController.shared.unlockAllOrientations()
        setNeedsUpdateOfSupportedInterfaceOrientations()
        UIViewController.attemptRotationToDeviceOrientation()
    }
}

final class ContentNavigationCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
    weak var controller: ContentPortalController?
    var lastNavigatedAddress: URL?
    private var panelCompletion: (([URL]?) -> Void)?

    init(controller: ContentPortalController) {
        self.controller = controller
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        controller?.requestCaptureAccess(type)
        decisionHandler(.grant)
    }

    @available(iOS 18.4, *)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        guard let controller else {
            completionHandler(nil)
            return
        }
        panelCompletion = completionHandler
        let sheet = UIAlertController(title: "Choose Source", message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                self?.showImagePicker(source: .camera)
            })
        }
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.showImagePicker(source: .photoLibrary)
        })
        sheet.addAction(UIAlertAction(title: "Files", style: .default) { [weak self] _ in
            self?.showDocumentPicker(allowsMultiple: parameters.allowsMultipleSelection)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.finishPanel(with: nil)
        })
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.maxY - 30, width: 1, height: 1)
        }
        controller.present(sheet, animated: true)
    }

    private func showImagePicker(source: UIImagePickerController.SourceType) {
        guard let controller else {
            finishPanel(with: nil)
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self
        picker.mediaTypes = ["public.image", "public.movie"]
        controller.present(picker, animated: true)
    }

    private func showDocumentPicker(allowsMultiple: Bool) {
        guard let controller else {
            finishPanel(with: nil)
            return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = allowsMultiple
        picker.delegate = self
        controller.present(picker, animated: true)
    }

    private func finishPanel(with addresses: [URL]?) {
        panelCompletion?(addresses)
        panelCompletion = nil
    }

    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale != 1.0 {
            scrollView.zoomScale = 1.0
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard isTargetFrameNil(for: navigationAction),
              let address = safeRequestAddress(from: navigationAction) else {
            if isTargetFrameNil(for: navigationAction) {
            }
            return nil
        }
        lastNavigatedAddress = address

        if webView.backForwardList.backList.isEmpty {
            replaceCurrentHistoryEntry(in: webView, with: address)
        } else {
            webView.load(noCacheRequest(for: address))
        }
        return nil
    }

    private func noCacheRequest(for address: URL) -> URLRequest {
        var request = URLRequest(url: address)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return request
    }

    private func replaceCurrentHistoryEntry(in webView: WKWebView, with address: URL) {
        guard let encoded = try? JSONEncoder().encode(address.absoluteString),
              let literal = String(data: encoded, encoding: .utf8) else {
            webView.load(noCacheRequest(for: address))
            return
        }
        webView.evaluateJavaScript("location.replace(\(literal));") { [weak self] _, error in
            if error != nil {
                self?.controller?.reload(address: address)
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame,
           let httpResponse = navigationResponse.response as? HTTPURLResponse {
            _ = httpResponse.statusCode
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        controller?.markMainContentLoaded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if isCancellation(nsError) {
            controller?.finishInitialLoading()
            return
        }
        controller?.handleMainFrameLoadFailure(nsError)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorHTTPTooManyRedirects {
            let failingAddress = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? lastNavigatedAddress
            if let address = failingAddress {
                webView.load(noCacheRequest(for: address))
                return
            }
        }
        if isCancellation(nsError) {
            controller?.finishInitialLoading()
            return
        }
        controller?.handleMainFrameLoadFailure(nsError)
    }

    private func isCancellation(_ error: NSError) -> Bool {
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            return true
        }
        if error.domain == "WebKitErrorDomain" && (error.code == 102 || error.code == 101) {
            return true
        }
        return false
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        controller?.finishInitialLoading()
        if let address = lastNavigatedAddress {
            webView.load(noCacheRequest(for: address))
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let address = safeRequestAddress(from: navigationAction) else {
            decisionHandler(.allow)
            return
        }

        let scheme = address.scheme?.lowercased()

        let inAppSchemes: Set<String> = ["http", "https", "about", "blob", "data", "file"]
        let isInApp = scheme.map { inAppSchemes.contains($0) } ?? false

        if isInApp {
            lastNavigatedAddress = address
            decisionHandler(.allow)
            return
        }

        decisionHandler(.cancel)
        openDeepLinkExternally(address)
    }

    private func safeRequestAddress(from navigationAction: WKNavigationAction) -> URL? {
        if #available(iOS 18.0, *) {
            return navigationAction.request.url
        }

        let obj = navigationAction as NSObject

        if let request = obj.value(forKey: "request") as? NSURLRequest {
            return request.url
        }

        if let resolved = obj.value(forKeyPath: "request.URL") as? URL {
            return resolved
        }
        if let nsURL = obj.value(forKeyPath: "request.URL") as? NSURL {
            return nsURL as URL
        }
        if let absolute = obj.value(forKeyPath: "request.URL.absoluteString") as? String,
           let resolved = URL(string: absolute) {
            return resolved
        }
        if let mainDocURL = obj.value(forKeyPath: "request.mainDocumentURL") as? URL {
            return mainDocURL
        }
        if let mainDocNSURL = obj.value(forKeyPath: "request.mainDocumentURL") as? NSURL {
            return mainDocNSURL as URL
        }

        let selector = NSSelectorFromString("request")
        if obj.responds(to: selector),
           let unmanaged = obj.perform(selector),
           let request = unmanaged.takeUnretainedValue() as? NSURLRequest {
            return request.url
        }

        return nil
    }

    private func isTargetFrameNil(for navigationAction: WKNavigationAction) -> Bool {
        if #available(iOS 18.0, *) {
            return navigationAction.targetFrame == nil
        }

        let obj = navigationAction as NSObject
        let selector = NSSelectorFromString("targetFrame")
        guard obj.responds(to: selector) else {
            return false
        }
        return obj.perform(selector) == nil
    }

    private func openDeepLinkExternally(_ address: URL) {
        UIApplication.shared.open(address, options: [:]) { [weak self] success in
            if success { return }

            guard let fallback = self?.strippedSafariSchemeAddress(from: address) else { return }
            UIApplication.shared.open(fallback, options: [:]) { fallbackSuccess in
                if !fallbackSuccess {
                }
            }
        }
    }

    private func strippedSafariSchemeAddress(from address: URL) -> URL? {
        guard let scheme = address.scheme?.lowercased(), scheme.hasPrefix("x-safari-") else {
            return nil
        }
        let strippedScheme = String(scheme.dropFirst("x-safari-".count))
        guard strippedScheme == "http" || strippedScheme == "https" else { return nil }

        var components = URLComponents(url: address, resolvingAgainstBaseURL: false)
        components?.scheme = strippedScheme
        return components?.url
    }
}

extension ContentNavigationCoordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let address = info[.mediaURL] as? URL {
            picker.dismiss(animated: true)
            finishPanel(with: [address])
            return
        }
        guard let image = info[.originalImage] as? UIImage,
              let data = image.jpegData(compressionQuality: 0.9) else {
            picker.dismiss(animated: true)
            finishPanel(with: nil)
            return
        }
        let address = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        try? data.write(to: address, options: .atomic)
        picker.dismiss(animated: true)
        finishPanel(with: [address])
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        finishPanel(with: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finishPanel(with: urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishPanel(with: nil)
    }
}
