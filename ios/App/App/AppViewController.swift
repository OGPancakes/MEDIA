import UIKit
import WebKit
import Capacitor
import ObjectiveC.runtime
import PhotosUI
import UserNotifications

final class AppViewController: CAPBridgeViewController, WKScriptMessageHandler, UITextViewDelegate, PHPickerViewControllerDelegate, UITableViewDataSource, UITableViewDelegate {
    private enum PrimarySection: String {
        case feed
        case messages
        case search
        case profile
    }

    private let shellBackground = UIColor(red: 238.0 / 255.0, green: 244.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
    private let topGradient = UIColor(red: 247.0 / 255.0, green: 250.0 / 255.0, blue: 255.0 / 255.0, alpha: 1).cgColor
    private let bottomGradient = UIColor(red: 255.0 / 255.0, green: 247.0 / 255.0, blue: 239.0 / 255.0, alpha: 1).cgColor
    private let gradientLayer = CAGradientLayer()

    private let composerDimView = UIControl()
    private let composerSheet = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let composerHandle = UIView()
    private let composerTitle = UILabel()
    private let composerCloseButton = UIButton(type: .system)
    private let composerTextView = UITextView()
    private let composerPlaceholder = UILabel()
    private let composerAttachButton = UIButton(type: .system)
    private let composerPreviewContainer = UIView()
    private let composerPreviewImageView = UIImageView()
    private let composerRemovePhotoButton = UIButton(type: .system)
    private let composerPostButton = UIButton(type: .system)
    private let composeButton = UIButton(type: .system)
    private let nativeTabBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let nativeTabBarBackdrop = UIView()
    private let nativeTabStack = UIStackView()
    private let messagesTabButton = UIButton(type: .system)
    private let feedTabButton = UIButton(type: .system)
    private let searchTabButton = UIButton(type: .system)
    private let profileTabButton = UIButton(type: .system)
    private let nativeMessagesContainer = UIView()
    private let nativeMessagesHeader = UILabel()
    private let nativeMessagesSubtitle = UILabel()
    private let nativeMessagesListTableView = UITableView(frame: .zero, style: .plain)
    private let nativeMessagesEmptyLabel = UILabel()
    private let nativeThreadContainer = UIView()
    private let nativeThreadBackButton = UIButton(type: .system)
    private let nativeThreadAvatarView = NativeAvatarView()
    private let nativeThreadTitleLabel = UILabel()
    private let nativeThreadVerifiedBadgeView = UIImageView()
    private let nativeThreadSubtitleLabel = UILabel()
    private let nativeThreadTableView = UITableView(frame: .zero, style: .plain)
    private let nativeThreadComposerBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let nativeThreadTextView = UITextView()
    private let nativeThreadPlaceholder = UILabel()
    private let nativeThreadSendButton = UIButton(type: .system)
    private let nativeThreadLoadingView = UIActivityIndicatorView(style: .large)
    private let nativeThreadEmptyLabel = UILabel()

    private var composerSheetBottomConstraint: NSLayoutConstraint?
    private var composeButtonBottomConstraint: NSLayoutConstraint?
    private var composerTextViewHeightConstraint: NSLayoutConstraint?
    private var composerPreviewHeightConstraint: NSLayoutConstraint?
    private var nativeThreadComposerBottomConstraint: NSLayoutConstraint?
    private var keyboardObserversInstalled = false
    private var nativeComposerAvailable = false
    private var isPostingComposer = false
    private var isLoggedIntoWebApp = false
    private var isShowingNativeMessages = false
    private var isLoadingNativeInbox = false
    private var isLoadingNativeThread = false
    private var isSendingNativeMessage = false
    private var lastRegisteredPushToken: String?
    private var stateSyncTimer: Timer?
    private var selectedImageData: Data?
    private var selectedImageName: String?
    private var selectedImageMimeType = "image/jpeg"
    private var currentFeedTab = "home"
    private var currentUsername = ""
    private var currentRoute = "/"
    private var currentPrimarySection: PrimarySection = .feed
    private var warmedRoutesForUsername: String?
    private var lastRouteBySection: [PrimarySection: String] = [
        .messages: "/messages",
        .feed: "/",
        .search: "/search"
    ]
    private var nativeMessageConversations: [NativeMessageConversation] = []
    private var nativeThreadMessages: [NativeThreadMessage] = []
    private var nativeMessageTarget: NativeUserSummary?
    private let nativeAvatarImageCache = NSCache<NSString, UIImage>()

    private let composerScriptMessageName = "nativeComposerState"

    public override func capacitorDidLoad() {
        super.capacitorDidLoad()

        view.backgroundColor = shellBackground
        gradientLayer.colors = [topGradient, shellBackground.cgColor, bottomGradient]
        gradientLayer.locations = [0.0, 0.58, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        if gradientLayer.superlayer == nil {
            view.layer.insertSublayer(gradientLayer, at: 0)
        }

        configureWebView()
        configureNativeComposer()
        configureNativeTabBar()
        configureNativeMessages()
        installKeyboardObservers()
        observePushToken()
        installComposerBridge()
        startStateSyncTimer()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stateSyncTimer?.invalidate()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: composerScriptMessageName)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
        if let threadGradient = nativeThreadContainer.layer.value(forKey: "threadGradientLayer") as? CAGradientLayer {
            threadGradient.frame = nativeThreadContainer.bounds
        }
    }

    private func configureWebView() {
        guard let webView = webView else { return }
        webView.isOpaque = true
        webView.backgroundColor = shellBackground
        if #available(iOS 15.0, *) {
            webView.underPageBackgroundColor = shellBackground
        }
        webView.inputAssistantItem.leadingBarButtonGroups = []
        webView.inputAssistantItem.trailingBarButtonGroups = []
        webView.hideInputAccessoryView()
        webView.scrollView.backgroundColor = shellBackground
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        webView.scrollView.verticalScrollIndicatorInsets = .zero
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.keyboardDismissMode = .interactive
    }

    private func configureNativeComposer() {
        composerDimView.translatesAutoresizingMaskIntoConstraints = false
        composerDimView.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        composerDimView.alpha = 0
        composerDimView.isHidden = true
        composerDimView.addTarget(self, action: #selector(dismissComposer), for: .touchUpInside)
        view.addSubview(composerDimView)

        composerSheet.translatesAutoresizingMaskIntoConstraints = false
        composerSheet.effect = UIBlurEffect(style: .systemThinMaterial)
        composerSheet.layer.cornerRadius = 30
        composerSheet.layer.cornerCurve = .continuous
        composerSheet.clipsToBounds = true
        composerSheet.isHidden = true
        composerSheet.alpha = 0
        view.addSubview(composerSheet)

        let sheetContent = composerSheet.contentView
        sheetContent.backgroundColor = UIColor.white.withAlphaComponent(0.72)

        composerHandle.translatesAutoresizingMaskIntoConstraints = false
        composerHandle.backgroundColor = UIColor(white: 0.45, alpha: 0.25)
        composerHandle.layer.cornerRadius = 2.5
        sheetContent.addSubview(composerHandle)

        composerTitle.translatesAutoresizingMaskIntoConstraints = false
        composerTitle.text = "Create post"
        composerTitle.font = .systemFont(ofSize: 18, weight: .semibold)
        composerTitle.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        sheetContent.addSubview(composerTitle)

        composerCloseButton.translatesAutoresizingMaskIntoConstraints = false
        composerCloseButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        composerCloseButton.tintColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.68)
        composerCloseButton.addTarget(self, action: #selector(dismissComposer), for: .touchUpInside)
        sheetContent.addSubview(composerCloseButton)

        composerTextView.translatesAutoresizingMaskIntoConstraints = false
        composerTextView.backgroundColor = .clear
        composerTextView.font = .systemFont(ofSize: 18)
        composerTextView.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        composerTextView.delegate = self
        composerTextView.returnKeyType = .default
        composerTextView.keyboardAppearance = .default
        composerTextView.autocorrectionType = .yes
        composerTextView.spellCheckingType = .yes
        composerTextView.autocapitalizationType = .sentences
        composerTextView.textContainerInset = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        composerTextView.textContainer.lineFragmentPadding = 0
        sheetContent.addSubview(composerTextView)

        composerPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        composerPlaceholder.text = "What’s happening?"
        composerPlaceholder.font = .systemFont(ofSize: 18)
        composerPlaceholder.textColor = UIColor(red: 91.0 / 255.0, green: 107.0 / 255.0, blue: 138.0 / 255.0, alpha: 0.72)
        sheetContent.addSubview(composerPlaceholder)

        composerPreviewContainer.translatesAutoresizingMaskIntoConstraints = false
        composerPreviewContainer.layer.cornerRadius = 18
        composerPreviewContainer.layer.cornerCurve = .continuous
        composerPreviewContainer.clipsToBounds = true
        composerPreviewContainer.backgroundColor = UIColor(red: 245.0 / 255.0, green: 248.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.88)
        composerPreviewContainer.isHidden = true
        sheetContent.addSubview(composerPreviewContainer)

        composerPreviewImageView.translatesAutoresizingMaskIntoConstraints = false
        composerPreviewImageView.contentMode = .scaleAspectFill
        composerPreviewImageView.clipsToBounds = true
        composerPreviewContainer.addSubview(composerPreviewImageView)

        composerRemovePhotoButton.translatesAutoresizingMaskIntoConstraints = false
        composerRemovePhotoButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        composerRemovePhotoButton.tintColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.9)
        composerRemovePhotoButton.addTarget(self, action: #selector(removeSelectedPhoto), for: .touchUpInside)
        composerPreviewContainer.addSubview(composerRemovePhotoButton)

        composerAttachButton.translatesAutoresizingMaskIntoConstraints = false
        composerAttachButton.setImage(UIImage(systemName: "photo.on.rectangle.angled"), for: .normal)
        composerAttachButton.setTitle(" Add photo", for: .normal)
        composerAttachButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        composerAttachButton.tintColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.92)
        composerAttachButton.backgroundColor = UIColor(red: 245.0 / 255.0, green: 248.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.9)
        composerAttachButton.layer.cornerRadius = 18
        composerAttachButton.layer.cornerCurve = .continuous
        composerAttachButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        composerAttachButton.addTarget(self, action: #selector(openPhotoPicker), for: .touchUpInside)
        sheetContent.addSubview(composerAttachButton)

        composerPostButton.translatesAutoresizingMaskIntoConstraints = false
        composerPostButton.setTitle("Post", for: .normal)
        composerPostButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        composerPostButton.backgroundColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
        composerPostButton.layer.cornerRadius = 18
        composerPostButton.layer.cornerCurve = .continuous
        composerPostButton.setTitleColor(.white, for: .normal)
        composerPostButton.addTarget(self, action: #selector(postFromNativeComposer), for: .touchUpInside)
        sheetContent.addSubview(composerPostButton)

        composeButton.translatesAutoresizingMaskIntoConstraints = false
        composeButton.backgroundColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
        composeButton.layer.cornerRadius = 28
        composeButton.layer.cornerCurve = .continuous
        composeButton.tintColor = .white
        composeButton.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        composeButton.addTarget(self, action: #selector(showComposer), for: .touchUpInside)
        composeButton.alpha = 0
        composeButton.isHidden = true
        composeButton.layer.shadowColor = UIColor.black.withAlphaComponent(0.22).cgColor
        composeButton.layer.shadowOpacity = 1
        composeButton.layer.shadowRadius = 18
        composeButton.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.addSubview(composeButton)

        composerSheetBottomConstraint = composerSheet.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 360)
        composerTextViewHeightConstraint = composerTextView.heightAnchor.constraint(equalToConstant: 112)
        composerPreviewHeightConstraint = composerPreviewContainer.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            composerDimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composerDimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composerDimView.topAnchor.constraint(equalTo: view.topAnchor),
            composerDimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            composerSheet.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            composerSheet.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            composerSheetBottomConstraint!,

            composerHandle.topAnchor.constraint(equalTo: sheetContent.topAnchor, constant: 10),
            composerHandle.centerXAnchor.constraint(equalTo: sheetContent.centerXAnchor),
            composerHandle.widthAnchor.constraint(equalToConstant: 42),
            composerHandle.heightAnchor.constraint(equalToConstant: 5),

            composerCloseButton.topAnchor.constraint(equalTo: sheetContent.topAnchor, constant: 18),
            composerCloseButton.trailingAnchor.constraint(equalTo: sheetContent.trailingAnchor, constant: -18),
            composerCloseButton.widthAnchor.constraint(equalToConstant: 28),
            composerCloseButton.heightAnchor.constraint(equalToConstant: 28),

            composerTitle.centerYAnchor.constraint(equalTo: composerCloseButton.centerYAnchor),
            composerTitle.centerXAnchor.constraint(equalTo: sheetContent.centerXAnchor),

            composerTextView.topAnchor.constraint(equalTo: composerTitle.bottomAnchor, constant: 16),
            composerTextView.leadingAnchor.constraint(equalTo: sheetContent.leadingAnchor, constant: 18),
            composerTextView.trailingAnchor.constraint(equalTo: sheetContent.trailingAnchor, constant: -18),
            composerTextViewHeightConstraint!,

            composerPlaceholder.topAnchor.constraint(equalTo: composerTextView.topAnchor, constant: 14),
            composerPlaceholder.leadingAnchor.constraint(equalTo: composerTextView.leadingAnchor),

            composerPreviewContainer.topAnchor.constraint(equalTo: composerTextView.bottomAnchor, constant: 6),
            composerPreviewContainer.leadingAnchor.constraint(equalTo: sheetContent.leadingAnchor, constant: 18),
            composerPreviewContainer.trailingAnchor.constraint(equalTo: sheetContent.trailingAnchor, constant: -18),
            composerPreviewHeightConstraint!,

            composerPreviewImageView.leadingAnchor.constraint(equalTo: composerPreviewContainer.leadingAnchor),
            composerPreviewImageView.trailingAnchor.constraint(equalTo: composerPreviewContainer.trailingAnchor),
            composerPreviewImageView.topAnchor.constraint(equalTo: composerPreviewContainer.topAnchor),
            composerPreviewImageView.bottomAnchor.constraint(equalTo: composerPreviewContainer.bottomAnchor),

            composerRemovePhotoButton.topAnchor.constraint(equalTo: composerPreviewContainer.topAnchor, constant: 8),
            composerRemovePhotoButton.trailingAnchor.constraint(equalTo: composerPreviewContainer.trailingAnchor, constant: -8),
            composerRemovePhotoButton.widthAnchor.constraint(equalToConstant: 30),
            composerRemovePhotoButton.heightAnchor.constraint(equalToConstant: 30),

            composerAttachButton.topAnchor.constraint(equalTo: composerPreviewContainer.bottomAnchor, constant: 12),
            composerAttachButton.leadingAnchor.constraint(equalTo: sheetContent.leadingAnchor, constant: 18),
            composerAttachButton.heightAnchor.constraint(equalToConstant: 40),

            composerPostButton.centerYAnchor.constraint(equalTo: composerAttachButton.centerYAnchor),
            composerPostButton.trailingAnchor.constraint(equalTo: sheetContent.trailingAnchor, constant: -18),
            composerPostButton.widthAnchor.constraint(equalToConstant: 82),
            composerPostButton.heightAnchor.constraint(equalToConstant: 40),
            composerPostButton.leadingAnchor.constraint(greaterThanOrEqualTo: composerAttachButton.trailingAnchor, constant: 12),
            composerPostButton.bottomAnchor.constraint(equalTo: sheetContent.bottomAnchor, constant: -16),

            composeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            composeButton.widthAnchor.constraint(equalToConstant: 56),
            composeButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        composerPostButton.isEnabled = false
        composerPostButton.alpha = 0.55
    }

    private func configureNativeTabBar() {
        nativeTabBarBackdrop.translatesAutoresizingMaskIntoConstraints = false
        nativeTabBarBackdrop.backgroundColor = shellBackground
        nativeTabBarBackdrop.alpha = 0
        nativeTabBarBackdrop.isHidden = true
        nativeTabBarBackdrop.layer.zPosition = 55
        view.addSubview(nativeTabBarBackdrop)

        nativeTabBar.translatesAutoresizingMaskIntoConstraints = false
        nativeTabBar.effect = nil
        nativeTabBar.layer.zPosition = 60
        nativeTabBar.layer.cornerRadius = 26
        nativeTabBar.layer.cornerCurve = .continuous
        nativeTabBar.clipsToBounds = true
        nativeTabBar.contentView.backgroundColor = UIColor.white.withAlphaComponent(0.98)
        nativeTabBar.layer.borderWidth = 1
        nativeTabBar.layer.borderColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.1).cgColor
        nativeTabBar.layer.shadowColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.18).cgColor
        nativeTabBar.layer.shadowOpacity = 1
        nativeTabBar.layer.shadowRadius = 18
        nativeTabBar.layer.shadowOffset = CGSize(width: 0, height: 10)
        nativeTabBar.alpha = 0
        nativeTabBar.isHidden = true
        view.addSubview(nativeTabBar)

        nativeTabStack.translatesAutoresizingMaskIntoConstraints = false
        nativeTabStack.axis = .horizontal
        nativeTabStack.distribution = .fillEqually
        nativeTabStack.alignment = .fill
        nativeTabStack.spacing = 10
        nativeTabBar.contentView.addSubview(nativeTabStack)

        configureTabButton(messagesTabButton, title: "DM", section: .messages)
        configureTabButton(feedTabButton, title: "Feed", section: .feed)
        configureTabButton(searchTabButton, title: "Search", section: .search)
        configureTabButton(profileTabButton, title: "Profile", section: .profile)

        [messagesTabButton, feedTabButton, searchTabButton, profileTabButton].forEach(nativeTabStack.addArrangedSubview)

        composeButtonBottomConstraint = composeButton.bottomAnchor.constraint(equalTo: nativeTabBar.topAnchor, constant: -14)
        composeButton.layer.zPosition = 62

        NSLayoutConstraint.activate([
            nativeTabBarBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeTabBarBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeTabBarBackdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            nativeTabBarBackdrop.topAnchor.constraint(equalTo: nativeTabBar.topAnchor, constant: -14),

            nativeTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            nativeTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            nativeTabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),

            nativeTabStack.leadingAnchor.constraint(equalTo: nativeTabBar.contentView.leadingAnchor, constant: 10),
            nativeTabStack.trailingAnchor.constraint(equalTo: nativeTabBar.contentView.trailingAnchor, constant: -10),
            nativeTabStack.topAnchor.constraint(equalTo: nativeTabBar.contentView.topAnchor, constant: 10),
            nativeTabStack.bottomAnchor.constraint(equalTo: nativeTabBar.contentView.bottomAnchor, constant: -10),

            composeButtonBottomConstraint!
        ])

        updateNativeTabSelection(animated: false)
    }

    private func configureNativeMessages() {
        nativeMessagesContainer.translatesAutoresizingMaskIntoConstraints = false
        nativeMessagesContainer.alpha = 0
        nativeMessagesContainer.isHidden = true
        nativeMessagesContainer.backgroundColor = shellBackground
        nativeMessagesContainer.isOpaque = true
        nativeMessagesContainer.layer.zPosition = 40
        view.addSubview(nativeMessagesContainer)

        nativeMessagesHeader.translatesAutoresizingMaskIntoConstraints = false
        nativeMessagesHeader.text = "Messages"
        nativeMessagesHeader.font = .systemFont(ofSize: 34, weight: .bold)
        nativeMessagesHeader.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativeMessagesContainer.addSubview(nativeMessagesHeader)

        nativeMessagesSubtitle.translatesAutoresizingMaskIntoConstraints = false
        nativeMessagesSubtitle.text = "Your conversations will show here once you send or receive a message."
        nativeMessagesSubtitle.font = .systemFont(ofSize: 15, weight: .medium)
        nativeMessagesSubtitle.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.92)
        nativeMessagesSubtitle.numberOfLines = 2
        nativeMessagesContainer.addSubview(nativeMessagesSubtitle)

        nativeMessagesListTableView.translatesAutoresizingMaskIntoConstraints = false
        nativeMessagesListTableView.backgroundColor = .clear
        nativeMessagesListTableView.separatorStyle = .none
        nativeMessagesListTableView.showsVerticalScrollIndicator = false
        nativeMessagesListTableView.rowHeight = UITableView.automaticDimension
        nativeMessagesListTableView.estimatedRowHeight = 104
        nativeMessagesListTableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 18, right: 0)
        nativeMessagesListTableView.dataSource = self
        nativeMessagesListTableView.delegate = self
        nativeMessagesListTableView.register(NativeConversationCell.self, forCellReuseIdentifier: NativeConversationCell.reuseIdentifier)
        nativeMessagesContainer.addSubview(nativeMessagesListTableView)

        nativeMessagesEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeMessagesEmptyLabel.text = "No conversations yet."
        nativeMessagesEmptyLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nativeMessagesEmptyLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.75)
        nativeMessagesEmptyLabel.textAlignment = .center
        nativeMessagesEmptyLabel.isHidden = true
        nativeMessagesContainer.addSubview(nativeMessagesEmptyLabel)

        nativeThreadContainer.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadContainer.backgroundColor = shellBackground
        nativeThreadContainer.layer.cornerRadius = 28
        nativeThreadContainer.layer.cornerCurve = .continuous
        nativeThreadContainer.layer.borderWidth = 1
        nativeThreadContainer.layer.borderColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.08).cgColor
        nativeThreadContainer.layer.shadowColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.12).cgColor
        nativeThreadContainer.layer.shadowOpacity = 1
        nativeThreadContainer.layer.shadowRadius = 24
        nativeThreadContainer.layer.shadowOffset = CGSize(width: 0, height: 14)
        nativeThreadContainer.isHidden = true
        nativeMessagesContainer.addSubview(nativeThreadContainer)

        nativeThreadBackButton.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadBackButton.setTitle("Back", for: .normal)
        nativeThreadBackButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        nativeThreadBackButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        nativeThreadBackButton.tintColor = UIColor(red: 245.0 / 255.0, green: 248.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
        nativeThreadBackButton.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        nativeThreadBackButton.layer.cornerRadius = 15
        nativeThreadBackButton.layer.cornerCurve = .continuous
        nativeThreadBackButton.contentEdgeInsets = UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 12)
        nativeThreadBackButton.addTarget(self, action: #selector(handleNativeThreadBack), for: .touchUpInside)
        nativeThreadContainer.addSubview(nativeThreadBackButton)

        nativeThreadAvatarView.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadContainer.addSubview(nativeThreadAvatarView)

        nativeThreadTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadTitleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        nativeThreadTitleLabel.textColor = UIColor.white
        nativeThreadContainer.addSubview(nativeThreadTitleLabel)

        nativeThreadVerifiedBadgeView.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadVerifiedBadgeView.image = UIImage(systemName: "checkmark.seal.fill")
        nativeThreadVerifiedBadgeView.tintColor = UIColor(red: 62.0 / 255.0, green: 164.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
        nativeThreadVerifiedBadgeView.contentMode = .scaleAspectFit
        nativeThreadVerifiedBadgeView.isHidden = true
        nativeThreadContainer.addSubview(nativeThreadVerifiedBadgeView)

        nativeThreadSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadSubtitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nativeThreadSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        nativeThreadContainer.addSubview(nativeThreadSubtitleLabel)

        nativeThreadTableView.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadTableView.backgroundColor = .clear
        nativeThreadTableView.separatorStyle = .none
        nativeThreadTableView.showsVerticalScrollIndicator = false
        nativeThreadTableView.keyboardDismissMode = .interactive
        nativeThreadTableView.rowHeight = UITableView.automaticDimension
        nativeThreadTableView.estimatedRowHeight = 92
        nativeThreadTableView.contentInset = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        nativeThreadTableView.isScrollEnabled = true
        nativeThreadTableView.dataSource = self
        nativeThreadTableView.delegate = self
        nativeThreadTableView.register(NativeThreadMessageCell.self, forCellReuseIdentifier: NativeThreadMessageCell.reuseIdentifier)
        nativeThreadContainer.addSubview(nativeThreadTableView)

        nativeThreadComposerBar.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadComposerBar.layer.cornerRadius = 22
        nativeThreadComposerBar.layer.cornerCurve = .continuous
        nativeThreadComposerBar.clipsToBounds = true
        nativeThreadComposerBar.contentView.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        nativeThreadContainer.addSubview(nativeThreadComposerBar)

        nativeThreadTextView.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadTextView.backgroundColor = .clear
        nativeThreadTextView.font = .systemFont(ofSize: 17)
        nativeThreadTextView.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativeThreadTextView.delegate = self
        nativeThreadTextView.textContainerInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        nativeThreadTextView.textContainer.lineFragmentPadding = 0
        nativeThreadTextView.isScrollEnabled = false
        nativeThreadTextView.autocorrectionType = .yes
        nativeThreadTextView.spellCheckingType = .yes
        nativeThreadComposerBar.contentView.addSubview(nativeThreadTextView)

        nativeThreadPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadPlaceholder.text = "Write a direct message"
        nativeThreadPlaceholder.font = .systemFont(ofSize: 17)
        nativeThreadPlaceholder.textColor = UIColor(red: 91.0 / 255.0, green: 107.0 / 255.0, blue: 138.0 / 255.0, alpha: 0.72)
        nativeThreadComposerBar.contentView.addSubview(nativeThreadPlaceholder)

        nativeThreadSendButton.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadSendButton.setTitle("Send", for: .normal)
        nativeThreadSendButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        nativeThreadSendButton.backgroundColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
        nativeThreadSendButton.setTitleColor(.white, for: .normal)
        nativeThreadSendButton.layer.cornerRadius = 18
        nativeThreadSendButton.layer.cornerCurve = .continuous
        nativeThreadSendButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        nativeThreadSendButton.addTarget(self, action: #selector(handleNativeMessageSend), for: .touchUpInside)
        nativeThreadComposerBar.contentView.addSubview(nativeThreadSendButton)

        nativeThreadLoadingView.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadLoadingView.hidesWhenStopped = true
        nativeThreadLoadingView.color = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.9)
        nativeMessagesContainer.addSubview(nativeThreadLoadingView)

        nativeThreadEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeThreadEmptyLabel.text = "No messages yet."
        nativeThreadEmptyLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nativeThreadEmptyLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        nativeThreadEmptyLabel.textAlignment = .center
        nativeThreadEmptyLabel.isHidden = true
        nativeThreadContainer.addSubview(nativeThreadEmptyLabel)

        nativeThreadComposerBottomConstraint = nativeThreadComposerBar.bottomAnchor.constraint(equalTo: nativeThreadContainer.bottomAnchor, constant: -14)

        NSLayoutConstraint.activate([
            nativeMessagesContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeMessagesContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeMessagesContainer.topAnchor.constraint(equalTo: view.topAnchor),
            nativeMessagesContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            nativeMessagesHeader.leadingAnchor.constraint(equalTo: nativeMessagesContainer.leadingAnchor, constant: 20),
            nativeMessagesHeader.trailingAnchor.constraint(equalTo: nativeMessagesContainer.trailingAnchor, constant: -20),
            nativeMessagesHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),

            nativeMessagesSubtitle.leadingAnchor.constraint(equalTo: nativeMessagesHeader.leadingAnchor),
            nativeMessagesSubtitle.trailingAnchor.constraint(equalTo: nativeMessagesHeader.trailingAnchor),
            nativeMessagesSubtitle.topAnchor.constraint(equalTo: nativeMessagesHeader.bottomAnchor, constant: 6),

            nativeMessagesListTableView.leadingAnchor.constraint(equalTo: nativeMessagesContainer.leadingAnchor, constant: 12),
            nativeMessagesListTableView.trailingAnchor.constraint(equalTo: nativeMessagesContainer.trailingAnchor, constant: -12),
            nativeMessagesListTableView.topAnchor.constraint(equalTo: nativeMessagesSubtitle.bottomAnchor, constant: 12),
            nativeMessagesListTableView.bottomAnchor.constraint(equalTo: nativeTabBar.topAnchor, constant: -16),

            nativeMessagesEmptyLabel.centerXAnchor.constraint(equalTo: nativeMessagesListTableView.centerXAnchor),
            nativeMessagesEmptyLabel.centerYAnchor.constraint(equalTo: nativeMessagesListTableView.centerYAnchor),

            nativeThreadContainer.leadingAnchor.constraint(equalTo: nativeMessagesContainer.leadingAnchor, constant: 12),
            nativeThreadContainer.trailingAnchor.constraint(equalTo: nativeMessagesContainer.trailingAnchor, constant: -12),
            nativeThreadContainer.topAnchor.constraint(equalTo: nativeMessagesHeader.bottomAnchor, constant: 2),
            nativeThreadContainer.bottomAnchor.constraint(equalTo: nativeTabBar.topAnchor, constant: -12),

            nativeThreadBackButton.leadingAnchor.constraint(equalTo: nativeThreadContainer.leadingAnchor, constant: 16),
            nativeThreadBackButton.topAnchor.constraint(equalTo: nativeThreadContainer.topAnchor, constant: 16),
            nativeThreadBackButton.heightAnchor.constraint(equalToConstant: 30),

            nativeThreadAvatarView.leadingAnchor.constraint(equalTo: nativeThreadContainer.leadingAnchor, constant: 18),
            nativeThreadAvatarView.topAnchor.constraint(equalTo: nativeThreadBackButton.bottomAnchor, constant: 16),
            nativeThreadAvatarView.widthAnchor.constraint(equalToConstant: 54),
            nativeThreadAvatarView.heightAnchor.constraint(equalToConstant: 54),

            nativeThreadTitleLabel.leadingAnchor.constraint(equalTo: nativeThreadAvatarView.trailingAnchor, constant: 14),
            nativeThreadTitleLabel.topAnchor.constraint(equalTo: nativeThreadAvatarView.topAnchor, constant: 2),

            nativeThreadVerifiedBadgeView.leadingAnchor.constraint(equalTo: nativeThreadTitleLabel.trailingAnchor, constant: 6),
            nativeThreadVerifiedBadgeView.centerYAnchor.constraint(equalTo: nativeThreadTitleLabel.centerYAnchor),
            nativeThreadVerifiedBadgeView.widthAnchor.constraint(equalToConstant: 18),
            nativeThreadVerifiedBadgeView.heightAnchor.constraint(equalToConstant: 18),

            nativeThreadTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: nativeThreadVerifiedBadgeView.leadingAnchor, constant: -6),
            nativeThreadVerifiedBadgeView.trailingAnchor.constraint(lessThanOrEqualTo: nativeThreadContainer.trailingAnchor, constant: -18),

            nativeThreadSubtitleLabel.leadingAnchor.constraint(equalTo: nativeThreadTitleLabel.leadingAnchor),
            nativeThreadSubtitleLabel.trailingAnchor.constraint(equalTo: nativeThreadTitleLabel.trailingAnchor),
            nativeThreadSubtitleLabel.topAnchor.constraint(equalTo: nativeThreadTitleLabel.bottomAnchor, constant: 4),

            nativeThreadTableView.leadingAnchor.constraint(equalTo: nativeThreadContainer.leadingAnchor, constant: 10),
            nativeThreadTableView.trailingAnchor.constraint(equalTo: nativeThreadContainer.trailingAnchor, constant: -10),
            nativeThreadTableView.topAnchor.constraint(equalTo: nativeThreadAvatarView.bottomAnchor, constant: 18),
            nativeThreadTableView.bottomAnchor.constraint(equalTo: nativeThreadComposerBar.topAnchor, constant: -10),

            nativeThreadComposerBar.leadingAnchor.constraint(equalTo: nativeThreadContainer.leadingAnchor, constant: 14),
            nativeThreadComposerBar.trailingAnchor.constraint(equalTo: nativeThreadContainer.trailingAnchor, constant: -14),
            nativeThreadComposerBottomConstraint!,

            nativeThreadTextView.leadingAnchor.constraint(equalTo: nativeThreadComposerBar.contentView.leadingAnchor, constant: 16),
            nativeThreadTextView.trailingAnchor.constraint(equalTo: nativeThreadSendButton.leadingAnchor, constant: -10),
            nativeThreadTextView.topAnchor.constraint(equalTo: nativeThreadComposerBar.contentView.topAnchor, constant: 2),
            nativeThreadTextView.bottomAnchor.constraint(equalTo: nativeThreadComposerBar.contentView.bottomAnchor, constant: -2),
            nativeThreadTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),

            nativeThreadPlaceholder.leadingAnchor.constraint(equalTo: nativeThreadTextView.leadingAnchor),
            nativeThreadPlaceholder.topAnchor.constraint(equalTo: nativeThreadTextView.topAnchor, constant: 12),

            nativeThreadSendButton.trailingAnchor.constraint(equalTo: nativeThreadComposerBar.contentView.trailingAnchor, constant: -10),
            nativeThreadSendButton.centerYAnchor.constraint(equalTo: nativeThreadComposerBar.contentView.centerYAnchor),
            nativeThreadSendButton.heightAnchor.constraint(equalToConstant: 38),

            nativeThreadLoadingView.centerXAnchor.constraint(equalTo: nativeMessagesContainer.centerXAnchor),
            nativeThreadLoadingView.centerYAnchor.constraint(equalTo: nativeMessagesContainer.centerYAnchor),

            nativeThreadEmptyLabel.centerXAnchor.constraint(equalTo: nativeThreadTableView.centerXAnchor),
            nativeThreadEmptyLabel.centerYAnchor.constraint(equalTo: nativeThreadTableView.centerYAnchor)
        ])

        let threadGradient = CAGradientLayer()
        threadGradient.colors = [
            UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.97).cgColor,
            UIColor(red: 191.0 / 255.0, green: 10.0 / 255.0, blue: 48.0 / 255.0, alpha: 0.84).cgColor
        ]
        threadGradient.startPoint = CGPoint(x: 0, y: 0)
        threadGradient.endPoint = CGPoint(x: 1, y: 1)
        threadGradient.cornerRadius = 28
        threadGradient.cornerCurve = .continuous
        threadGradient.frame = CGRect(x: 0, y: 0, width: 1, height: 180)
        nativeThreadContainer.layer.insertSublayer(threadGradient, at: 0)
        nativeThreadContainer.layer.setValue(threadGradient, forKey: "threadGradientLayer")

        updateNativeThreadComposeState()
    }

    private func configureTabButton(_ button: UIButton, title: String, section: PrimarySection) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 18
        button.layer.cornerCurve = .continuous
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        button.tag = tabTag(for: section)
        button.addTarget(self, action: #selector(handleNativeTabTap(_:)), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 56).isActive = true
    }

    private func tabTag(for section: PrimarySection) -> Int {
        switch section {
        case .messages: return 1
        case .feed: return 2
        case .search: return 3
        case .profile: return 4
        }
    }

    private func section(for tag: Int) -> PrimarySection? {
        switch tag {
        case 1: return .messages
        case 2: return .feed
        case 3: return .search
        case 4: return .profile
        default: return nil
        }
    }

    private func updateNativeTabSelection(animated: Bool) {
        let updates = {
            [self.messagesTabButton, self.feedTabButton, self.searchTabButton, self.profileTabButton].forEach { button in
                guard let section = self.section(for: button.tag) else { return }
                let isActive = section == self.currentPrimarySection
                button.backgroundColor = isActive
                    ? UIColor(red: 240.0 / 255.0, green: 244.0 / 255.0, blue: 252.0 / 255.0, alpha: 1)
                    : UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.06)
                button.setTitleColor(
                    isActive
                        ? UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
                        : UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 1),
                    for: .normal
                )
                button.transform = isActive ? CGAffineTransform(scaleX: 1.02, y: 1.02) : .identity
            }
        }
        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func setNativeTabBarVisible(_ visible: Bool, animated: Bool) {
        if visible {
            nativeTabBar.isHidden = false
        }
        let changes = {
            self.nativeTabBar.alpha = visible ? 1 : 0
            self.nativeTabBarBackdrop.alpha = visible ? 1 : 0
        }
        let completion: (Bool) -> Void = { _ in
            if !visible {
                self.nativeTabBar.isHidden = true
                self.nativeTabBarBackdrop.isHidden = true
            }
        }
        if animated {
            if visible {
                self.nativeTabBarBackdrop.isHidden = false
            }
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut], animations: changes, completion: completion)
        } else {
            nativeTabBarBackdrop.isHidden = !visible
            changes()
            completion(true)
        }
    }

    private func updateNativeSectionPresentation() {
        let shouldShowMessages = isLoggedIntoWebApp && currentPrimarySection == .messages
        if shouldShowMessages {
            showNativeMessagesIfNeeded()
            let routeTarget = nativeMessageUsername(from: currentRoute)
            if let routeTarget, routeTarget != nativeMessageTarget?.username {
                loadNativeThread(username: routeTarget, animate: nativeMessageTarget != nil)
            } else if nativeMessageTarget == nil && !isLoadingNativeInbox && nativeMessageConversations.isEmpty {
                loadNativeInbox()
            }
        } else {
            hideNativeMessagesIfNeeded()
        }
    }

    private func showNativeMessagesIfNeeded() {
        guard !isShowingNativeMessages else { return }
        isShowingNativeMessages = true
        composeButton.isHidden = true
        nativeMessagesContainer.isHidden = false
        nativeMessagesContainer.alpha = 1
        view.bringSubviewToFront(nativeMessagesContainer)
        view.bringSubviewToFront(nativeTabBarBackdrop)
        view.bringSubviewToFront(nativeTabBar)
        loadNativeInbox()
    }

    private func hideNativeMessagesIfNeeded() {
        guard isShowingNativeMessages else { return }
        isShowingNativeMessages = false
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut]) {
            self.nativeMessagesContainer.alpha = 0
        } completion: { _ in
            self.nativeMessagesContainer.isHidden = true
            if self.nativeComposerAvailable {
                self.composeButton.isHidden = false
                self.composeButton.alpha = 1
            }
        }
    }

    private func nativeMessageUsername(from route: String) -> String? {
        guard route.starts(with: "/messages") else { return nil }
        guard let components = URLComponents(string: "https://local\(route)"),
              let value = components.queryItems?.first(where: { $0.name == "user" })?.value,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func updateNativeThreadComposeState() {
        let trimmed = nativeThreadTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSend = !trimmed.isEmpty && !isSendingNativeMessage && nativeMessageTarget != nil
        nativeThreadPlaceholder.isHidden = !trimmed.isEmpty
        nativeThreadSendButton.isEnabled = canSend
        nativeThreadSendButton.alpha = canSend ? 1 : 0.5
    }

    private func installComposerBridge() {
        guard let webView = webView else { return }
        let source = """
        (function() {
          if (window.__nativeComposerBridgeInstalled) return;
          window.__nativeComposerBridgeInstalled = true;
          function normalizedProfilePath(username) {
            return username ? `/users/${encodeURIComponent(username)}` : '/';
          }
          function normalizedCurrentRoute() {
            return `${window.location.pathname || '/'}${window.location.search || ''}`;
          }
          function currentScrollTop() {
            const scrollRoot = document.querySelector('[data-app-scroll-root]') || document.querySelector('main.content, main.guest-shell');
            if (scrollRoot && typeof scrollRoot.scrollTop === 'number') {
              return scrollRoot.scrollTop;
            }
            return window.scrollY || 0;
          }
          function primarySection() {
            const path = window.location.pathname || '/';
            if (path.startsWith('/messages')) return 'messages';
            if (path.startsWith('/search')) return 'search';
            if (path.startsWith('/users/')) return 'profile';
            return 'feed';
          }
          window.nativeOpenPrimaryRoute = function(section, profileUsername, preferredRoute, restoreScroll) {
            const destinations = {
              messages: '/messages',
              feed: '/',
              search: '/search',
              profile: normalizedProfilePath(profileUsername || '')
            };
            const targetUrl = preferredRoute || destinations[section] || '/';
            if (window.navigateInApp) {
              return window.navigateInApp(targetUrl, { restoreScroll: !!restoreScroll });
            }
            window.location.assign(targetUrl);
          };
          window.nativePrefetchPrimaryRoutes = function(profileUsername) {
            if (!window.prefetchRoute) return;
            const urls = ['/messages', '/', '/search', normalizedProfilePath(profileUsername || '')];
            urls.forEach(function(url) {
              window.prefetchRoute(url);
            });
          };
          function notify() {
            try {
              document.body && document.body.classList.add('native-compose-enabled');
              document.body && document.body.classList.add('native-tab-shell-enabled');
              const username = document.querySelector('.account-trigger-copy span') ? document.querySelector('.account-trigger-copy span').textContent.replace(/^@/, '').trim() : '';
              window.webkit.messageHandlers.\(composerScriptMessageName).postMessage({
                loggedIn: document.body ? document.body.classList.contains('app-body') : false,
                username: username,
                isFeed: !!document.querySelector('.home-flow'),
                canCompose: !!document.querySelector('.home-flow .composer form'),
                feedMode: (document.querySelector('#live-feed') && document.querySelector('#live-feed').dataset.feedMode) || 'home',
                primarySection: primarySection(),
                currentRoute: normalizedCurrentRoute(),
                scrollTop: currentScrollTop()
              });
            } catch (e) {}
          }
          const wrapHistory = function(method) {
            const original = history[method];
            history[method] = function() {
              const result = original.apply(this, arguments);
              requestAnimationFrame(notify);
              return result;
            };
          };
          wrapHistory('pushState');
          wrapHistory('replaceState');
          window.addEventListener('load', notify);
          window.addEventListener('pageshow', notify);
          window.addEventListener('popstate', notify);
          new MutationObserver(function() {
            requestAnimationFrame(notify);
          }).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['class'] });
          notify();
        })();
        """
        webView.configuration.userContentController.removeScriptMessageHandler(forName: composerScriptMessageName)
        webView.configuration.userContentController.add(self, name: composerScriptMessageName)
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
        webView.evaluateJavaScript(source, completionHandler: nil)
    }

    private func installKeyboardObservers() {
        guard !keyboardObserversInstalled else { return }
        keyboardObserversInstalled = true
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func startStateSyncTimer() {
        stateSyncTimer?.invalidate()
        stateSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.syncComposerAvailabilityFromPage()
        }
        stateSyncTimer?.tolerance = 0.2
        syncComposerAvailabilityFromPage()
    }

    private func syncComposerAvailabilityFromPage() {
        let script = """
        (function() {
          if (document.body) {
            document.body.classList.add('native-compose-enabled');
            document.body.classList.add('native-tab-shell-enabled');
          }
            const username = document.querySelector('.account-trigger-copy span') ? document.querySelector('.account-trigger-copy span').textContent.replace(/^@/, '').trim() : '';
            const path = window.location.pathname || '/';
            let primarySection = 'feed';
            if (path.startsWith('/messages')) {
              primarySection = 'messages';
            } else if (path.startsWith('/search')) {
              primarySection = 'search';
            } else if (path.startsWith('/users/')) {
              primarySection = 'profile';
            }
            return {
              loggedIn: !!(document.body && document.body.classList.contains('app-body')),
              username: username,
              isFeed: !!document.querySelector('.home-flow'),
              canCompose: !!document.querySelector('.home-flow .composer form'),
              feedMode: (document.querySelector('#live-feed') && document.querySelector('#live-feed').dataset.feedMode) || 'home',
              primarySection: primarySection,
              currentRoute: `${window.location.pathname || '/'}${window.location.search || ''}`,
              scrollTop: (() => {
                const scrollRoot = document.querySelector('[data-app-scroll-root]') || document.querySelector('main.content, main.guest-shell');
                if (scrollRoot && typeof scrollRoot.scrollTop === 'number') {
                  return scrollRoot.scrollTop;
                }
                return window.scrollY || 0;
              })()
            };
        })();
        """
        webView?.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self else { return }
            if let payload = result as? [String: Any] {
                let loggedIn = payload["loggedIn"] as? Bool ?? false
                let isFeed = payload["isFeed"] as? Bool ?? false
                let canCompose = payload["canCompose"] as? Bool ?? false
                let username = payload["username"] as? String ?? ""
                self.currentFeedTab = payload["feedMode"] as? String ?? "home"
                let payloadRoute = payload["currentRoute"] as? String ?? ""
                let payloadSection = PrimarySection(rawValue: payload["primarySection"] as? String ?? "feed") ?? .feed
                let shouldPreserveNativeMessages = self.isShowingNativeMessages && !payloadRoute.starts(with: "/messages")
                if !shouldPreserveNativeMessages {
                    self.currentPrimarySection = payloadSection
                }
                self.currentUsername = username
                if !shouldPreserveNativeMessages, !payloadRoute.isEmpty {
                    self.currentRoute = payloadRoute
                    self.lastRouteBySection[self.currentPrimarySection] = payloadRoute
                } else if self.currentPrimarySection == .messages {
                    self.currentRoute = self.lastRouteBySection[.messages] ?? "/messages"
                }
                if !username.isEmpty {
                    self.lastRouteBySection[.profile] = "/users/\(username)"
                }
                self.handleLoginState(loggedIn: loggedIn, username: username)
                self.setComposeButtonVisible(loggedIn && isFeed && canCompose, animated: true)
                self.updateNativeTabSelection(animated: true)
                self.prefetchPrimaryRoutesIfNeeded(username: username)
                self.updateNativeSectionPresentation()
            }
        }
    }

    private func handleLoginState(loggedIn: Bool, username: String) {
        let wasLoggedIn = isLoggedIntoWebApp
        isLoggedIntoWebApp = loggedIn
        setNativeTabBarVisible(loggedIn, animated: true)
        guard loggedIn else {
            lastRegisteredPushToken = nil
            warmedRoutesForUsername = nil
            currentRoute = "/"
            nativeMessageTarget = nil
            nativeMessageConversations = []
            nativeThreadMessages = []
            lastRouteBySection = [
                .messages: "/messages",
                .feed: "/",
                .search: "/search"
            ]
            nativeMessagesListTableView.reloadData()
            nativeThreadTableView.reloadData()
            hideNativeMessagesIfNeeded()
            return
        }
        if !wasLoggedIn {
            maybeRequestNotificationPermission(for: username)
        }
        if !username.isEmpty {
            lastRouteBySection[.profile] = "/users/\(username)"
        }
    }

    private func observePushToken() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePushTokenNotification(_:)),
            name: .piaDidRegisterPushToken,
            object: nil
        )
    }

    private func maybeRequestNotificationPermission(for username: String) {
        let promptKey = "pia.notifications.prompted.\(username.isEmpty ? "default" : username)"
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .notDetermined:
                if UserDefaults.standard.bool(forKey: promptKey) {
                    return
                }
                UserDefaults.standard.set(true, forKey: promptKey)
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    @objc private func handlePushTokenNotification(_ note: Notification) {
        guard isLoggedIntoWebApp,
              let token = note.userInfo?["token"] as? String,
              !token.isEmpty,
              token != lastRegisteredPushToken else { return }
        lastRegisteredPushToken = token
        registerPushToken(token)
    }

    private func registerPushToken(_ token: String) {
        guard let targetURL = URL(string: "/push/register", relativeTo: webView?.url)?.absoluteURL else { return }
        fetchCookieHeader { cookieHeader in
            var request = URLRequest(url: targetURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("fetch", forHTTPHeaderField: "X-Requested-With")
            if let cookieHeader, !cookieHeader.isEmpty {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["endpoint": "apns:\(token)"], options: [])
            URLSession.shared.dataTask(with: request).resume()
        }
    }

    private func setComposeButtonVisible(_ visible: Bool, animated: Bool) {
        nativeComposerAvailable = visible
        if visible {
            composeButton.isHidden = false
        }
        let changes = {
            self.composeButton.alpha = visible ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.22, animations: changes) { _ in
                if !visible {
                    self.composeButton.isHidden = true
                }
            }
        } else {
            changes()
            if !visible {
                composeButton.isHidden = true
            }
        }
        if !visible {
            dismissComposerSheet(animated: false)
        }
    }

    @objc private func showComposer() {
        composerDimView.isHidden = false
        composerSheet.isHidden = false
        composerPlaceholder.isHidden = !composerTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        view.layoutIfNeeded()
        composerSheetBottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut]) {
            self.composerDimView.alpha = 1
            self.composerSheet.alpha = 1
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.composerTextView.becomeFirstResponder()
        }
    }

    @objc private func dismissComposer() {
        dismissComposerSheet(animated: true)
    }

    private func dismissComposerSheet(animated: Bool) {
        composerTextView.resignFirstResponder()
        let reset = {
            self.composerDimView.alpha = 0
            self.composerSheet.alpha = 0
            self.composerSheetBottomConstraint?.constant = 360
            self.view.layoutIfNeeded()
        }
        let completion: (Bool) -> Void = { _ in
            self.composerDimView.isHidden = true
            self.composerSheet.isHidden = true
            self.composerPostButton.isEnabled = true
            self.composerPostButton.alpha = 1
            if !self.isPostingComposer {
                self.composerTextView.text = ""
                self.clearSelectedImage()
                self.textViewDidChange(self.composerTextView)
            }
        }
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: reset, completion: completion)
        } else {
            reset()
            completion(true)
        }
    }

    @objc private func handleKeyboardWillChange(_ note: Notification) {
        var shouldAnimate = false
        if isShowingNativeMessages, !nativeThreadContainer.isHidden,
           let frameValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardFrame = view.convert(frameValue.cgRectValue, from: nil)
            let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
            nativeThreadComposerBottomConstraint?.constant = -(overlap - view.safeAreaInsets.bottom) - 8
            shouldAnimate = true
        }
        if !composerSheet.isHidden,
           let frameValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardFrame = view.convert(frameValue.cgRectValue, from: nil)
            let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
            composerSheetBottomConstraint?.constant = max(0, -view.safeAreaInsets.bottom) - overlap + view.safeAreaInsets.bottom
            shouldAnimate = true
        }
        if shouldAnimate {
            animateWithKeyboard(note)
        }
    }

    @objc private func handleKeyboardWillHide(_ note: Notification) {
        var shouldAnimate = false
        if isShowingNativeMessages, !nativeThreadContainer.isHidden {
            nativeThreadComposerBottomConstraint?.constant = -14
            shouldAnimate = true
        }
        if !composerSheet.isHidden {
            composerSheetBottomConstraint?.constant = 0
            shouldAnimate = true
        }
        if shouldAnimate {
            animateWithKeyboard(note)
        }
    }

    private func animateWithKeyboard(_ note: Notification) {
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curveRaw = (note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func postFromNativeComposer() {
        let body = composerTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty || selectedImageData != nil else { return }
        guard let targetURL = URL(string: "/post/create", relativeTo: webView?.url)?.absoluteURL else { return }

        isPostingComposer = true
        composerPostButton.isEnabled = false
        composerPostButton.alpha = 0.75

        let imageData = selectedImageData
        let imageName = selectedImageName
        let imageMimeType = selectedImageMimeType

        composerTextView.text = ""
        clearSelectedImage()
        textViewDidChange(composerTextView)
        dismissComposerSheet(animated: true)

        fetchCookieHeader { [weak self] cookieHeader in
            guard let self else { return }
            let boundary = "Boundary-\(UUID().uuidString)"
            var request = URLRequest(url: targetURL)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("fetch", forHTTPHeaderField: "X-Requested-With")
            if let cookieHeader, !cookieHeader.isEmpty {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            request.httpBody = self.multipartBody(
                boundary: boundary,
                body: body,
                feedTab: self.currentFeedTab == "breaking" ? "breaking" : "home",
                imageData: imageData,
                imageName: imageName,
                mimeType: imageMimeType
            )

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.isPostingComposer = false
                    guard error == nil,
                          let data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let ok = json["ok"] as? Bool,
                          ok,
                          let html = json["html"] as? String else {
                        self.showNativeFlash(message: "Post failed. Try again.", category: "error")
                        return
                    }

                    let latestPostID = (json["latest_post_id"] as? NSNumber)?.intValue ?? (json["post_id"] as? NSNumber)?.intValue ?? 0
                    self.injectPostedCard(html: html, latestPostID: latestPostID)
                    self.showNativeFlash(message: "Posted.", category: "success")
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            task.resume()
        }
    }

    private func injectPostedCard(html: String, latestPostID: Int) {
        guard let payloadData = try? JSONSerialization.data(withJSONObject: ["html": html, "latest_post_id": latestPostID], options: []),
              let payloadJSON = String(data: payloadData, encoding: .utf8) else { return }
        let script = "window.nativeInsertPostCard && window.nativeInsertPostCard(\(payloadJSON));"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func showNativeFlash(message: String, category: String) {
        guard let payloadData = try? JSONSerialization.data(withJSONObject: ["message": message, "category": category], options: []),
              let payloadJSON = String(data: payloadData, encoding: .utf8) else { return }
        let script = "window.showTransientFlash && window.showTransientFlash(\(payloadJSON).message, \(payloadJSON).category);"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func fetchCookieHeader(completion: @escaping (String?) -> Void) {
        guard let cookieStore = webView?.configuration.websiteDataStore.httpCookieStore else {
            completion(nil)
            return
        }
        cookieStore.getAllCookies { cookies in
            let header = cookies
                .filter { $0.domain.contains("railway.app") || $0.domain.contains("media-production-0abd.up.railway.app") || $0.domain.isEmpty }
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            completion(header.isEmpty ? nil : header)
        }
    }

    private func performNativeJSONRequest(path: String, method: String = "GET", bodyObject: Any? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let targetURL = URL(string: path, relativeTo: webView?.url)?.absoluteURL else {
            completion(.failure(NSError(domain: "NativeMessages", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid request URL."])))
            return
        }
        fetchCookieHeader { cookieHeader in
            var request = URLRequest(url: targetURL)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("fetch", forHTTPHeaderField: "X-Requested-With")
            if method != "GET" {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            if let cookieHeader, !cookieHeader.isEmpty {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            if let bodyObject {
                request.httpBody = try? JSONSerialization.data(withJSONObject: bodyObject)
            }
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                completion(.success(data ?? Data()))
            }.resume()
        }
    }

    private func parseNativeUserSummary(from raw: [String: Any]) -> NativeUserSummary? {
        let id = (raw["id"] as? Int) ?? (raw["id"] as? NSNumber)?.intValue ?? 0
        guard id >= 0,
              let username = raw["username"] as? String else { return nil }
        return NativeUserSummary(
            id: id,
            username: username,
            display_name: raw["display_name"] as? String ?? username,
            avatar_url: raw["avatar_url"] as? String ?? "",
            avatar_emoji: raw["avatar_emoji"] as? String ?? "🦅",
            use_emoji: raw["use_emoji"] as? Bool ?? true,
            is_verified: raw["is_verified"] as? Bool ?? false,
            is_creator: raw["is_creator"] as? Bool ?? false
        )
    }

    private func parseNativeThreadMessage(from raw: [String: Any]) -> NativeThreadMessage? {
        guard let id = raw["id"] as? Int,
              let body = raw["body"] as? String,
              let senderRaw = raw["sender"] as? [String: Any],
              let receiverRaw = raw["receiver"] as? [String: Any],
              let sender = parseNativeUserSummary(from: senderRaw),
              let receiver = parseNativeUserSummary(from: receiverRaw) else { return nil }
        return NativeThreadMessage(
            id: id,
            body: body,
            is_mine: raw["is_mine"] as? Bool ?? false,
            is_read: raw["is_read"] as? Bool ?? false,
            created_at: raw["created_at"] as? String ?? "",
            created_at_relative: raw["created_at_relative"] as? String ?? "",
            sender: sender,
            receiver: receiver
        )
    }

    private func parseNativeThreadPayload(from data: Data) -> (ok: Bool, target: NativeUserSummary?, messages: [NativeThreadMessage], error: String?)? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let ok = object["ok"] as? Bool ?? false
        let target = (object["target"] as? [String: Any]).flatMap(parseNativeUserSummary(from:))
        let messages = ((object["messages"] as? [[String: Any]]) ?? []).compactMap(parseNativeThreadMessage(from:))
        let error = object["error"] as? String
        return (ok, target, messages, error)
    }

    private func parseNativeSendMessagePayload(from data: Data) -> (ok: Bool, message: NativeThreadMessage?, error: String?)? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let ok = object["ok"] as? Bool ?? false
        let message = (object["message"] as? [String: Any]).flatMap(parseNativeThreadMessage(from:))
        let error = object["error"] as? String
        return (ok, message, error)
    }

    private func loadNativeInbox() {
        guard isLoggedIntoWebApp, !isLoadingNativeInbox else { return }
        isLoadingNativeInbox = true
        nativeThreadLoadingView.startAnimating()
        performNativeJSONRequest(path: "/api/messages/inbox") { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingNativeInbox = false
                self.nativeThreadLoadingView.stopAnimating()
                switch result {
                case .success(let data):
                    if let payload = try? JSONDecoder().decode(NativeInboxResponse.self, from: data) {
                        self.nativeMessageConversations = payload.conversations
                        self.nativeMessagesListTableView.reloadData()
                        self.nativeMessagesEmptyLabel.isHidden = !payload.conversations.isEmpty || !self.nativeThreadContainer.isHidden
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private func presentNativeThreadShell(for target: NativeUserSummary) {
        nativeMessageTarget = target
        nativeThreadTitleLabel.text = target.display_name
        nativeThreadVerifiedBadgeView.isHidden = !target.is_verified
        nativeThreadSubtitleLabel.text = "@\(target.username)"
        nativeThreadAvatarView.configure(with: target, imageCache: nativeAvatarImageCache)
        nativeMessagesSubtitle.isHidden = true
        nativeMessagesListTableView.isHidden = true
        nativeMessagesEmptyLabel.isHidden = true
        nativeThreadContainer.isHidden = false
        nativeThreadContainer.alpha = 1
        nativeThreadContainer.transform = .identity
        nativeThreadComposerBar.isHidden = false
        nativeThreadTableView.isHidden = false
        nativeThreadEmptyLabel.isHidden = true
        nativeThreadComposerBottomConstraint?.constant = -14
        updateNativeThreadComposeState()
        view.layoutIfNeeded()
    }

    private func loadNativeThread(username: String, animate: Bool = true) {
        guard isLoggedIntoWebApp, !isLoadingNativeThread else { return }
        isLoadingNativeThread = true
        var fallbackTarget: NativeUserSummary?
        if let conversation = nativeMessageConversations.first(where: { $0.username == username }) {
            let target = NativeUserSummary(
                id: conversation.id,
                username: conversation.username,
                display_name: conversation.display_name,
                avatar_url: conversation.avatar_url,
                avatar_emoji: conversation.avatar_emoji,
                use_emoji: conversation.use_emoji,
                is_verified: conversation.is_verified,
                is_creator: conversation.is_creator
            )
            fallbackTarget = target
            presentNativeThreadShell(for: target)
        } else if let existingTarget = nativeMessageTarget, existingTarget.username == username {
            fallbackTarget = existingTarget
            presentNativeThreadShell(for: existingTarget)
        }
        nativeThreadMessages = []
        nativeThreadTableView.reloadData()
        nativeThreadEmptyLabel.isHidden = true
        nativeThreadLoadingView.startAnimating()
        if animate {
            nativeThreadContainer.transform = CGAffineTransform(translationX: 16, y: 0)
            nativeThreadContainer.alpha = 0.35
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
                self.nativeThreadContainer.alpha = 1
                self.nativeThreadContainer.transform = .identity
            }
        }
        performNativeJSONRequest(path: "/api/messages/thread?user=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username)") { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingNativeThread = false
                self.nativeThreadLoadingView.stopAnimating()
                switch result {
                case .success(let data):
                    guard let payload = self.parseNativeThreadPayload(from: data), payload.ok else {
                        let errorMessage = self.parseNativeThreadPayload(from: data)?.error ?? "We couldn’t load that conversation yet."
                        self.showNativeFlash(message: errorMessage, category: "error")
                        return
                    }
                    let target = payload.target ?? fallbackTarget ?? self.nativeMessageTarget
                    guard let target else {
                        self.showNativeFlash(message: "We couldn’t load that conversation yet.", category: "error")
                        return
                    }
                    self.nativeThreadMessages = payload.messages
                    self.presentNativeThreadShell(for: target)
                    self.lastRouteBySection[.messages] = "/messages?user=\(target.username)"
                    self.currentRoute = self.lastRouteBySection[.messages] ?? "/messages"
                    self.nativeThreadTableView.reloadData()
                    self.nativeThreadEmptyLabel.isHidden = !payload.messages.isEmpty
                    self.nativeThreadComposerBottomConstraint?.constant = -14
                    self.view.layoutIfNeeded()
                    self.nativeThreadTableView.layoutIfNeeded()
                    self.scrollNativeThreadToBottom(animated: animate)
                    self.nativeThreadContainer.alpha = 1
                    self.nativeThreadContainer.transform = .identity
                case .failure(let error):
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func scrollNativeThreadToBottom(animated: Bool) {
        guard !nativeThreadMessages.isEmpty else { return }
        let lastRow = nativeThreadMessages.count - 1
        nativeThreadTableView.layoutIfNeeded()
        nativeThreadTableView.scrollToRow(at: IndexPath(row: lastRow, section: 0), at: .bottom, animated: animated)
    }

    private func multipartBody(boundary: String, body: String, feedTab: String, imageData: Data?, imageName: String?, mimeType: String) -> Data {
        var data = Data()
        let lineBreak = "\r\n"
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"body\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append("\(body)\(lineBreak)".data(using: .utf8)!)
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"feed_tab\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append("\(feedTab)\(lineBreak)".data(using: .utf8)!)
        if let imageData {
            let fileName = imageName ?? "upload.jpg"
            data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"media\"; filename=\"\(fileName)\"\(lineBreak)".data(using: .utf8)!)
            data.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            data.append(imageData)
            data.append(lineBreak.data(using: .utf8)!)
        }
        data.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return data
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == composerScriptMessageName,
              let payload = message.body as? [String: Any] else { return }
        let loggedIn = payload["loggedIn"] as? Bool ?? false
        let isFeed = payload["isFeed"] as? Bool ?? false
        let canCompose = payload["canCompose"] as? Bool ?? false
        let username = payload["username"] as? String ?? ""
        currentFeedTab = payload["feedMode"] as? String ?? "home"
        let payloadRoute = payload["currentRoute"] as? String ?? ""
        let payloadSection = PrimarySection(rawValue: payload["primarySection"] as? String ?? "feed") ?? .feed
        let shouldPreserveNativeMessages = isShowingNativeMessages && !payloadRoute.starts(with: "/messages")
        if !shouldPreserveNativeMessages {
            currentPrimarySection = payloadSection
        }
        currentUsername = username
        if !shouldPreserveNativeMessages, !payloadRoute.isEmpty {
            currentRoute = payloadRoute
            lastRouteBySection[currentPrimarySection] = payloadRoute
        } else if currentPrimarySection == .messages {
            currentRoute = lastRouteBySection[.messages] ?? "/messages"
        }
        if !username.isEmpty {
            lastRouteBySection[.profile] = "/users/\(username)"
        }
        DispatchQueue.main.async {
            self.handleLoginState(loggedIn: loggedIn, username: username)
            self.setComposeButtonVisible(loggedIn && isFeed && canCompose, animated: true)
            self.updateNativeTabSelection(animated: true)
            self.prefetchPrimaryRoutesIfNeeded(username: username)
            self.updateNativeSectionPresentation()
        }
    }

    private func prefetchPrimaryRoutesIfNeeded(username: String) {
        guard isLoggedIntoWebApp, !username.isEmpty, warmedRoutesForUsername != username else { return }
        warmedRoutesForUsername = username
        let escapedUsername = username
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "window.nativePrefetchPrimaryRoutes && window.nativePrefetchPrimaryRoutes(\"\(escapedUsername)\");"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    @objc private func handleNativeTabTap(_ sender: UIButton) {
        guard let section = section(for: sender.tag) else { return }
        openPrimarySection(section)
    }

    private func openPrimarySection(_ section: PrimarySection) {
        if section == .messages {
            currentPrimarySection = .messages
            updateNativeTabSelection(animated: true)
            updateNativeSectionPresentation()
            if let routeTarget = nativeMessageUsername(from: lastRouteBySection[.messages] ?? "/messages") {
                loadNativeThread(username: routeTarget, animate: false)
            } else {
                nativeMessagesSubtitle.isHidden = false
                nativeMessagesListTableView.isHidden = false
                nativeThreadContainer.isHidden = true
                nativeMessageTarget = nil
                nativeThreadMessages = []
                nativeThreadTableView.reloadData()
                loadNativeInbox()
            }
            return
        }
        let targetUsername = currentUsername
        let escapedUsername = targetUsername
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let preferredRoute = lastRouteBySection[section] ?? {
            switch section {
            case .messages: return "/messages"
            case .feed: return "/"
            case .search: return "/search"
            case .profile: return targetUsername.isEmpty ? "/" : "/users/\(targetUsername)"
            }
        }()
        let escapedRoute = preferredRoute
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        currentPrimarySection = section
        updateNativeTabSelection(animated: true)
        hideNativeMessagesIfNeeded()
        let script = "window.nativeOpenPrimaryRoute && window.nativeOpenPrimaryRoute(\"\(section.rawValue)\", \"\(escapedUsername)\", \"\(escapedRoute)\", true);"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    @objc private func handleNativeThreadBack() {
        nativeThreadTextView.resignFirstResponder()
        nativeThreadContainer.isHidden = true
        nativeThreadMessages = []
        nativeThreadTableView.reloadData()
        nativeThreadEmptyLabel.isHidden = true
        nativeThreadComposerBottomConstraint?.constant = -14
        nativeMessageTarget = nil
        nativeMessagesSubtitle.isHidden = false
        nativeMessagesListTableView.isHidden = false
        currentRoute = "/messages"
        lastRouteBySection[.messages] = "/messages"
        nativeMessagesEmptyLabel.isHidden = !nativeMessageConversations.isEmpty
        updateNativeThreadComposeState()
    }

    @objc private func handleNativeMessageSend() {
        guard let target = nativeMessageTarget else { return }
        let body = nativeThreadTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSendingNativeMessage else { return }
        isSendingNativeMessage = true
        updateNativeThreadComposeState()
        performNativeJSONRequest(path: "/api/messages/send", method: "POST", bodyObject: ["receiver": target.username, "body": body]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSendingNativeMessage = false
                switch result {
                case .success(let data):
                    guard let payload = self.parseNativeSendMessagePayload(from: data), payload.ok, let message = payload.message else {
                        if let payload = self.parseNativeSendMessagePayload(from: data), let error = payload.error, !error.isEmpty {
                            self.showNativeFlash(message: error, category: "error")
                        }
                        self.updateNativeThreadComposeState()
                        return
                    }
                    self.nativeThreadTextView.text = ""
                    self.nativeThreadMessages.append(message)
                    self.nativeThreadTableView.reloadData()
                    self.scrollNativeThreadToBottom(animated: true)
                    if let convoIndex = self.nativeMessageConversations.firstIndex(where: { $0.username == target.username }) {
                        self.nativeMessageConversations[convoIndex].latest_message = message.body
                        self.nativeMessageConversations[convoIndex].latest_message_relative = message.created_at_relative
                        self.nativeMessageConversations[convoIndex].latest_message_at = message.created_at
                        let updated = self.nativeMessageConversations.remove(at: convoIndex)
                        self.nativeMessageConversations.insert(updated, at: 0)
                    } else {
                        var newConversation = NativeMessageConversation(from: target)
                        newConversation.latest_message = message.body
                        newConversation.latest_message_relative = message.created_at_relative
                        newConversation.latest_message_at = message.created_at
                        self.nativeMessageConversations.insert(newConversation, at: 0)
                    }
                    self.nativeMessagesListTableView.reloadData()
                    self.updateNativeThreadComposeState()
                case .failure:
                    self.updateNativeThreadComposeState()
                }
            }
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView === nativeThreadTextView {
            nativeThreadPlaceholder.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let targetHeight = min(max(textView.contentSize.height, 24), 104)
            textView.constraints.first(where: { $0.firstAttribute == .height })?.constant = targetHeight
            updateNativeThreadComposeState()
            UIView.animate(withDuration: 0.14) {
                self.view.layoutIfNeeded()
            }
            return
        }
        composerPlaceholder.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let targetHeight = min(max(textView.contentSize.height, 92), 180)
        composerTextViewHeightConstraint?.constant = targetHeight
        composerPostButton.isEnabled = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
        composerPostButton.alpha = composerPostButton.isEnabled ? 1 : 0.55
        UIView.animate(withDuration: 0.14) {
            self.view.layoutIfNeeded()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === nativeMessagesListTableView {
            return nativeMessageConversations.count
        }
        return nativeThreadMessages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView === nativeMessagesListTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: NativeConversationCell.reuseIdentifier, for: indexPath) as! NativeConversationCell
            cell.configure(with: nativeMessageConversations[indexPath.row], imageCache: nativeAvatarImageCache)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: NativeThreadMessageCell.reuseIdentifier, for: indexPath) as! NativeThreadMessageCell
        cell.configure(with: nativeThreadMessages[indexPath.row], imageCache: nativeAvatarImageCache)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView === nativeMessagesListTableView {
            let conversation = nativeMessageConversations[indexPath.row]
            presentNativeThreadShell(for: NativeUserSummary(
                id: conversation.id,
                username: conversation.username,
                display_name: conversation.display_name,
                avatar_url: conversation.avatar_url,
                avatar_emoji: conversation.avatar_emoji,
                use_emoji: conversation.use_emoji,
                is_verified: conversation.is_verified,
                is_creator: conversation.is_creator
            ))
            loadNativeThread(username: conversation.username)
        }
    }

    @objc private func openPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        picker.modalPresentationStyle = .pageSheet
        present(picker, animated: true)
    }

    @objc private func removeSelectedPhoto() {
        clearSelectedImage()
        textViewDidChange(composerTextView)
    }

    private func clearSelectedImage() {
        selectedImageData = nil
        selectedImageName = nil
        selectedImageMimeType = "image/jpeg"
        composerPreviewImageView.image = nil
        composerPreviewContainer.isHidden = true
        composerPreviewHeightConstraint?.constant = 0
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self, let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self.composerPreviewImageView.image = image
                    self.composerPreviewContainer.isHidden = false
                    self.composerPreviewHeightConstraint?.constant = 140
                    self.selectedImageData = image.jpegData(compressionQuality: 0.88)
                    self.selectedImageName = "photo.jpg"
                    self.selectedImageMimeType = "image/jpeg"
                    self.textViewDidChange(self.composerTextView)
                }
            }
        }
    }
}

private struct NativeInboxResponse: Decodable {
    let conversations: [NativeMessageConversation]
}

private struct NativeThreadResponse: Decodable {
    let ok: Bool
    let target: NativeUserSummary
    let messages: [NativeThreadMessage]
}

private struct NativeSendMessageResponse: Decodable {
    let ok: Bool
    let message: NativeThreadMessage?
}

private struct NativeUserSummary: Decodable {
    let id: Int
    let username: String
    let display_name: String
    let avatar_url: String
    let avatar_emoji: String
    let use_emoji: Bool
    let is_verified: Bool
    let is_creator: Bool
}

private struct NativeMessageConversation: Decodable {
    let id: Int
    let username: String
    let display_name: String
    let avatar_url: String
    let avatar_emoji: String
    let use_emoji: Bool
    let is_verified: Bool
    let is_creator: Bool
    var latest_message: String
    var latest_message_relative: String
    var latest_message_at: String
    var unread_count: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case display_name
        case avatar_url
        case avatar_emoji
        case use_emoji
        case is_verified
        case is_creator
        case latest_message
        case latest_message_relative
        case latest_message_at
        case unread_count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        display_name = try container.decode(String.self, forKey: .display_name)
        avatar_url = try container.decode(String.self, forKey: .avatar_url)
        avatar_emoji = try container.decode(String.self, forKey: .avatar_emoji)
        use_emoji = try container.decode(Bool.self, forKey: .use_emoji)
        is_verified = try container.decode(Bool.self, forKey: .is_verified)
        is_creator = try container.decode(Bool.self, forKey: .is_creator)
        latest_message = try container.decodeIfPresent(String.self, forKey: .latest_message) ?? ""
        latest_message_relative = try container.decodeIfPresent(String.self, forKey: .latest_message_relative) ?? ""
        latest_message_at = try container.decodeIfPresent(String.self, forKey: .latest_message_at) ?? ""
        unread_count = try container.decodeIfPresent(Int.self, forKey: .unread_count) ?? 0
    }

    init(from user: NativeUserSummary) {
        id = user.id
        username = user.username
        display_name = user.display_name
        avatar_url = user.avatar_url
        avatar_emoji = user.avatar_emoji
        use_emoji = user.use_emoji
        is_verified = user.is_verified
        is_creator = user.is_creator
        latest_message = ""
        latest_message_relative = ""
        latest_message_at = ""
        unread_count = 0
    }
}

private struct NativeThreadMessage: Decodable {
    let id: Int
    let body: String
    let is_mine: Bool
    let is_read: Bool
    let created_at: String
    let created_at_relative: String
    let sender: NativeUserSummary
    let receiver: NativeUserSummary
}

private final class NativeAvatarView: UIView {
    private let backgroundCircle = UIView()
    private let imageView = UIImageView()
    private let emojiLabel = UILabel()
    private var currentAvatarKey: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundCircle.translatesAutoresizingMaskIntoConstraints = false
        backgroundCircle.backgroundColor = UIColor(red: 245.0 / 255.0, green: 236.0 / 255.0, blue: 244.0 / 255.0, alpha: 1)
        backgroundCircle.layer.cornerRadius = 24
        backgroundCircle.layer.cornerCurve = .continuous
        backgroundCircle.layer.borderWidth = 1
        backgroundCircle.layer.borderColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.08).cgColor
        addSubview(backgroundCircle)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 24
        imageView.layer.cornerCurve = .continuous
        imageView.isHidden = true
        addSubview(imageView)

        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.font = .systemFont(ofSize: 26)
        emojiLabel.textAlignment = .center
        addSubview(emojiLabel)

        NSLayoutConstraint.activate([
            backgroundCircle.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundCircle.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundCircle.topAnchor.constraint(equalTo: topAnchor),
            backgroundCircle.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            emojiLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with user: NativeUserSummary, imageCache: NSCache<NSString, UIImage>) {
        currentAvatarKey = user.avatar_url
        emojiLabel.text = user.avatar_emoji
        emojiLabel.isHidden = false
        if user.use_emoji || user.avatar_url.isEmpty {
            imageView.isHidden = true
            imageView.image = nil
            return
        }
        let cacheKey = NSString(string: user.avatar_url)
        if let cached = imageCache.object(forKey: cacheKey) {
            imageView.image = cached
            imageView.isHidden = false
            emojiLabel.isHidden = true
            return
        }
        imageView.isHidden = true
        imageView.image = nil
        guard let url = URL(string: user.avatar_url) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            imageCache.setObject(image, forKey: cacheKey)
            DispatchQueue.main.async {
                guard self.currentAvatarKey == user.avatar_url else { return }
                self.imageView.image = image
                self.imageView.isHidden = false
                self.emojiLabel.isHidden = true
            }
        }.resume()
    }
}

private final class NativeConversationCell: UITableViewCell {
    static let reuseIdentifier = "NativeConversationCell"

    private let cardView = UIView()
    private let avatarView = NativeAvatarView()
    private let nameLabel = UILabel()
    private let verifiedBadgeView = UIImageView()
    private let usernameLabel = UILabel()
    private let previewLabel = UILabel()
    private let metaLabel = UILabel()
    private let unreadBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        cardView.layer.cornerRadius = 24
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.08).cgColor
        contentView.addSubview(cardView)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(avatarView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 18, weight: .bold)
        nameLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        cardView.addSubview(nameLabel)

        verifiedBadgeView.translatesAutoresizingMaskIntoConstraints = false
        verifiedBadgeView.image = UIImage(systemName: "checkmark.seal.fill")
        verifiedBadgeView.tintColor = UIColor(red: 62.0 / 255.0, green: 164.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
        verifiedBadgeView.contentMode = .scaleAspectFit
        verifiedBadgeView.isHidden = true
        cardView.addSubview(verifiedBadgeView)

        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        usernameLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.92)
        cardView.addSubview(usernameLabel)

        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.font = .systemFont(ofSize: 15, weight: .medium)
        previewLabel.textColor = UIColor(red: 63.0 / 255.0, green: 75.0 / 255.0, blue: 101.0 / 255.0, alpha: 0.94)
        previewLabel.numberOfLines = 2
        cardView.addSubview(previewLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        metaLabel.textColor = UIColor(red: 107.0 / 255.0, green: 119.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.86)
        metaLabel.textAlignment = .right
        cardView.addSubview(metaLabel)

        unreadBadge.translatesAutoresizingMaskIntoConstraints = false
        unreadBadge.backgroundColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
        unreadBadge.textColor = .white
        unreadBadge.font = .systemFont(ofSize: 12, weight: .bold)
        unreadBadge.textAlignment = .center
        unreadBadge.layer.cornerRadius = 12
        unreadBadge.layer.cornerCurve = .continuous
        unreadBadge.clipsToBounds = true
        unreadBadge.isHidden = true
        cardView.addSubview(unreadBadge)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 52),
            avatarView.heightAnchor.constraint(equalToConstant: 52),

            metaLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            metaLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 14),
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),

            verifiedBadgeView.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            verifiedBadgeView.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            verifiedBadgeView.widthAnchor.constraint(equalToConstant: 18),
            verifiedBadgeView.heightAnchor.constraint(equalToConstant: 18),
            verifiedBadgeView.trailingAnchor.constraint(lessThanOrEqualTo: metaLabel.leadingAnchor, constant: -10),

            usernameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            usernameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            previewLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            previewLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            previewLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 10),
            previewLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),

            unreadBadge.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            unreadBadge.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),
            unreadBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
            unreadBadge.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with conversation: NativeMessageConversation, imageCache: NSCache<NSString, UIImage>) {
        nameLabel.text = conversation.display_name
        verifiedBadgeView.isHidden = !conversation.is_verified
        usernameLabel.text = "@\(conversation.username)"
        previewLabel.text = conversation.latest_message.isEmpty ? "Start a conversation" : conversation.latest_message
        metaLabel.text = conversation.latest_message_relative
        avatarView.configure(with: NativeUserSummary(id: conversation.id, username: conversation.username, display_name: conversation.display_name, avatar_url: conversation.avatar_url, avatar_emoji: conversation.avatar_emoji, use_emoji: conversation.use_emoji, is_verified: conversation.is_verified, is_creator: conversation.is_creator), imageCache: imageCache)
        if conversation.unread_count > 0 {
            unreadBadge.isHidden = false
            unreadBadge.text = conversation.unread_count > 9 ? "9+" : "\(conversation.unread_count)"
        } else {
            unreadBadge.isHidden = true
        }
    }
}

private final class NativeThreadMessageCell: UITableViewCell {
    static let reuseIdentifier = "NativeThreadMessageCell"

    private let stack = UIStackView()
    private let row = UIStackView()
    private let avatarView = NativeAvatarView()
    private let bubbleView = UIView()
    private let bodyLabel = UILabel()
    private let metaLabel = UILabel()
    private let spacer = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 6
        contentView.addSubview(stack)

        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .bottom
        row.spacing = 10
        stack.addArrangedSubview(row)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(avatarView)
        avatarView.widthAnchor.constraint(equalToConstant: 36).isActive = true
        avatarView.heightAnchor.constraint(equalToConstant: 36).isActive = true

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 20
        bubbleView.layer.cornerCurve = .continuous
        row.addArrangedSubview(bubbleView)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 17, weight: .medium)
        bodyLabel.numberOfLines = 0
        bubbleView.addSubview(bodyLabel)

        spacer.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(spacer)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        metaLabel.textColor = UIColor(red: 107.0 / 255.0, green: 119.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.84)
        stack.addArrangedSubview(metaLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            bodyLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
            bodyLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            bodyLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),

            bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with message: NativeThreadMessage, imageCache: NSCache<NSString, UIImage>) {
        avatarView.configure(with: message.sender, imageCache: imageCache)
        bodyLabel.text = message.body
        metaLabel.text = message.created_at_relative
        if message.is_mine {
            row.semanticContentAttribute = .forceRightToLeft
            stack.alignment = .trailing
            bubbleView.backgroundColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.95)
            bodyLabel.textColor = .white
            metaLabel.textAlignment = .right
            avatarView.isHidden = true
            spacer.isHidden = false
        } else {
            row.semanticContentAttribute = .forceLeftToRight
            stack.alignment = .leading
            bubbleView.backgroundColor = UIColor(red: 241.0 / 255.0, green: 245.0 / 255.0, blue: 252.0 / 255.0, alpha: 1)
            bodyLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
            metaLabel.textAlignment = .left
            avatarView.isHidden = false
            spacer.isHidden = true
        }
    }
}

private extension UIView {
    func hideInputAccessoryView() {
        guard let targetView = scrollViewContentView() else { return }
        let originalClass: AnyClass = object_getClass(targetView)!
        let className = String(cString: class_getName(originalClass)).appending("_NoInputAccessory")

        if let existingClass = NSClassFromString(className) {
            object_setClass(targetView, existingClass)
            return
        }

        guard let subclass = objc_allocateClassPair(originalClass, className, 0) else { return }
        if let method = class_getInstanceMethod(UIView.self, #selector(getter: UIView.inputAccessoryView)) {
            let block: @convention(block) (AnyObject) -> Any? = { _ in nil }
            class_addMethod(
                subclass,
                #selector(getter: UIView.inputAccessoryView),
                imp_implementationWithBlock(block),
                method_getTypeEncoding(method)
            )
        }
        objc_registerClassPair(subclass)
        object_setClass(targetView, subclass)
    }

    func scrollViewContentView() -> UIView? {
        if String(describing: type(of: self)).hasPrefix("WKContent") {
            return self
        }
        for subview in subviews {
            if let found = subview.scrollViewContentView() {
                return found
            }
        }
        return nil
    }
}
