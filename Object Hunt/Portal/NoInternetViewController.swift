import UIKit

final class NoInternetViewController: UIViewController {
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
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        updateBackgroundImage(for: currentCanvasSize())
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBackgroundImage(for: currentCanvasSize())
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.updateBackgroundImage(for: size)
        })
    }

    private func currentCanvasSize() -> CGSize {
        let size = view.bounds.size
        if size.width > 0, size.height > 0 {
            return size
        }
        return UIScreen.main.bounds.size
    }

    private func updateBackgroundImage(for size: CGSize) {
        let isLandscape = size.width > size.height
        let name = isLandscape ? "NoInternetBackgroundLandscape" : "NoInternetBackground"
        let image = UIImage(named: name) ?? UIImage(named: "NoInternetBackground")
        if backgroundImageView.image !== image {
            backgroundImageView.image = image
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
