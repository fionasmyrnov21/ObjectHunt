import UIKit

final class AccentFillButton: UIButton {
    private let fillLayer = CAGradientLayer()

    var fillColors: [UIColor] = [] {
        didSet { fillLayer.colors = fillColors.map { $0.cgColor } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        fillLayer.startPoint = CGPoint(x: 0.5, y: 0)
        fillLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(fillLayer, at: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fillLayer.frame = bounds
        fillLayer.cornerRadius = layer.cornerRadius
    }
}

final class PushPermissionViewController: UIViewController {
    var onAccept: (() -> Void)?
    var onSkip: (() -> Void)?

    private var didHandleAction = false

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let gradientView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let textPanel: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.38)
        view.layer.cornerRadius = 18
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Stay Close to Your Frames"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.shadowColor = UIColor.black.withAlphaComponent(0.9)
        label.shadowOffset = CGSize(width: 0, height: 2)
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Enable alerts for quiet reminders and updates."
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.92)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.shadowColor = UIColor.black.withAlphaComponent(0.9)
        label.shadowOffset = CGSize(width: 0, height: 1)
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let buttonsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        return view
    }()

    private let acceptButton: AccentFillButton = {
        let button = AccentFillButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Enable Alerts", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        button.setTitleColor(.white, for: .normal)
        button.fillColors = [
            UIColor(red: 1.0, green: 0.74, blue: 0.17, alpha: 1.0),
            UIColor(red: 1.0, green: 0.42, blue: 0.02, alpha: 1.0)
        ]
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor(red: 0.63, green: 0.19, blue: 0.02, alpha: 1.0).cgColor
        return button
    }()

    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Skip", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 24
        return button
    }()

    private var gradientLayer: CAGradientLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        updateBackgroundImage(for: view.bounds.size)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = gradientView.bounds
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateBackgroundImage(for: size)
    }

    private func updateBackgroundImage(for size: CGSize) {
        let name = size.width > size.height ? "NotificationPermissionBackgroundLandscape" : "NotificationPermissionBackground"
        backgroundImageView.image = UIImage(named: name)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    private func setupUI() {
        view.backgroundColor = .black

        view.addSubview(backgroundImageView)
        view.addSubview(gradientView)
        view.addSubview(textPanel)
        textPanel.addSubview(textStack)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        view.addSubview(buttonsContainer)
        buttonsContainer.addSubview(acceptButton)
        buttonsContainer.addSubview(skipButton)

        setupGradientView()

        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let textPreferredTop = textPanel.topAnchor.constraint(equalTo: view.centerYAnchor, constant: 24)
        textPreferredTop.priority = .defaultLow

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            textPanel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            textPanel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            textPreferredTop,
            textPanel.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            textPanel.bottomAnchor.constraint(lessThanOrEqualTo: buttonsContainer.topAnchor, constant: -16),

            textStack.topAnchor.constraint(equalTo: textPanel.topAnchor, constant: 16),
            textStack.bottomAnchor.constraint(equalTo: textPanel.bottomAnchor, constant: -16),
            textStack.leadingAnchor.constraint(equalTo: textPanel.leadingAnchor, constant: 18),
            textStack.trailingAnchor.constraint(equalTo: textPanel.trailingAnchor, constant: -18),

            buttonsContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 38),
            buttonsContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -38),
            buttonsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),

            acceptButton.topAnchor.constraint(equalTo: buttonsContainer.topAnchor),
            acceptButton.leadingAnchor.constraint(equalTo: buttonsContainer.leadingAnchor),
            acceptButton.trailingAnchor.constraint(equalTo: buttonsContainer.trailingAnchor),
            acceptButton.heightAnchor.constraint(equalToConstant: 56),

            skipButton.topAnchor.constraint(equalTo: acceptButton.bottomAnchor, constant: 12),
            skipButton.leadingAnchor.constraint(equalTo: buttonsContainer.leadingAnchor),
            skipButton.trailingAnchor.constraint(equalTo: buttonsContainer.trailingAnchor),
            skipButton.heightAnchor.constraint(equalToConstant: 48),
            skipButton.bottomAnchor.constraint(equalTo: buttonsContainer.bottomAnchor)
        ])
    }

    private func setupGradientView() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.black.withAlphaComponent(0.05).cgColor,
            UIColor.black.withAlphaComponent(0.05).cgColor,
            UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 0.45).cgColor,
            UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 0.80).cgColor,
            UIColor(red: 0.03, green: 0.03, blue: 0.08, alpha: 0.95).cgColor
        ]
        gradient.locations = [0, 0.32, 0.5, 0.72, 1.0]
        gradientView.layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }

    private func setupActions() {
        acceptButton.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
    }

    private func animateIn() {
        buttonsContainer.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.55, delay: 0, options: .curveEaseOut) {
            self.buttonsContainer.alpha = 1.0
            self.buttonsContainer.transform = .identity
        }
    }

    @objc private func acceptTapped() {
        guard markActionHandled() else { return }
        onAccept?()
    }

    @objc private func skipTapped() {
        guard markActionHandled() else { return }
        onSkip?()
    }

    private func markActionHandled() -> Bool {
        guard !didHandleAction else { return false }
        didHandleAction = true
        acceptButton.isEnabled = false
        skipButton.isEnabled = false
        buttonsContainer.isUserInteractionEnabled = false
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
