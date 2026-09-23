import UIKit

final class LaunchLoaderViewController: UIViewController {
    private let indicator = UIActivityIndicatorView(style: .large)
    private var indicatorCenterY: NSLayoutConstraint?
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(backgroundImageView)

        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)

        let centerY = indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        indicatorCenterY = centerY

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerY
        ])

        indicator.startAnimating()
        updateBackgroundImage(for: view.bounds.size)
        updateIndicatorPosition(for: view.bounds.size)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateBackgroundImage(for: size)
        updateIndicatorPosition(for: size)
    }

    private func updateBackgroundImage(for size: CGSize) {
        let name = size.width > size.height ? "LoadingBackgroundLandscape" : "LoadingBackground"
        backgroundImageView.image = UIImage(named: name)
    }

    private func updateIndicatorPosition(for size: CGSize) {
        let isLandscape = size.width > size.height
        indicatorCenterY?.constant = isLandscape ? 70 : 0
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
