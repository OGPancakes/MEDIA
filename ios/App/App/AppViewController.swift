import UIKit
import WebKit
import Capacitor
import ObjectiveC.runtime
import PhotosUI
import UserNotifications
import AVKit
import UniformTypeIdentifiers

final class AppViewController: CAPBridgeViewController, WKScriptMessageHandler, UITextViewDelegate, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching {
    private enum PrimarySection: String {
        case feed
        case messages
        case search
        case profile
    }

    private enum NativePhotoPickerPurpose {
        case post
        case story
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
    private let composerMentionsContainer = UIView()
    private let composerMentionsStack = UIStackView()
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
    private let nativeFeedContainer = UIView()
    private let nativeFeedHeader = UILabel()
    private let nativeFeedSegment = UISegmentedControl(items: ["Home", "FYP", "Breaking"])
    private let nativeFeedTableView = UITableView(frame: .zero, style: .plain)
    private let nativeFeedEmptyLabel = UILabel()
    private let nativeFeedRefreshControl = UIRefreshControl()
    private let nativeFeedStoriesHeader = NativeStoriesHeaderView()
    private let nativeProfileAvatarView = NativeAvatarView()
    private let nativeAccountButton = UIButton(type: .system)
    private let nativeAccountAvatarView = NativeAvatarView()
    private let nativeAccountDimView = UIControl()
    private let nativeAccountSheet = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let nativeAccountHandle = UIView()
    private let nativeAccountAvatarLargeView = NativeAvatarView()
    private let nativeAccountNameLabel = UILabel()
    private let nativeAccountUsernameLabel = UILabel()
    private let nativeAccountStack = UIStackView()
    private let nativePostDetailContainer = UIView()
    private let nativePostDetailBackButton = UIButton(type: .system)
    private let nativePostDetailTitleLabel = UILabel()
    private let nativePostDetailTableView = UITableView(frame: .zero, style: .plain)
    private let nativePostDetailEmptyLabel = UILabel()
    private let nativeProfileContainer = UIView()
    private let nativeProfileTableView = UITableView(frame: .zero, style: .plain)
    private let nativeProfileEmptyLabel = UILabel()
    private let nativeProfileHeaderView = NativeProfileHeaderView()
    private let nativeSearchContainer = UIView()
    private let nativeSearchTitleLabel = UILabel()
    private let nativeSearchField = UITextField()
    private let nativeSearchTableView = UITableView(frame: .zero, style: .plain)
    private let nativeSearchEmptyLabel = UILabel()
    private let nativeStoryViewer = NativeStoryViewerView()
    private let nativeConnectionsDimView = UIControl()
    private let nativeConnectionsSheet = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let nativeConnectionsHandle = UIView()
    private let nativeConnectionsTitleLabel = UILabel()
    private let nativeConnectionsCloseButton = UIButton(type: .system)
    private let nativeConnectionsTableView = UITableView(frame: .zero, style: .plain)
    private let nativeConnectionsEmptyLabel = UILabel()
    private let nativeCommentsDimView = UIControl()
    private let nativeCommentsSheet = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let nativeCommentsHandle = UIView()
    private let nativeCommentsTitleLabel = UILabel()
    private let nativeCommentsSubtitleLabel = UILabel()
    private let nativeCommentsCloseButton = UIButton(type: .system)
    private let nativeCommentsFullPostButton = UIButton(type: .system)
    private let nativeCommentsReplyingLabel = UILabel()
    private let nativeCommentsCancelReplyButton = UIButton(type: .system)
    private let nativeCommentsTableView = UITableView(frame: .zero, style: .plain)
    private let nativeCommentsComposerBar = UIView()
    private let nativeCommentsComposerAvatar = NativeAvatarView()
    private let nativeCommentsTextView = UITextView()
    private let nativeCommentsPlaceholder = UILabel()
    private let nativeCommentsSendButton = UIButton(type: .system)

    private var composerSheetBottomConstraint: NSLayoutConstraint?
    private var composeButtonBottomConstraint: NSLayoutConstraint?
    private var nativeCommentsSheetBottomConstraint: NSLayoutConstraint?
    private var nativeCommentsTextViewHeightConstraint: NSLayoutConstraint?
    private var composerTextViewHeightConstraint: NSLayoutConstraint?
    private var composerPreviewHeightConstraint: NSLayoutConstraint?
    private var nativeThreadComposerBottomConstraint: NSLayoutConstraint?
    private var nativeThreadTextViewHeightConstraint: NSLayoutConstraint?
    private var keyboardObserversInstalled = false
    private var nativeComposerAvailable = false
    private var isPostingComposer = false
    private var isLoggedIntoWebApp = false
    private var isShowingNativeFeed = false
    private var isShowingNativePostDetail = false
    private var isShowingNativeProfile = false
    private var isLoadingNativeFeed = false
    private var isLoadingNativePostDetail = false
    private var isLoadingNativeProfile = false
    private var isShowingNativeSearch = false
    private var isLoadingNativeSearch = false
    private var isLoadingNativeConnections = false
    private var isLoadingMentionSuggestions = false
    private var isShowingNativeMessages = false
    private var isLoadingNativeInbox = false
    private var isLoadingNativeThread = false
    private var isSendingNativeMessage = false
    private var isRefreshingNativeThread = false
    private var lastRegisteredPushToken: String?
    private var stateSyncTimer: Timer?
    private var nativeThreadRefreshTimer: Timer?
    private var selectedImageData: Data?
    private var selectedImageName: String?
    private var selectedImageMimeType = "image/jpeg"
    private var photoPickerPurpose: NativePhotoPickerPurpose = .post
    private var currentFeedTab = "home"
    private var currentUsername = ""
    private var currentRoute = "/"
    private var currentPrimarySection: PrimarySection = .feed
    private var currentKeyboardFrameInView: CGRect?
    private var warmedRoutesForUsername: String?
    private var pendingPushRoute: String?
    private var lastRouteBySection: [PrimarySection: String] = [
        .messages: "/messages",
        .feed: "/",
        .search: "/search"
    ]
    private var nativeMessageConversations: [NativeMessageConversation] = []
    private var nativeThreadMessages: [NativeThreadMessage] = []
    private var nativeFeedPosts: [NativeFeedPost] = []
    private var nativeFeedStories: [NativeFeedStory] = []
    private var nativeFeedPolls: [NativeFeedPoll] = []
    private var nativePostDetailPost: NativeFeedPost?
    private var nativePostDetailComments: [NativeComment] = []
    private var nativeProfileUser: NativeProfileUser?
    private var nativeProfilePosts: [NativeFeedPost] = []
    private var nativeSearchUsers: [NativeProfileUser] = []
    private var nativeSearchPosts: [NativeFeedPost] = []
    private var nativeConnectionsUsers: [NativeProfileUser] = []
    private var nativeCommentsPost: NativeFeedPost?
    private var nativeComments: [NativeComment] = []
    private var nativeCommentsReplyTarget: NativeComment?
    private var nativeFeedLatestPostID = 0
    private var nativeCurrentUser: NativeUserSummary?
    private var currentMentionSuggestions: [NativeMentionUser] = []
    private var activeMentionQuery = ""
    private var isApplyingComposerTextAttributes = false
    private var nativeMessageTarget: NativeUserSummary?
    private var nativeRouteOverrideUntil: Date?
    private var pendingNativeJSONRequests: [String: (Result<Data, Error>) -> Void] = [:]
    private let nativeAvatarImageCache = NSCache<NSString, UIImage>()
    private let nativeFeedImageCache = NSCache<NSString, UIImage>()

    private let composerScriptMessageName = "nativeComposerState"
    private let nativeJSONScriptMessageName = "nativeJSONResponse"

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
        configureNativeFeed()
        configureNativePostDetail()
        configureNativeProfile()
        configureNativeSearch()
        configureNativeStoryViewer()
        configureNativeConnections()
        configureNativeAccountMenu()
        configureNativeComments()
        configureNativeMessages()
        installKeyboardObservers()
        observePushToken()
        observePushNotificationTaps()
        installComposerBridge()
        startStateSyncTimer()
        consumeStoredPushRoute()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stateSyncTimer?.invalidate()
        nativeThreadRefreshTimer?.invalidate()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: composerScriptMessageName)
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: nativeJSONScriptMessageName)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
        if nativeFeedTableView.tableHeaderView === nativeFeedStoriesHeader,
           nativeFeedStoriesHeader.frame.width != nativeFeedTableView.bounds.width {
            resizeNativeFeedHeader()
        }
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
        composerDimView.layer.zPosition = 70
        composerDimView.addTarget(self, action: #selector(dismissComposer), for: .touchUpInside)
        view.addSubview(composerDimView)

        composerSheet.translatesAutoresizingMaskIntoConstraints = false
        composerSheet.effect = UIBlurEffect(style: .systemThinMaterial)
        composerSheet.layer.cornerRadius = 30
        composerSheet.layer.cornerCurve = .continuous
        composerSheet.clipsToBounds = true
        composerSheet.isHidden = true
        composerSheet.alpha = 0
        composerSheet.layer.zPosition = 72
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

        composerMentionsContainer.translatesAutoresizingMaskIntoConstraints = false
        composerMentionsContainer.backgroundColor = UIColor(red: 245.0 / 255.0, green: 248.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.95)
        composerMentionsContainer.layer.cornerRadius = 16
        composerMentionsContainer.layer.cornerCurve = .continuous
        composerMentionsContainer.layer.borderWidth = 1
        composerMentionsContainer.layer.borderColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.1).cgColor
        composerMentionsContainer.isHidden = true
        sheetContent.addSubview(composerMentionsContainer)

        composerMentionsStack.translatesAutoresizingMaskIntoConstraints = false
        composerMentionsStack.axis = .vertical
        composerMentionsStack.spacing = 4
        composerMentionsContainer.addSubview(composerMentionsStack)

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

            composerMentionsContainer.topAnchor.constraint(equalTo: composerTextView.bottomAnchor, constant: 6),
            composerMentionsContainer.leadingAnchor.constraint(equalTo: sheetContent.leadingAnchor, constant: 18),
            composerMentionsContainer.trailingAnchor.constraint(equalTo: sheetContent.trailingAnchor, constant: -18),
            composerMentionsStack.leadingAnchor.constraint(equalTo: composerMentionsContainer.leadingAnchor, constant: 8),
            composerMentionsStack.trailingAnchor.constraint(equalTo: composerMentionsContainer.trailingAnchor, constant: -8),
            composerMentionsStack.topAnchor.constraint(equalTo: composerMentionsContainer.topAnchor, constant: 8),
            composerMentionsStack.bottomAnchor.constraint(equalTo: composerMentionsContainer.bottomAnchor, constant: -8),

            composerPreviewContainer.topAnchor.constraint(equalTo: composerMentionsContainer.bottomAnchor, constant: 6),
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
        configureNativeProfileTabAvatar()

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

    private func configureNativeProfileTabAvatar() {
        profileTabButton.setTitle("", for: .normal)
        profileTabButton.accessibilityLabel = "Profile"
        nativeProfileAvatarView.translatesAutoresizingMaskIntoConstraints = false
        nativeProfileAvatarView.isUserInteractionEnabled = false
        profileTabButton.addSubview(nativeProfileAvatarView)
        NSLayoutConstraint.activate([
            nativeProfileAvatarView.centerXAnchor.constraint(equalTo: profileTabButton.centerXAnchor),
            nativeProfileAvatarView.centerYAnchor.constraint(equalTo: profileTabButton.centerYAnchor),
            nativeProfileAvatarView.widthAnchor.constraint(equalToConstant: 38),
            nativeProfileAvatarView.heightAnchor.constraint(equalToConstant: 38)
        ])
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
        nativeThreadTableView.contentInset = UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        nativeThreadTableView.dataSource = self
        nativeThreadTableView.delegate = self
        nativeThreadTableView.rowHeight = UITableView.automaticDimension
        nativeThreadTableView.estimatedRowHeight = 76
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
        nativeThreadTextView.returnKeyType = .default
        nativeThreadTextView.enablesReturnKeyAutomatically = false
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
        nativeThreadTextViewHeightConstraint = nativeThreadTextView.heightAnchor.constraint(equalToConstant: 44)

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
            nativeThreadTextViewHeightConstraint!,

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

    private func configureNativeFeed() {
        nativeFeedContainer.translatesAutoresizingMaskIntoConstraints = false
        nativeFeedContainer.alpha = 0
        nativeFeedContainer.isHidden = true
        nativeFeedContainer.backgroundColor = shellBackground
        nativeFeedContainer.isOpaque = true
        nativeFeedContainer.layer.zPosition = 30
        view.addSubview(nativeFeedContainer)

        nativeFeedHeader.translatesAutoresizingMaskIntoConstraints = false
        nativeFeedHeader.text = "Feed"
        nativeFeedHeader.font = .systemFont(ofSize: 34, weight: .bold)
        nativeFeedHeader.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativeFeedContainer.addSubview(nativeFeedHeader)

        nativeFeedSegment.translatesAutoresizingMaskIntoConstraints = false
        nativeFeedSegment.selectedSegmentIndex = 0
        nativeFeedSegment.addTarget(self, action: #selector(handleNativeFeedSegmentChanged), for: .valueChanged)
        nativeFeedContainer.addSubview(nativeFeedSegment)

        nativeFeedTableView.translatesAutoresizingMaskIntoConstraints = false
        nativeFeedTableView.backgroundColor = .clear
        nativeFeedTableView.separatorStyle = .none
        nativeFeedTableView.showsVerticalScrollIndicator = false
        nativeFeedTableView.keyboardDismissMode = .interactive
        nativeFeedTableView.rowHeight = UITableView.automaticDimension
        nativeFeedTableView.estimatedRowHeight = 280
        nativeFeedTableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 20, right: 0)
        nativeFeedTableView.dataSource = self
        nativeFeedTableView.delegate = self
        nativeFeedTableView.prefetchDataSource = self
        nativeFeedTableView.register(NativeFeedPostCell.self, forCellReuseIdentifier: NativeFeedPostCell.reuseIdentifier)
        nativeFeedTableView.register(NativeFeedPollCell.self, forCellReuseIdentifier: NativeFeedPollCell.reuseIdentifier)
        nativeFeedRefreshControl.addTarget(self, action: #selector(handleNativeFeedRefresh), for: .valueChanged)
        nativeFeedTableView.refreshControl = nativeFeedRefreshControl
        nativeFeedStoriesHeader.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 120)
        nativeFeedStoriesHeader.onAddStory = { [weak self] in
            self?.openNativeStoryComposer()
        }
        nativeFeedStoriesHeader.onOpenStory = { [weak self] story in
            self?.openNativeStory(story)
        }
        nativeFeedStoriesHeader.onDiscover = { [weak self] in
            self?.openPrimarySection(.search)
        }
        nativeFeedTableView.tableHeaderView = nativeFeedStoriesHeader
        nativeFeedContainer.addSubview(nativeFeedTableView)

        nativeFeedEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeFeedEmptyLabel.text = "No posts yet."
        nativeFeedEmptyLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nativeFeedEmptyLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.75)
        nativeFeedEmptyLabel.textAlignment = .center
        nativeFeedEmptyLabel.isHidden = true
        nativeFeedContainer.addSubview(nativeFeedEmptyLabel)

        NSLayoutConstraint.activate([
            nativeFeedContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeFeedContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeFeedContainer.topAnchor.constraint(equalTo: view.topAnchor),
            nativeFeedContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            nativeFeedHeader.leadingAnchor.constraint(equalTo: nativeFeedContainer.leadingAnchor, constant: 20),
            nativeFeedHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),

            nativeFeedSegment.leadingAnchor.constraint(equalTo: nativeFeedHeader.trailingAnchor, constant: 16),
            nativeFeedSegment.trailingAnchor.constraint(equalTo: nativeFeedContainer.trailingAnchor, constant: -20),
            nativeFeedSegment.centerYAnchor.constraint(equalTo: nativeFeedHeader.centerYAnchor),

            nativeFeedTableView.leadingAnchor.constraint(equalTo: nativeFeedContainer.leadingAnchor, constant: 10),
            nativeFeedTableView.trailingAnchor.constraint(equalTo: nativeFeedContainer.trailingAnchor, constant: -10),
            nativeFeedTableView.topAnchor.constraint(equalTo: nativeFeedHeader.bottomAnchor, constant: 14),
            nativeFeedTableView.bottomAnchor.constraint(equalTo: nativeTabBar.topAnchor, constant: -16),

            nativeFeedEmptyLabel.centerXAnchor.constraint(equalTo: nativeFeedTableView.centerXAnchor),
            nativeFeedEmptyLabel.centerYAnchor.constraint(equalTo: nativeFeedTableView.centerYAnchor)
        ])
    }

    private func configureNativePostDetail() {
        nativePostDetailContainer.translatesAutoresizingMaskIntoConstraints = false
        nativePostDetailContainer.alpha = 0
        nativePostDetailContainer.isHidden = true
        nativePostDetailContainer.backgroundColor = shellBackground
        nativePostDetailContainer.layer.zPosition = 34
        view.addSubview(nativePostDetailContainer)

        nativePostDetailBackButton.translatesAutoresizingMaskIntoConstraints = false
        nativePostDetailBackButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        nativePostDetailBackButton.tintColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativePostDetailBackButton.addTarget(self, action: #selector(closeNativePostDetail), for: .touchUpInside)
        nativePostDetailContainer.addSubview(nativePostDetailBackButton)

        nativePostDetailTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        nativePostDetailTitleLabel.text = "Post"
        nativePostDetailTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        nativePostDetailTitleLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativePostDetailContainer.addSubview(nativePostDetailTitleLabel)

        nativePostDetailTableView.translatesAutoresizingMaskIntoConstraints = false
        nativePostDetailTableView.backgroundColor = .clear
        nativePostDetailTableView.separatorStyle = .none
        nativePostDetailTableView.rowHeight = UITableView.automaticDimension
        nativePostDetailTableView.estimatedRowHeight = 160
        nativePostDetailTableView.dataSource = self
        nativePostDetailTableView.delegate = self
        nativePostDetailTableView.prefetchDataSource = self
        nativePostDetailTableView.register(NativeFeedPostCell.self, forCellReuseIdentifier: NativeFeedPostCell.reuseIdentifier)
        nativePostDetailTableView.register(NativeCommentCell.self, forCellReuseIdentifier: NativeCommentCell.reuseIdentifier)
        nativePostDetailContainer.addSubview(nativePostDetailTableView)

        nativePostDetailEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        nativePostDetailEmptyLabel.text = "Loading post..."
        nativePostDetailEmptyLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nativePostDetailEmptyLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.75)
        nativePostDetailEmptyLabel.textAlignment = .center
        nativePostDetailEmptyLabel.isHidden = true
        nativePostDetailContainer.addSubview(nativePostDetailEmptyLabel)

        NSLayoutConstraint.activate([
            nativePostDetailContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativePostDetailContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativePostDetailContainer.topAnchor.constraint(equalTo: view.topAnchor),
            nativePostDetailContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            nativePostDetailBackButton.leadingAnchor.constraint(equalTo: nativePostDetailContainer.leadingAnchor, constant: 14),
            nativePostDetailBackButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            nativePostDetailBackButton.widthAnchor.constraint(equalToConstant: 36),
            nativePostDetailBackButton.heightAnchor.constraint(equalToConstant: 36),
            nativePostDetailTitleLabel.leadingAnchor.constraint(equalTo: nativePostDetailBackButton.trailingAnchor, constant: 8),
            nativePostDetailTitleLabel.centerYAnchor.constraint(equalTo: nativePostDetailBackButton.centerYAnchor),
            nativePostDetailTableView.leadingAnchor.constraint(equalTo: nativePostDetailContainer.leadingAnchor, constant: 10),
            nativePostDetailTableView.trailingAnchor.constraint(equalTo: nativePostDetailContainer.trailingAnchor, constant: -10),
            nativePostDetailTableView.topAnchor.constraint(equalTo: nativePostDetailBackButton.bottomAnchor, constant: 8),
            nativePostDetailTableView.bottomAnchor.constraint(equalTo: nativeTabBar.topAnchor, constant: -16),
            nativePostDetailEmptyLabel.centerXAnchor.constraint(equalTo: nativePostDetailTableView.centerXAnchor),
            nativePostDetailEmptyLabel.centerYAnchor.constraint(equalTo: nativePostDetailTableView.centerYAnchor)
        ])
    }

    private func configureNativeProfile() {
        nativeProfileContainer.translatesAutoresizingMaskIntoConstraints = false
        nativeProfileContainer.alpha = 0
        nativeProfileContainer.isHidden = true
        nativeProfileContainer.backgroundColor = shellBackground
        nativeProfileContainer.layer.zPosition = 32
        view.addSubview(nativeProfileContainer)

        nativeProfileTableView.translatesAutoresizingMaskIntoConstraints = false
        nativeProfileTableView.backgroundColor = .clear
        nativeProfileTableView.separatorStyle = .none
        nativeProfileTableView.rowHeight = UITableView.automaticDimension
        nativeProfileTableView.estimatedRowHeight = 280
        nativeProfileTableView.dataSource = self
        nativeProfileTableView.delegate = self
        nativeProfileTableView.prefetchDataSource = self
        nativeProfileTableView.register(NativeFeedPostCell.self, forCellReuseIdentifier: NativeFeedPostCell.reuseIdentifier)
        nativeProfileHeaderView.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: nativeProfileHeaderView.preferredHeight)
        nativeProfileHeaderView.onFollowTap = { [weak self] in
            self?.toggleNativeProfileFollow()
        }
        nativeProfileHeaderView.onFollowersTap = { [weak self] in
            self?.presentNativeConnections(tab: "followers")
        }
        nativeProfileHeaderView.onFollowingTap = { [weak self] in
            self?.presentNativeConnections(tab: "following")
        }
        nativeProfileTableView.tableHeaderView = nativeProfileHeaderView
        nativeProfileContainer.addSubview(nativeProfileTableView)

        nativeProfileEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeProfileEmptyLabel.text = "Loading profile..."
        nativeProfileEmptyLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nativeProfileEmptyLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.75)
        nativeProfileEmptyLabel.textAlignment = .center
        nativeProfileEmptyLabel.isHidden = true
        nativeProfileContainer.addSubview(nativeProfileEmptyLabel)

        NSLayoutConstraint.activate([
            nativeProfileContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeProfileContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeProfileContainer.topAnchor.constraint(equalTo: view.topAnchor),
            nativeProfileContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            nativeProfileTableView.leadingAnchor.constraint(equalTo: nativeProfileContainer.leadingAnchor, constant: 10),
            nativeProfileTableView.trailingAnchor.constraint(equalTo: nativeProfileContainer.trailingAnchor, constant: -10),
            nativeProfileTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            nativeProfileTableView.bottomAnchor.constraint(equalTo: nativeTabBar.topAnchor, constant: -16),
            nativeProfileEmptyLabel.centerXAnchor.constraint(equalTo: nativeProfileTableView.centerXAnchor),
            nativeProfileEmptyLabel.centerYAnchor.constraint(equalTo: nativeProfileTableView.centerYAnchor)
        ])
    }

    private func configureNativeSearch() {
        nativeSearchContainer.translatesAutoresizingMaskIntoConstraints = false
        nativeSearchContainer.alpha = 0
        nativeSearchContainer.isHidden = true
        nativeSearchContainer.backgroundColor = shellBackground
        nativeSearchContainer.layer.zPosition = 31
        view.addSubview(nativeSearchContainer)

        nativeSearchTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeSearchTitleLabel.text = "Search"
        nativeSearchTitleLabel.font = .systemFont(ofSize: 42, weight: .bold)
        nativeSearchTitleLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativeSearchContainer.addSubview(nativeSearchTitleLabel)

        nativeSearchField.translatesAutoresizingMaskIntoConstraints = false
        nativeSearchField.placeholder = "Search people and posts"
        nativeSearchField.font = .systemFont(ofSize: 16, weight: .semibold)
        nativeSearchField.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativeSearchField.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        nativeSearchField.layer.cornerRadius = 22
        nativeSearchField.layer.cornerCurve = .continuous
        nativeSearchField.layer.borderWidth = 1
        nativeSearchField.layer.borderColor = UIColor(red: 207.0 / 255.0, green: 218.0 / 255.0, blue: 236.0 / 255.0, alpha: 0.82).cgColor
        nativeSearchField.clearButtonMode = .whileEditing
        nativeSearchField.returnKeyType = .search
        nativeSearchField.leftViewMode = .always
        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.75)
        searchIcon.contentMode = .center
        searchIcon.frame = CGRect(x: 0, y: 0, width: 42, height: 42)
        nativeSearchField.leftView = searchIcon
        nativeSearchField.addTarget(self, action: #selector(nativeSearchTextChanged), for: .editingChanged)
        nativeSearchField.addTarget(self, action: #selector(nativeSearchReturnPressed), for: .editingDidEndOnExit)
        nativeSearchContainer.addSubview(nativeSearchField)

        nativeSearchTableView.translatesAutoresizingMaskIntoConstraints = false
        nativeSearchTableView.backgroundColor = .clear
        nativeSearchTableView.separatorStyle = .none
        nativeSearchTableView.rowHeight = UITableView.automaticDimension
        nativeSearchTableView.estimatedRowHeight = 92
        nativeSearchTableView.keyboardDismissMode = .interactive
        nativeSearchTableView.dataSource = self
        nativeSearchTableView.delegate = self
        nativeSearchTableView.prefetchDataSource = self
        nativeSearchTableView.register(NativeConnectionCell.self, forCellReuseIdentifier: NativeConnectionCell.reuseIdentifier)
        nativeSearchTableView.register(NativeFeedPostCell.self, forCellReuseIdentifier: NativeFeedPostCell.reuseIdentifier)
        nativeSearchContainer.addSubview(nativeSearchTableView)

        nativeSearchEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeSearchEmptyLabel.text = "Start typing to find people and posts."
        nativeSearchEmptyLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nativeSearchEmptyLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.78)
        nativeSearchEmptyLabel.textAlignment = .center
        nativeSearchEmptyLabel.numberOfLines = 0
        nativeSearchContainer.addSubview(nativeSearchEmptyLabel)

        NSLayoutConstraint.activate([
            nativeSearchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeSearchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeSearchContainer.topAnchor.constraint(equalTo: view.topAnchor),
            nativeSearchContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            nativeSearchTitleLabel.leadingAnchor.constraint(equalTo: nativeSearchContainer.leadingAnchor, constant: 24),
            nativeSearchTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            nativeSearchField.leadingAnchor.constraint(equalTo: nativeSearchContainer.leadingAnchor, constant: 24),
            nativeSearchField.trailingAnchor.constraint(equalTo: nativeSearchContainer.trailingAnchor, constant: -24),
            nativeSearchField.topAnchor.constraint(equalTo: nativeSearchTitleLabel.bottomAnchor, constant: 18),
            nativeSearchField.heightAnchor.constraint(equalToConstant: 46),
            nativeSearchTableView.leadingAnchor.constraint(equalTo: nativeSearchContainer.leadingAnchor, constant: 10),
            nativeSearchTableView.trailingAnchor.constraint(equalTo: nativeSearchContainer.trailingAnchor, constant: -10),
            nativeSearchTableView.topAnchor.constraint(equalTo: nativeSearchField.bottomAnchor, constant: 12),
            nativeSearchTableView.bottomAnchor.constraint(equalTo: nativeTabBar.topAnchor, constant: -16),
            nativeSearchEmptyLabel.centerXAnchor.constraint(equalTo: nativeSearchTableView.centerXAnchor),
            nativeSearchEmptyLabel.centerYAnchor.constraint(equalTo: nativeSearchTableView.centerYAnchor),
            nativeSearchEmptyLabel.leadingAnchor.constraint(equalTo: nativeSearchTableView.leadingAnchor, constant: 24),
            nativeSearchEmptyLabel.trailingAnchor.constraint(equalTo: nativeSearchTableView.trailingAnchor, constant: -24)
        ])
    }

    private func configureNativeStoryViewer() {
        nativeStoryViewer.translatesAutoresizingMaskIntoConstraints = false
        nativeStoryViewer.alpha = 0
        nativeStoryViewer.isHidden = true
        nativeStoryViewer.layer.zPosition = 90
        nativeStoryViewer.onClose = { [weak self] in
            self?.dismissNativeStoryViewer()
        }
        nativeStoryViewer.onOpenVideo = { [weak self] url in
            self?.presentNativeVideo(url: url)
        }
        view.addSubview(nativeStoryViewer)
        NSLayoutConstraint.activate([
            nativeStoryViewer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeStoryViewer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeStoryViewer.topAnchor.constraint(equalTo: view.topAnchor),
            nativeStoryViewer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureNativeConnections() {
        nativeConnectionsDimView.translatesAutoresizingMaskIntoConstraints = false
        nativeConnectionsDimView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        nativeConnectionsDimView.alpha = 0
        nativeConnectionsDimView.isHidden = true
        nativeConnectionsDimView.layer.zPosition = 82
        nativeConnectionsDimView.addTarget(self, action: #selector(dismissNativeConnections), for: .touchUpInside)
        view.addSubview(nativeConnectionsDimView)

        nativeConnectionsSheet.translatesAutoresizingMaskIntoConstraints = false
        nativeConnectionsSheet.layer.cornerRadius = 28
        nativeConnectionsSheet.layer.cornerCurve = .continuous
        nativeConnectionsSheet.clipsToBounds = true
        nativeConnectionsSheet.alpha = 0
        nativeConnectionsSheet.isHidden = true
        nativeConnectionsSheet.layer.zPosition = 84
        view.addSubview(nativeConnectionsSheet)

        let content = nativeConnectionsSheet.contentView
        content.backgroundColor = UIColor.white.withAlphaComponent(0.96)

        nativeConnectionsHandle.translatesAutoresizingMaskIntoConstraints = false
        nativeConnectionsHandle.backgroundColor = UIColor(red: 16.0 / 255.0, green: 24.0 / 255.0, blue: 40.0 / 255.0, alpha: 0.16)
        nativeConnectionsHandle.layer.cornerRadius = 2.5
        nativeConnectionsHandle.layer.cornerCurve = .continuous
        content.addSubview(nativeConnectionsHandle)

        nativeConnectionsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeConnectionsTitleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        nativeConnectionsTitleLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativeConnectionsTitleLabel.textAlignment = .center
        content.addSubview(nativeConnectionsTitleLabel)

        nativeConnectionsCloseButton.translatesAutoresizingMaskIntoConstraints = false
        nativeConnectionsCloseButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        nativeConnectionsCloseButton.tintColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.72)
        nativeConnectionsCloseButton.addTarget(self, action: #selector(dismissNativeConnections), for: .touchUpInside)
        content.addSubview(nativeConnectionsCloseButton)

        nativeConnectionsTableView.translatesAutoresizingMaskIntoConstraints = false
        nativeConnectionsTableView.backgroundColor = .clear
        nativeConnectionsTableView.separatorStyle = .none
        nativeConnectionsTableView.rowHeight = UITableView.automaticDimension
        nativeConnectionsTableView.estimatedRowHeight = 82
        nativeConnectionsTableView.dataSource = self
        nativeConnectionsTableView.delegate = self
        nativeConnectionsTableView.register(NativeConnectionCell.self, forCellReuseIdentifier: NativeConnectionCell.reuseIdentifier)
        content.addSubview(nativeConnectionsTableView)

        nativeConnectionsEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeConnectionsEmptyLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nativeConnectionsEmptyLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.78)
        nativeConnectionsEmptyLabel.textAlignment = .center
        nativeConnectionsEmptyLabel.isHidden = true
        content.addSubview(nativeConnectionsEmptyLabel)

        NSLayoutConstraint.activate([
            nativeConnectionsDimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeConnectionsDimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeConnectionsDimView.topAnchor.constraint(equalTo: view.topAnchor),
            nativeConnectionsDimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            nativeConnectionsSheet.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            nativeConnectionsSheet.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            nativeConnectionsSheet.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            nativeConnectionsSheet.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.58),
            nativeConnectionsHandle.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            nativeConnectionsHandle.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            nativeConnectionsHandle.widthAnchor.constraint(equalToConstant: 44),
            nativeConnectionsHandle.heightAnchor.constraint(equalToConstant: 5),
            nativeConnectionsTitleLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 56),
            nativeConnectionsTitleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -56),
            nativeConnectionsTitleLabel.topAnchor.constraint(equalTo: nativeConnectionsHandle.bottomAnchor, constant: 14),
            nativeConnectionsCloseButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            nativeConnectionsCloseButton.centerYAnchor.constraint(equalTo: nativeConnectionsTitleLabel.centerYAnchor),
            nativeConnectionsCloseButton.widthAnchor.constraint(equalToConstant: 34),
            nativeConnectionsCloseButton.heightAnchor.constraint(equalToConstant: 34),
            nativeConnectionsTableView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            nativeConnectionsTableView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            nativeConnectionsTableView.topAnchor.constraint(equalTo: nativeConnectionsTitleLabel.bottomAnchor, constant: 10),
            nativeConnectionsTableView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
            nativeConnectionsEmptyLabel.centerXAnchor.constraint(equalTo: nativeConnectionsTableView.centerXAnchor),
            nativeConnectionsEmptyLabel.centerYAnchor.constraint(equalTo: nativeConnectionsTableView.centerYAnchor)
        ])
    }

    private func configureNativeAccountMenu() {
        nativeAccountButton.translatesAutoresizingMaskIntoConstraints = false
        nativeAccountButton.backgroundColor = UIColor.white.withAlphaComponent(0.84)
        nativeAccountButton.layer.cornerRadius = 22
        nativeAccountButton.layer.cornerCurve = .continuous
        nativeAccountButton.layer.borderWidth = 1
        nativeAccountButton.layer.borderColor = UIColor(red: 207.0 / 255.0, green: 218.0 / 255.0, blue: 236.0 / 255.0, alpha: 0.85).cgColor
        nativeAccountButton.layer.shadowColor = UIColor.black.cgColor
        nativeAccountButton.layer.shadowOpacity = 0.08
        nativeAccountButton.layer.shadowRadius = 12
        nativeAccountButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        nativeAccountButton.alpha = 0
        nativeAccountButton.isHidden = true
        nativeAccountButton.layer.zPosition = 70
        nativeAccountButton.addTarget(self, action: #selector(presentNativeAccountMenu), for: .touchUpInside)
        view.addSubview(nativeAccountButton)

        nativeAccountAvatarView.translatesAutoresizingMaskIntoConstraints = false
        nativeAccountAvatarView.isUserInteractionEnabled = false
        nativeAccountButton.addSubview(nativeAccountAvatarView)

        nativeAccountDimView.translatesAutoresizingMaskIntoConstraints = false
        nativeAccountDimView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        nativeAccountDimView.alpha = 0
        nativeAccountDimView.isHidden = true
        nativeAccountDimView.layer.zPosition = 86
        nativeAccountDimView.addTarget(self, action: #selector(dismissNativeAccountMenu), for: .touchUpInside)
        view.addSubview(nativeAccountDimView)

        nativeAccountSheet.translatesAutoresizingMaskIntoConstraints = false
        nativeAccountSheet.layer.cornerRadius = 28
        nativeAccountSheet.layer.cornerCurve = .continuous
        nativeAccountSheet.clipsToBounds = true
        nativeAccountSheet.alpha = 0
        nativeAccountSheet.isHidden = true
        nativeAccountSheet.layer.zPosition = 88
        view.addSubview(nativeAccountSheet)

        let content = nativeAccountSheet.contentView
        content.backgroundColor = UIColor.white.withAlphaComponent(0.96)

        nativeAccountHandle.translatesAutoresizingMaskIntoConstraints = false
        nativeAccountHandle.backgroundColor = UIColor(red: 16.0 / 255.0, green: 24.0 / 255.0, blue: 40.0 / 255.0, alpha: 0.16)
        nativeAccountHandle.layer.cornerRadius = 2.5
        nativeAccountHandle.layer.cornerCurve = .continuous
        content.addSubview(nativeAccountHandle)

        nativeAccountAvatarLargeView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(nativeAccountAvatarLargeView)

        nativeAccountNameLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeAccountNameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        nativeAccountNameLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        content.addSubview(nativeAccountNameLabel)

        nativeAccountUsernameLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeAccountUsernameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nativeAccountUsernameLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.86)
        content.addSubview(nativeAccountUsernameLabel)

        nativeAccountStack.translatesAutoresizingMaskIntoConstraints = false
        nativeAccountStack.axis = .vertical
        nativeAccountStack.spacing = 10
        content.addSubview(nativeAccountStack)

        addNativeAccountMenuButton(title: "View Profile", symbol: "person.crop.circle", route: nil)
        addNativeAccountMenuButton(title: "Settings", symbol: "gearshape.fill", route: "/settings")
        addNativeAccountMenuButton(title: "Saved", symbol: "bookmark.fill", route: "/saved")
        addNativeAccountMenuButton(title: "Admin", symbol: "shield.lefthalf.filled", route: "/admin")
        addNativeAccountMenuButton(title: "Log Out", symbol: "rectangle.portrait.and.arrow.right", route: "/logout")

        NSLayoutConstraint.activate([
            nativeAccountButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            nativeAccountButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            nativeAccountButton.widthAnchor.constraint(equalToConstant: 44),
            nativeAccountButton.heightAnchor.constraint(equalToConstant: 44),
            nativeAccountAvatarView.centerXAnchor.constraint(equalTo: nativeAccountButton.centerXAnchor),
            nativeAccountAvatarView.centerYAnchor.constraint(equalTo: nativeAccountButton.centerYAnchor),
            nativeAccountAvatarView.widthAnchor.constraint(equalToConstant: 34),
            nativeAccountAvatarView.heightAnchor.constraint(equalToConstant: 34),
            nativeAccountDimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeAccountDimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeAccountDimView.topAnchor.constraint(equalTo: view.topAnchor),
            nativeAccountDimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            nativeAccountSheet.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            nativeAccountSheet.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            nativeAccountSheet.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            nativeAccountSheet.heightAnchor.constraint(equalToConstant: 390),
            nativeAccountHandle.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            nativeAccountHandle.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            nativeAccountHandle.widthAnchor.constraint(equalToConstant: 44),
            nativeAccountHandle.heightAnchor.constraint(equalToConstant: 5),
            nativeAccountAvatarLargeView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            nativeAccountAvatarLargeView.topAnchor.constraint(equalTo: nativeAccountHandle.bottomAnchor, constant: 22),
            nativeAccountAvatarLargeView.widthAnchor.constraint(equalToConstant: 58),
            nativeAccountAvatarLargeView.heightAnchor.constraint(equalToConstant: 58),
            nativeAccountNameLabel.leadingAnchor.constraint(equalTo: nativeAccountAvatarLargeView.trailingAnchor, constant: 14),
            nativeAccountNameLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            nativeAccountNameLabel.topAnchor.constraint(equalTo: nativeAccountAvatarLargeView.topAnchor, constant: 4),
            nativeAccountUsernameLabel.leadingAnchor.constraint(equalTo: nativeAccountNameLabel.leadingAnchor),
            nativeAccountUsernameLabel.trailingAnchor.constraint(equalTo: nativeAccountNameLabel.trailingAnchor),
            nativeAccountUsernameLabel.topAnchor.constraint(equalTo: nativeAccountNameLabel.bottomAnchor, constant: 3),
            nativeAccountStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            nativeAccountStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            nativeAccountStack.topAnchor.constraint(equalTo: nativeAccountAvatarLargeView.bottomAnchor, constant: 20)
        ])
    }

    private func addNativeAccountMenuButton(title: String, symbol: String, route: String?) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        button.setTitleColor(UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.backgroundColor = UIColor(red: 242.0 / 255.0, green: 247.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
        button.layer.cornerRadius = 18
        button.layer.cornerCurve = .continuous
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: -10)
        button.contentHorizontalAlignment = .leading
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        button.addAction(UIAction { [weak self] _ in
            self?.handleNativeAccountMenuSelection(route: route)
        }, for: .touchUpInside)
        nativeAccountStack.addArrangedSubview(button)
    }

    private func updateNativeAccountAvatar() {
        guard let currentUser = nativeCurrentUser else { return }
        nativeAccountAvatarView.configure(with: currentUser, imageCache: nativeAvatarImageCache)
        nativeAccountAvatarLargeView.configure(with: currentUser, imageCache: nativeAvatarImageCache)
        nativeAccountNameLabel.text = currentUser.display_name
        nativeAccountUsernameLabel.text = "@\(currentUser.username)"
    }

    private func setNativeAccountButtonVisible(_ visible: Bool, animated: Bool) {
        let changes = {
            self.nativeAccountButton.alpha = visible ? 1 : 0
        }
        let completion: (Bool) -> Void = { _ in
            self.nativeAccountButton.isHidden = !visible
        }
        if animated {
            if visible { nativeAccountButton.isHidden = false }
            UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseOut], animations: changes, completion: completion)
        } else {
            nativeAccountButton.isHidden = !visible
            changes()
        }
    }

    @objc private func presentNativeAccountMenu() {
        updateNativeAccountAvatar()
        nativeAccountDimView.isHidden = false
        nativeAccountSheet.isHidden = false
        view.bringSubviewToFront(nativeAccountDimView)
        view.bringSubviewToFront(nativeAccountSheet)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.nativeAccountDimView.alpha = 1
            self.nativeAccountSheet.alpha = 1
        }
    }

    @objc private func dismissNativeAccountMenu() {
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseInOut]) {
            self.nativeAccountDimView.alpha = 0
            self.nativeAccountSheet.alpha = 0
        } completion: { _ in
            self.nativeAccountDimView.isHidden = true
            self.nativeAccountSheet.isHidden = true
        }
    }

    private func handleNativeAccountMenuSelection(route: String?) {
        dismissNativeAccountMenu()
        if let route {
            currentRoute = route
            if route == "/logout" {
                setNativeAccountButtonVisible(false, animated: true)
            }
            hideNativeFeedIfNeeded()
            hideNativeProfileIfNeeded()
            hideNativeSearchIfNeeded()
            hideNativeMessagesIfNeeded()
            navigateWebView(to: route, replace: false)
            return
        }
        openPrimarySection(.profile)
    }

    private func configureNativeComments() {
        nativeCommentsDimView.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsDimView.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        nativeCommentsDimView.alpha = 0
        nativeCommentsDimView.isHidden = true
        nativeCommentsDimView.layer.zPosition = 76
        nativeCommentsDimView.addTarget(self, action: #selector(dismissNativeComments), for: .touchUpInside)
        view.addSubview(nativeCommentsDimView)

        nativeCommentsSheet.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsSheet.layer.cornerRadius = 30
        nativeCommentsSheet.layer.cornerCurve = .continuous
        nativeCommentsSheet.clipsToBounds = true
        nativeCommentsSheet.alpha = 0
        nativeCommentsSheet.isHidden = true
        nativeCommentsSheet.layer.zPosition = 78
        view.addSubview(nativeCommentsSheet)

        let content = nativeCommentsSheet.contentView
        content.backgroundColor = UIColor.white.withAlphaComponent(0.96)

        nativeCommentsHandle.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsHandle.backgroundColor = UIColor(red: 16.0 / 255.0, green: 24.0 / 255.0, blue: 40.0 / 255.0, alpha: 0.16)
        nativeCommentsHandle.layer.cornerRadius = 2.5
        nativeCommentsHandle.layer.cornerCurve = .continuous
        content.addSubview(nativeCommentsHandle)

        nativeCommentsTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsTitleLabel.text = "Comments"
        nativeCommentsTitleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        nativeCommentsTitleLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativeCommentsTitleLabel.textAlignment = .center
        content.addSubview(nativeCommentsTitleLabel)

        nativeCommentsSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsSubtitleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nativeCommentsSubtitleLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.82)
        nativeCommentsSubtitleLabel.textAlignment = .center
        content.addSubview(nativeCommentsSubtitleLabel)

        nativeCommentsCloseButton.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsCloseButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        nativeCommentsCloseButton.tintColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.72)
        nativeCommentsCloseButton.addTarget(self, action: #selector(dismissNativeComments), for: .touchUpInside)
        content.addSubview(nativeCommentsCloseButton)

        nativeCommentsFullPostButton.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsFullPostButton.setTitle("View post", for: .normal)
        nativeCommentsFullPostButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        nativeCommentsFullPostButton.setTitleColor(UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1), for: .normal)
        nativeCommentsFullPostButton.addTarget(self, action: #selector(openNativeCommentsFullPost), for: .touchUpInside)
        content.addSubview(nativeCommentsFullPostButton)

        nativeCommentsReplyingLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsReplyingLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nativeCommentsReplyingLabel.textColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.86)
        nativeCommentsReplyingLabel.isHidden = true
        content.addSubview(nativeCommentsReplyingLabel)

        nativeCommentsCancelReplyButton.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsCancelReplyButton.setTitle("Cancel", for: .normal)
        nativeCommentsCancelReplyButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        nativeCommentsCancelReplyButton.setTitleColor(UIColor(red: 191.0 / 255.0, green: 10.0 / 255.0, blue: 48.0 / 255.0, alpha: 0.9), for: .normal)
        nativeCommentsCancelReplyButton.isHidden = true
        nativeCommentsCancelReplyButton.addTarget(self, action: #selector(cancelNativeCommentReply), for: .touchUpInside)
        content.addSubview(nativeCommentsCancelReplyButton)

        nativeCommentsTableView.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsTableView.backgroundColor = .clear
        nativeCommentsTableView.separatorStyle = .none
        nativeCommentsTableView.rowHeight = UITableView.automaticDimension
        nativeCommentsTableView.estimatedRowHeight = 76
        nativeCommentsTableView.keyboardDismissMode = .interactive
        nativeCommentsTableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        nativeCommentsTableView.dataSource = self
        nativeCommentsTableView.delegate = self
        nativeCommentsTableView.register(NativeCommentCell.self, forCellReuseIdentifier: NativeCommentCell.reuseIdentifier)
        content.addSubview(nativeCommentsTableView)

        nativeCommentsComposerBar.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsComposerBar.backgroundColor = .white
        nativeCommentsComposerBar.layer.borderWidth = 1
        nativeCommentsComposerBar.layer.borderColor = UIColor(red: 218.0 / 255.0, green: 226.0 / 255.0, blue: 240.0 / 255.0, alpha: 0.9).cgColor
        nativeCommentsComposerBar.layer.cornerRadius = 24
        nativeCommentsComposerBar.layer.cornerCurve = .continuous
        content.addSubview(nativeCommentsComposerBar)

        nativeCommentsComposerAvatar.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsComposerBar.addSubview(nativeCommentsComposerAvatar)

        nativeCommentsTextView.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsTextView.backgroundColor = .clear
        nativeCommentsTextView.font = .systemFont(ofSize: 15)
        nativeCommentsTextView.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        nativeCommentsTextView.delegate = self
        nativeCommentsTextView.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        nativeCommentsTextView.textContainer.lineFragmentPadding = 0
        nativeCommentsTextView.inputAccessoryView = makeNativeCommentsKeyboardAccessory()
        nativeCommentsComposerBar.addSubview(nativeCommentsTextView)

        nativeCommentsPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsPlaceholder.text = "Add a comment for everyone to see..."
        nativeCommentsPlaceholder.font = .systemFont(ofSize: 15)
        nativeCommentsPlaceholder.textColor = UIColor(red: 91.0 / 255.0, green: 107.0 / 255.0, blue: 138.0 / 255.0, alpha: 0.66)
        nativeCommentsComposerBar.addSubview(nativeCommentsPlaceholder)

        nativeCommentsSendButton.translatesAutoresizingMaskIntoConstraints = false
        nativeCommentsSendButton.setTitle("Send", for: .normal)
        nativeCommentsSendButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        nativeCommentsSendButton.layer.cornerRadius = 17
        nativeCommentsSendButton.layer.cornerCurve = .continuous
        nativeCommentsSendButton.addTarget(self, action: #selector(sendNativeComment), for: .touchUpInside)
        nativeCommentsComposerBar.addSubview(nativeCommentsSendButton)

        nativeCommentsSheetBottomConstraint = nativeCommentsSheet.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 520)
        nativeCommentsTextViewHeightConstraint = nativeCommentsTextView.heightAnchor.constraint(equalToConstant: 44)

        NSLayoutConstraint.activate([
            nativeCommentsDimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeCommentsDimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeCommentsDimView.topAnchor.constraint(equalTo: view.topAnchor),
            nativeCommentsDimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            nativeCommentsSheet.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            nativeCommentsSheet.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            nativeCommentsSheet.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.62),
            nativeCommentsSheetBottomConstraint!,

            nativeCommentsHandle.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            nativeCommentsHandle.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            nativeCommentsHandle.widthAnchor.constraint(equalToConstant: 44),
            nativeCommentsHandle.heightAnchor.constraint(equalToConstant: 5),

            nativeCommentsTitleLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            nativeCommentsTitleLabel.topAnchor.constraint(equalTo: nativeCommentsHandle.bottomAnchor, constant: 12),
            nativeCommentsFullPostButton.trailingAnchor.constraint(equalTo: nativeCommentsCloseButton.leadingAnchor, constant: -8),
            nativeCommentsFullPostButton.centerYAnchor.constraint(equalTo: nativeCommentsCloseButton.centerYAnchor),
            nativeCommentsCloseButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            nativeCommentsCloseButton.centerYAnchor.constraint(equalTo: nativeCommentsTitleLabel.centerYAnchor),
            nativeCommentsCloseButton.widthAnchor.constraint(equalToConstant: 30),
            nativeCommentsCloseButton.heightAnchor.constraint(equalToConstant: 30),

            nativeCommentsSubtitleLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            nativeCommentsSubtitleLabel.topAnchor.constraint(equalTo: nativeCommentsTitleLabel.bottomAnchor, constant: 2),
            nativeCommentsReplyingLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            nativeCommentsReplyingLabel.topAnchor.constraint(equalTo: nativeCommentsSubtitleLabel.bottomAnchor, constant: 8),
            nativeCommentsCancelReplyButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            nativeCommentsCancelReplyButton.centerYAnchor.constraint(equalTo: nativeCommentsReplyingLabel.centerYAnchor),

            nativeCommentsTableView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            nativeCommentsTableView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            nativeCommentsTableView.topAnchor.constraint(equalTo: nativeCommentsReplyingLabel.bottomAnchor, constant: 8),
            nativeCommentsTableView.bottomAnchor.constraint(equalTo: nativeCommentsComposerBar.topAnchor, constant: -10),

            nativeCommentsComposerBar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            nativeCommentsComposerBar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            nativeCommentsComposerBar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),

            nativeCommentsComposerAvatar.leadingAnchor.constraint(equalTo: nativeCommentsComposerBar.leadingAnchor, constant: 8),
            nativeCommentsComposerAvatar.centerYAnchor.constraint(equalTo: nativeCommentsComposerBar.centerYAnchor),
            nativeCommentsComposerAvatar.widthAnchor.constraint(equalToConstant: 34),
            nativeCommentsComposerAvatar.heightAnchor.constraint(equalToConstant: 34),

            nativeCommentsTextView.leadingAnchor.constraint(equalTo: nativeCommentsComposerAvatar.trailingAnchor, constant: 10),
            nativeCommentsTextView.topAnchor.constraint(equalTo: nativeCommentsComposerBar.topAnchor, constant: 6),
            nativeCommentsTextView.bottomAnchor.constraint(equalTo: nativeCommentsComposerBar.bottomAnchor, constant: -6),
            nativeCommentsTextViewHeightConstraint!,

            nativeCommentsPlaceholder.leadingAnchor.constraint(equalTo: nativeCommentsTextView.leadingAnchor),
            nativeCommentsPlaceholder.centerYAnchor.constraint(equalTo: nativeCommentsTextView.centerYAnchor),

            nativeCommentsSendButton.leadingAnchor.constraint(equalTo: nativeCommentsTextView.trailingAnchor, constant: 10),
            nativeCommentsSendButton.trailingAnchor.constraint(equalTo: nativeCommentsComposerBar.trailingAnchor, constant: -8),
            nativeCommentsSendButton.centerYAnchor.constraint(equalTo: nativeCommentsComposerBar.centerYAnchor),
            nativeCommentsSendButton.widthAnchor.constraint(equalToConstant: 64),
            nativeCommentsSendButton.heightAnchor.constraint(equalToConstant: 34)
        ])
        updateNativeCommentsComposeState()
    }

    private func makeNativeCommentsKeyboardAccessory() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let done = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismissNativeCommentsKeyboard))
        let close = UIBarButtonItem(title: "Close Comments", style: .done, target: self, action: #selector(dismissNativeComments))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.items = [done, spacer, close]
        return toolbar
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
                    (section == .profile)
                        ? .clear
                        : (isActive
                        ? UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
                        : UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 1)),
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
        let shouldShowFeed = isLoggedIntoWebApp && currentPrimarySection == .feed
        if shouldShowFeed {
            showNativeFeedIfNeeded()
        } else {
            hideNativeFeedIfNeeded()
        }

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

        if currentPrimarySection == .profile {
            let username = nativeProfileUsername(from: currentRoute) ?? currentUsername
            showNativeProfileIfNeeded(username: username)
        } else {
            hideNativeProfileIfNeeded()
        }

        if currentPrimarySection == .search {
            showNativeSearchIfNeeded()
        } else {
            hideNativeSearchIfNeeded()
        }
        setNativeAccountButtonVisible(isLoggedIntoWebApp && currentPrimarySection != .messages, animated: true)
    }

    private func routeSupportsNativeFeed(_ route: String) -> Bool {
        if route == "/" { return true }
        guard route.starts(with: "/?") else { return false }
        guard let components = URLComponents(string: "https://local\(route)") else { return false }
        let tab = components.queryItems?.first(where: { $0.name == "tab" })?.value ?? "home"
        return ["home", "fyp", "breaking"].contains(tab)
    }

    private func showNativeFeedIfNeeded() {
        guard !isShowingNativeFeed else {
            syncNativeFeedSegment()
            return
        }
        isShowingNativeFeed = true
        syncNativeFeedSegment()
        nativeFeedContainer.isHidden = false
        nativeFeedContainer.alpha = 1
        view.bringSubviewToFront(nativeFeedContainer)
        view.bringSubviewToFront(composeButton)
        view.bringSubviewToFront(nativeAccountButton)
        view.bringSubviewToFront(nativeTabBarBackdrop)
        view.bringSubviewToFront(nativeTabBar)
        if nativeFeedPosts.isEmpty && nativeFeedPolls.isEmpty {
            loadNativeFeed(force: false)
        }
        if webView?.isHidden == true {
            webView?.isHidden = false
        }
    }

    private func hideNativeFeedIfNeeded() {
        guard isShowingNativeFeed else { return }
        isShowingNativeFeed = false
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseInOut]) {
            self.nativeFeedContainer.alpha = 0
        } completion: { _ in
            self.nativeFeedContainer.isHidden = true
        }
    }

    private func showNativePostDetail(for post: NativeFeedPost) {
        nativePostDetailPost = post
        nativePostDetailComments = []
        nativePostDetailEmptyLabel.text = "Loading replies..."
        nativePostDetailEmptyLabel.isHidden = false
        nativePostDetailTableView.reloadData()
        isShowingNativePostDetail = true
        nativePostDetailContainer.isHidden = false
        nativePostDetailContainer.alpha = 1
        view.bringSubviewToFront(nativePostDetailContainer)
        view.bringSubviewToFront(nativeTabBarBackdrop)
        view.bringSubviewToFront(nativeTabBar)
        loadNativePostDetail(postID: post.id)
    }

    @objc private func closeNativePostDetail() {
        hideNativePostDetailIfNeeded()
    }

    private func hideNativePostDetailIfNeeded() {
        guard isShowingNativePostDetail else { return }
        isShowingNativePostDetail = false
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseInOut]) {
            self.nativePostDetailContainer.alpha = 0
        } completion: { _ in
            self.nativePostDetailContainer.isHidden = true
            self.nativePostDetailPost = nil
            self.nativePostDetailComments = []
            self.nativePostDetailTableView.reloadData()
        }
    }

    private func showNativeProfileIfNeeded(username: String) {
        guard !username.isEmpty else { return }
        isShowingNativeProfile = true
        nativeProfileContainer.isHidden = false
        nativeProfileContainer.alpha = 1
        view.bringSubviewToFront(nativeProfileContainer)
        view.bringSubviewToFront(nativeAccountButton)
        view.bringSubviewToFront(nativeTabBarBackdrop)
        view.bringSubviewToFront(nativeTabBar)
        loadNativeProfile(username: username, force: nativeProfileUser?.username != username)
    }

    private func hideNativeProfileIfNeeded() {
        guard isShowingNativeProfile else { return }
        isShowingNativeProfile = false
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseInOut]) {
            self.nativeProfileContainer.alpha = 0
        } completion: { _ in
            self.nativeProfileContainer.isHidden = true
        }
    }

    private func showNativeSearchIfNeeded() {
        guard !isShowingNativeSearch else { return }
        isShowingNativeSearch = true
        nativeSearchContainer.isHidden = false
        nativeSearchContainer.alpha = 1
        view.bringSubviewToFront(nativeSearchContainer)
        view.bringSubviewToFront(nativeAccountButton)
        view.bringSubviewToFront(nativeTabBarBackdrop)
        view.bringSubviewToFront(nativeTabBar)
        if nativeSearchUsers.isEmpty && nativeSearchPosts.isEmpty {
            loadNativeSearch(query: nativeSearchField.text ?? "")
        }
    }

    private func hideNativeSearchIfNeeded() {
        guard isShowingNativeSearch else { return }
        isShowingNativeSearch = false
        nativeSearchField.resignFirstResponder()
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseInOut]) {
            self.nativeSearchContainer.alpha = 0
        } completion: { _ in
            self.nativeSearchContainer.isHidden = true
        }
    }

    private func syncNativeFeedSegment() {
        let targetIndex: Int
        switch currentFeedTab {
        case "fyp": targetIndex = 1
        case "breaking": targetIndex = 2
        default: targetIndex = 0
        }
        if nativeFeedSegment.selectedSegmentIndex != targetIndex {
            nativeFeedSegment.selectedSegmentIndex = targetIndex
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
        stopNativeThreadRefresh()
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

    private func nativeProfileUsername(from route: String) -> String? {
        guard route.starts(with: "/users/") else { return nil }
        let raw = String(route.dropFirst("/users/".count))
        let username = raw.split(separator: "?").first.map(String.init) ?? raw
        return username.removingPercentEncoding?.isEmpty == false ? username.removingPercentEncoding : username
    }

    private func updateNativeThreadComposeState() {
        let trimmed = nativeThreadTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSend = !trimmed.isEmpty && !isSendingNativeMessage && nativeMessageTarget != nil
        nativeThreadPlaceholder.isHidden = !trimmed.isEmpty
        nativeThreadSendButton.isEnabled = canSend
        nativeThreadSendButton.setTitle(isSendingNativeMessage ? "..." : "Send", for: .normal)
        nativeThreadSendButton.alpha = (canSend || isSendingNativeMessage) ? 1 : 0.55
        nativeThreadSendButton.backgroundColor = canSend
            ? UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
            : UIColor(red: 123.0 / 255.0, green: 145.0 / 255.0, blue: 189.0 / 255.0, alpha: 0.88)
    }

    private func activeMentionInfo(in textView: UITextView) -> (query: String, range: NSRange)? {
        let cursor = textView.selectedRange.location
        let text = textView.text as NSString
        guard cursor <= text.length else { return nil }
        var index = cursor
        while index > 0 {
            let character = text.substring(with: NSRange(location: index - 1, length: 1))
            if character == "@" {
                let range = NSRange(location: index - 1, length: cursor - index + 1)
                let query = text.substring(with: NSRange(location: index, length: cursor - index))
                guard !query.contains(" "), !query.contains("\n") else { return nil }
                return (query, range)
            }
            if character == " " || character == "\n" {
                return nil
            }
            index -= 1
        }
        return nil
    }

    private func updateComposerMentionSuggestions() {
        guard let mention = activeMentionInfo(in: composerTextView) else {
            activeMentionQuery = ""
            renderComposerMentionSuggestions([])
            return
        }
        guard mention.query != activeMentionQuery else { return }
        activeMentionQuery = mention.query
        fetchComposerMentionSuggestions(query: mention.query)
    }

    private func fetchComposerMentionSuggestions(query: String) {
        guard !isLoadingMentionSuggestions else { return }
        isLoadingMentionSuggestions = true
        performNativeJSONRequest(path: "/api/users/mentions?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)") { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingMentionSuggestions = false
                guard case .success(let data) = result,
                      let payload = try? JSONDecoder().decode(NativeMentionResponse.self, from: data),
                      self.activeMentionQuery == query else { return }
                self.currentMentionSuggestions = Array(payload.users.prefix(5))
                self.renderComposerMentionSuggestions(self.currentMentionSuggestions)
            }
        }
    }

    private func renderComposerMentionSuggestions(_ users: [NativeMentionUser]) {
        composerMentionsStack.arrangedSubviews.forEach { view in
            composerMentionsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        composerMentionsContainer.isHidden = users.isEmpty
        users.forEach { user in
            let button = NativeMentionSuggestionButton(user: user, imageCache: nativeAvatarImageCache)
            button.addTarget(self, action: #selector(handleMentionSuggestionTap(_:)), for: .touchUpInside)
            composerMentionsStack.addArrangedSubview(button)
        }
    }

    @objc private func handleMentionSuggestionTap(_ sender: NativeMentionSuggestionButton) {
        guard let mention = activeMentionInfo(in: composerTextView) else { return }
        let text = composerTextView.text as NSString
        let replacement = "@\(sender.user.username) "
        composerTextView.text = text.replacingCharacters(in: mention.range, with: replacement)
        composerTextView.selectedRange = NSRange(location: mention.range.location + replacement.count, length: 0)
        activeMentionQuery = ""
        renderComposerMentionSuggestions([])
        updateComposerTextStyling()
        textViewDidChange(composerTextView)
    }

    private func updateComposerTextStyling() {
        guard !isApplyingComposerTextAttributes else { return }
        isApplyingComposerTextAttributes = true
        let selectedRange = composerTextView.selectedRange
        let text = composerTextView.text ?? ""
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: composerTextView.font ?? UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
            ]
        )
        let regex = try? NSRegularExpression(pattern: "@[A-Za-z0-9_.]+")
        regex?.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).forEach { match in
            attributed.addAttributes([
                .foregroundColor: UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1),
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
            ], range: match.range)
        }
        composerTextView.attributedText = attributed
        composerTextView.selectedRange = selectedRange
        composerTextView.typingAttributes = [
            .font: composerTextView.font ?? UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        ]
        isApplyingComposerTextAttributes = false
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
        webView.configuration.userContentController.removeScriptMessageHandler(forName: nativeJSONScriptMessageName)
        webView.configuration.userContentController.add(self, name: nativeJSONScriptMessageName)
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
                let shouldPreserveNativeRoute = self.nativeRouteOverrideUntil.map { Date() < $0 } ?? false
                if !shouldPreserveNativeMessages && !shouldPreserveNativeRoute {
                    self.currentPrimarySection = payloadSection
                }
                self.currentUsername = username
                if !shouldPreserveNativeMessages, !shouldPreserveNativeRoute, !payloadRoute.isEmpty {
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
            nativeFeedPosts = []
            nativeFeedStories = []
            nativeFeedPolls = []
            nativeFeedLatestPostID = 0
            nativeCurrentUser = nil
            nativeFeedStoriesHeader.configure(stories: [], currentUser: nil, hasCurrentUserStory: false, imageCache: nativeAvatarImageCache)
            lastRouteBySection = [
                .messages: "/messages",
                .feed: "/",
                .search: "/search"
            ]
            nativeFeedTableView.reloadData()
            nativeMessagesListTableView.reloadData()
            renderNativeThreadMessages()
            hideNativeFeedIfNeeded()
            hideNativeMessagesIfNeeded()
            hideNativeProfileIfNeeded()
            hideNativeSearchIfNeeded()
            setNativeAccountButtonVisible(false, animated: true)
            return
        }
        if !wasLoggedIn {
            maybeRequestNotificationPermission(for: username)
        }
        if !username.isEmpty {
            lastRouteBySection[.profile] = "/users/\(username)"
        }
        updateNativeAccountAvatar()
        setNativeAccountButtonVisible(currentPrimarySection != .messages, animated: true)
        openPendingPushRouteIfPossible()
    }

    private func observePushToken() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePushTokenNotification(_:)),
            name: .piaDidRegisterPushToken,
            object: nil
        )
    }

    private func observePushNotificationTaps() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePushNotificationTap(_:)),
            name: .piaDidTapPushNotification,
            object: nil
        )
    }

    private func consumeStoredPushRoute() {
        guard let link = UserDefaults.standard.string(forKey: "pia.pendingPushLink"), !link.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: "pia.pendingPushLink")
        handlePushRoute(link)
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
        print("APNs device token received: \(token.prefix(12))...")
        lastRegisteredPushToken = token
        registerPushToken(token)
    }

    private func registerPushToken(_ token: String) {
        guard let targetURL = URL(string: "/push/register", relativeTo: webView?.url)?.absoluteURL else { return }
        fetchCookieHeader(for: targetURL) { [weak self] cookieHeader in
            var request = URLRequest(url: targetURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("fetch", forHTTPHeaderField: "X-Requested-With")
            if let cookieHeader, !cookieHeader.isEmpty {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["endpoint": "apns:\(token)"], options: [])
            URLSession.shared.dataTask(with: request) { data, response, error in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let preview = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                if let error {
                    print("Push token registration failed: \(error.localizedDescription)")
                    return
                }
                print("Push token registration response: status=\(status) body=\(preview.prefix(160))")
                if status < 200 || status >= 300 {
                    DispatchQueue.main.async {
                        self?.showNativeFlash(message: "Push registration failed: \(status)", category: "error")
                    }
                }
            }.resume()
        }
    }

    @objc private func handlePushNotificationTap(_ note: Notification) {
        guard let link = note.userInfo?["link"] as? String else { return }
        UserDefaults.standard.removeObject(forKey: "pia.pendingPushLink")
        handlePushRoute(link)
    }

    private func handlePushRoute(_ rawRoute: String) {
        guard let route = normalizedPushRoute(rawRoute) else { return }
        if !isLoggedIntoWebApp {
            pendingPushRoute = route
            return
        }
        openPushRoute(route)
    }

    private func openPendingPushRouteIfPossible() {
        guard isLoggedIntoWebApp, let route = pendingPushRoute else { return }
        pendingPushRoute = nil
        openPushRoute(route)
    }

    private func normalizedPushRoute(_ rawRoute: String) -> String? {
        let trimmed = rawRoute.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("/") {
            return trimmed
        }
        guard let components = URLComponents(string: trimmed) else { return nil }
        let path = components.path.isEmpty ? "/" : components.path
        return "\(path)\(components.query.map { "?\($0)" } ?? "")"
    }

    private func primarySection(for route: String) -> PrimarySection {
        if route.starts(with: "/messages") { return .messages }
        if route.starts(with: "/search") { return .search }
        if route.starts(with: "/users/") { return .profile }
        return .feed
    }

    private func openPushRoute(_ route: String) {
        let section = primarySection(for: route)
        currentPrimarySection = section
        currentRoute = route
        lastRouteBySection[section] = route
        updateNativeTabSelection(animated: true)

        if section == .messages {
            hideNativeFeedIfNeeded()
            showNativeMessagesIfNeeded()
            if let username = nativeMessageUsername(from: route) {
                lastRouteBySection[.messages] = route
                loadNativeThread(username: username, animate: nativeMessageTarget != nil)
            } else {
                nativeMessagesSubtitle.isHidden = false
                nativeMessagesListTableView.isHidden = false
                nativeThreadContainer.isHidden = true
                nativeMessageTarget = nil
                nativeThreadMessages = []
                renderNativeThreadMessages()
                loadNativeInbox()
            }
            return
        }

        hideNativeMessagesIfNeeded()
        if section == .feed || section == .search || section == .profile {
            updateNativeSectionPresentation()
            if section == .feed {
                loadNativeFeed(force: false)
            }
        } else {
            hideNativeFeedIfNeeded()
        }
        navigateWebView(to: route, replace: false)
    }

    private func navigateWebView(to route: String, replace: Bool) {
        guard let payloadData = try? JSONSerialization.data(withJSONObject: ["route": route, "replace": replace], options: []),
              let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            return
        }
        let script = """
        (function(payload) {
          if (window.navigateInApp) {
            window.navigateInApp(payload.route, {replace: !!payload.replace, restoreScroll: false});
          } else {
            window.location.assign(payload.route);
          }
        })(\(payloadJSON));
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func setComposeButtonVisible(_ visible: Bool, animated: Bool) {
        nativeComposerAvailable = visible
        let shouldShowCompose = visible && !isShowingNativeMessages && currentPrimarySection != .messages
        if shouldShowCompose {
            composeButton.isHidden = false
        }
        let changes = {
            self.composeButton.alpha = shouldShowCompose ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.22, animations: changes) { _ in
                if !shouldShowCompose {
                    self.composeButton.isHidden = true
                }
            }
        } else {
            changes()
            if !shouldShowCompose {
                composeButton.isHidden = true
            }
        }
        if !shouldShowCompose {
            dismissComposerSheet(animated: false)
        }
    }

    @objc private func showComposer() {
        composerDimView.isHidden = false
        composerSheet.isHidden = false
        composerPlaceholder.isHidden = !composerTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        view.bringSubviewToFront(composerDimView)
        view.bringSubviewToFront(composerSheet)
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
        renderComposerMentionSuggestions([])
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
            currentKeyboardFrameInView = keyboardFrame
            updateNativeThreadKeyboardPosition()
            updateNativeThreadTableInsets()
            shouldAnimate = true
        }
        if !composerSheet.isHidden,
           let frameValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardFrame = view.convert(frameValue.cgRectValue, from: nil)
            let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
            composerSheetBottomConstraint?.constant = max(0, -view.safeAreaInsets.bottom) - overlap + view.safeAreaInsets.bottom
            shouldAnimate = true
        }
        if !nativeCommentsSheet.isHidden,
           let frameValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardFrame = view.convert(frameValue.cgRectValue, from: nil)
            let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
            nativeCommentsSheetBottomConstraint?.constant = max(0, -view.safeAreaInsets.bottom) - overlap + view.safeAreaInsets.bottom
            shouldAnimate = true
        }
        if shouldAnimate {
            animateWithKeyboard(note)
        }
    }

    @objc private func handleKeyboardWillHide(_ note: Notification) {
        var shouldAnimate = false
        currentKeyboardFrameInView = nil
        if isShowingNativeMessages, !nativeThreadContainer.isHidden {
            nativeThreadComposerBottomConstraint?.constant = -14
            updateNativeThreadTableInsets()
            shouldAnimate = true
        }
        if !composerSheet.isHidden {
            composerSheetBottomConstraint?.constant = 0
            shouldAnimate = true
        }
        if !nativeCommentsSheet.isHidden {
            nativeCommentsSheetBottomConstraint?.constant = 0
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
            self.scrollNativeThreadToBottomWhenReady(animated: false)
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

        fetchCookieHeader(for: targetURL) { [weak self] cookieHeader in
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
                    if self.isShowingNativeFeed {
                        self.loadNativeFeed(force: true)
                    }
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

    private func cookie(_ cookie: HTTPCookie, matches targetURL: URL) -> Bool {
        guard let host = targetURL.host?.lowercased(), !host.isEmpty else { return false }
        let cookieDomain = cookie.domain.lowercased()
        if cookieDomain.isEmpty { return true }
        let normalizedDomain = cookieDomain.hasPrefix(".") ? String(cookieDomain.dropFirst()) : cookieDomain
        return host == normalizedDomain || host.hasSuffix(".\(normalizedDomain)")
    }

    private func fetchCookieHeader(for targetURL: URL, completion: @escaping (String?) -> Void) {
        guard let cookieStore = webView?.configuration.websiteDataStore.httpCookieStore else {
            completion(nil)
            return
        }
        cookieStore.getAllCookies { cookies in
            let header = cookies
                .filter { self.cookie($0, matches: targetURL) }
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
        let bodyJSON: String?
        if let bodyObject,
           let bodyData = try? JSONSerialization.data(withJSONObject: bodyObject),
           let bodyString = String(data: bodyData, encoding: .utf8) {
            bodyJSON = bodyString
        } else {
            bodyJSON = nil
        }
        let requestID = UUID().uuidString
        let payload: [String: Any] = [
            "id": requestID,
            "url": path,
            "method": method,
            "body": bodyJSON ?? NSNull()
        ]
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let payloadJSON = String(data: payloadData, encoding: .utf8) else {
            completion(.failure(NSError(domain: "NativeMessages", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid request payload."])))
            return
        }
        let script = """
        (function() {
          const request = \(payloadJSON);
          const complete = function(payload) {
            try {
              window.webkit.messageHandlers.\(nativeJSONScriptMessageName).postMessage(payload);
            } catch (e) {}
          };
          const headers = {
            "Accept": "application/json",
            "X-Requested-With": "fetch"
          };
          const options = {
            method: request.method || "GET",
            credentials: "include",
            headers
          };
          if (request.body !== null && request.body !== undefined) {
            headers["Content-Type"] = "application/json";
            options.body = request.body;
          }
          fetch(request.url, options)
            .then(async function(response) {
              const text = await response.text();
              complete({ id: request.id, status: response.status, text: text });
            })
            .catch(function(error) {
              const message = error && error.message ? error.message : String(error);
              complete({
                id: request.id,
                status: 0,
                text: JSON.stringify({ ok: false, error: message || "Network request failed." })
              });
            });
          return true;
        })();
        """
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingNativeJSONRequests[requestID] = completion
            print("Native DM request \(method) \(targetURL.absoluteString)")
            self.webView?.evaluateJavaScript(script) { _, error in
                if let error {
                    let pending = self.pendingNativeJSONRequests.removeValue(forKey: requestID)
                    pending?(.failure(error))
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self,
                      let pending = self.pendingNativeJSONRequests.removeValue(forKey: requestID) else { return }
                pending(.failure(NSError(domain: "NativeMessages", code: 4, userInfo: [NSLocalizedDescriptionKey: "Native DM request timed out."])))
            }
        }
    }

    private func parseNativeUserSummary(from raw: [String: Any]) -> NativeUserSummary? {
        let id = nativeInt(from: raw["id"]) ?? 0
        guard id >= 0,
              let username = raw["username"] as? String else { return nil }
        return NativeUserSummary(
            id: id,
            username: username,
            display_name: raw["display_name"] as? String ?? username,
            avatar_url: raw["avatar_url"] as? String ?? "",
            avatar_emoji: raw["avatar_emoji"] as? String ?? "🦅",
            use_emoji: nativeBool(from: raw["use_emoji"]) ?? true,
            is_verified: nativeBool(from: raw["is_verified"]) ?? false,
            is_creator: nativeBool(from: raw["is_creator"]) ?? false
        )
    }

    private func parseNativeThreadMessage(from raw: [String: Any]) -> NativeThreadMessage? {
        let id = nativeInt(from: raw["id"]) ?? 0
        guard id >= 0,
              let bodyValue = raw["body"],
              let sender = nativeDictionary(from: raw["sender"]).flatMap(parseNativeUserSummary(from:)),
              let receiver = nativeDictionary(from: raw["receiver"]).flatMap(parseNativeUserSummary(from:)) else { return nil }
        let body = (bodyValue as? String) ?? String(describing: bodyValue)
        return NativeThreadMessage(
            id: id,
            body: body,
            is_mine: nativeBool(from: raw["is_mine"]) ?? false,
            is_read: nativeBool(from: raw["is_read"]) ?? false,
            created_at: raw["created_at"] as? String ?? "",
            created_at_relative: raw["created_at_relative"] as? String ?? "",
            sender: sender,
            receiver: receiver
        )
    }

    private func parseNativeThreadPayload(from data: Data) -> (ok: Bool, target: NativeUserSummary?, messages: [NativeThreadMessage], error: String?)? {
        if let decoded = try? JSONDecoder().decode(NativeThreadResponse.self, from: data) {
            return (decoded.ok, decoded.target, decoded.messages, nil)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let ok = nativeBool(from: object["ok"]) ?? false
        let target = nativeDictionary(from: object["target"]).flatMap(parseNativeUserSummary(from:))
        let messages = nativeArrayOfDictionaries(from: object["messages"]).compactMap(parseNativeThreadMessage(from:))
        let error = object["error"] as? String
        return (ok, target, messages, error)
    }

    private func parseNativeSendMessagePayload(from data: Data) -> (ok: Bool, message: NativeThreadMessage?, error: String?)? {
        if let decoded = try? JSONDecoder().decode(NativeSendMessageResponse.self, from: data) {
            return (decoded.ok, decoded.message, nil)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let ok = nativeBool(from: object["ok"]) ?? false
        let message = nativeDictionary(from: object["message"]).flatMap(parseNativeThreadMessage(from:))
        let error = object["error"] as? String
        return (ok, message, error)
    }

    private func nativeResponsePreview(from data: Data) -> String {
        let raw = String(data: data, encoding: .utf8) ?? ""
        let compact = raw.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.isEmpty {
            return "empty response"
        }
        return String(compact.prefix(140))
    }

    private func nativeInt(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let numberValue = value as? NSNumber { return numberValue.intValue }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }

    private func nativeBool(from value: Any?) -> Bool? {
        if let boolValue = value as? Bool { return boolValue }
        if let numberValue = value as? NSNumber { return numberValue.boolValue }
        if let stringValue = value as? String {
            switch stringValue.lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private func nativeDictionary(from value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let dictionary = value as? NSDictionary {
            var bridged: [String: Any] = [:]
            for (key, value) in dictionary {
                if let key = key as? String {
                    bridged[key] = value
                }
            }
            return bridged.isEmpty ? nil : bridged
        }
        return nil
    }

    private func nativeArrayOfDictionaries(from value: Any?) -> [[String: Any]] {
        if let dictionaries = value as? [[String: Any]] {
            return dictionaries
        }
        if let array = value as? [NSDictionary] {
            return array.compactMap(nativeDictionary(from:))
        }
        if let array = value as? [Any] {
            return array.compactMap(nativeDictionary(from:))
        }
        return []
    }

    private func loadNativeFeed(force: Bool) {
        guard isLoggedIntoWebApp, !isLoadingNativeFeed else { return }
        isLoadingNativeFeed = true
        if !force && nativeFeedPosts.isEmpty {
            nativeFeedEmptyLabel.text = "Loading posts..."
            nativeFeedEmptyLabel.isHidden = false
        }
        let tab = currentFeedTab.isEmpty ? "home" : currentFeedTab
        performNativeJSONRequest(path: "/api/feed?tab=\(tab.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tab)") { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingNativeFeed = false
                self.nativeFeedRefreshControl.endRefreshing()
                switch result {
                case .success(let data):
                    guard let payload = try? JSONDecoder().decode(NativeFeedResponse.self, from: data), payload.ok else {
                        let apiError = (try? JSONDecoder().decode(NativeAPIErrorResponse.self, from: data))?.error
                        self.handleNativeFeedLoadError(apiError ?? "Feed error: \(self.nativeResponsePreview(from: data))")
                        return
                    }
                    self.currentFeedTab = payload.feed_mode
                    self.nativeFeedLatestPostID = payload.latest_post_id
                    self.nativeFeedPosts = payload.posts
                    self.nativeFeedStories = payload.stories
                    self.nativeFeedPolls = payload.polls
                    self.nativeCurrentUser = payload.current_user
                    self.nativeFeedStoriesHeader.configure(
                        stories: payload.stories,
                        currentUser: payload.current_user,
                        hasCurrentUserStory: payload.current_user_story,
                        imageCache: self.nativeAvatarImageCache
                    )
                    self.resizeNativeFeedHeader()
                    if let currentUser = payload.current_user {
                        self.nativeProfileAvatarView.configure(with: currentUser, imageCache: self.nativeAvatarImageCache)
                        self.updateNativeAccountAvatar()
                    }
                    self.syncNativeFeedSegment()
                    self.nativeFeedTableView.reloadData()
                    self.prefetchNativeFeedImages(for: Array(payload.posts.prefix(8)))
                    self.prefetchNativeStoryImages(for: payload.stories)
                    self.nativeFeedEmptyLabel.text = "No posts yet."
                    self.nativeFeedEmptyLabel.isHidden = !(payload.posts.isEmpty && payload.polls.isEmpty)
                case .failure(let error):
                    self.nativeFeedEmptyLabel.text = "Feed couldn't load."
                    self.nativeFeedEmptyLabel.isHidden = !(self.nativeFeedPosts.isEmpty && self.nativeFeedPolls.isEmpty)
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func handleNativeFeedLoadError(_ message: String) {
        nativeFeedRefreshControl.endRefreshing()
        nativeFeedEmptyLabel.text = message.isEmpty ? "Feed couldn't load." : message
        nativeFeedEmptyLabel.isHidden = false
        showNativeFlash(message: nativeFeedEmptyLabel.text ?? "Feed couldn't load.", category: "error")
        if message.localizedCaseInsensitiveContains("terms") {
            currentRoute = "/terms-agreement"
            hideNativeFeedIfNeeded()
            navigateWebView(to: "/terms-agreement", replace: false)
        }
    }

    private func prefetchNativeFeedImages(for posts: [NativeFeedPost]) {
        posts.forEach { post in
            preloadNativeImage(urlString: post.author.avatar_url, cache: nativeAvatarImageCache)
            preloadNativeImage(urlString: post.media_url, cache: nativeFeedImageCache)
            if let quote = post.quote {
                preloadNativeImage(urlString: quote.media_url, cache: nativeFeedImageCache)
                if let author = quote.author {
                    preloadNativeImage(urlString: author.avatar_url, cache: nativeAvatarImageCache)
                }
            }
        }
    }

    private func prefetchNativeStoryImages(for stories: [NativeFeedStory]) {
        stories.forEach { story in
            preloadNativeImage(urlString: story.author.avatar_url, cache: nativeAvatarImageCache)
            preloadNativeImage(urlString: story.media_url, cache: nativeFeedImageCache)
        }
    }

    private func resizeNativeFeedHeader() {
        guard nativeFeedTableView.tableHeaderView === nativeFeedStoriesHeader else { return }
        let height = nativeFeedStoriesHeader.preferredHeight
        nativeFeedStoriesHeader.frame = CGRect(x: 0, y: 0, width: nativeFeedTableView.bounds.width, height: height)
        nativeFeedTableView.tableHeaderView = nativeFeedStoriesHeader
    }

    private func openNativeStory(_ story: NativeFeedStory) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        nativeStoryViewer.configure(story: story, avatarCache: nativeAvatarImageCache, mediaCache: nativeFeedImageCache)
        nativeStoryViewer.isHidden = false
        view.bringSubviewToFront(nativeStoryViewer)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.nativeStoryViewer.alpha = 1
        }
    }

    private func dismissNativeStoryViewer() {
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseInOut]) {
            self.nativeStoryViewer.alpha = 0
        } completion: { _ in
            self.nativeStoryViewer.isHidden = true
            self.nativeStoryViewer.prepareForReuse()
        }
    }

    private func presentNativeVideo(url: URL) {
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        present(controller, animated: true) {
            player.play()
        }
    }

    private func openNativeStoryComposer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismissComposerSheet(animated: false)
        if !nativeCommentsSheet.isHidden {
            dismissNativeComments()
        }
        presentNativeStorySourceOptions()
    }

    private func presentNativeStorySourceOptions() {
        let alert = UIAlertController(title: "Add to Story", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
            self?.presentCameraForStory()
        })
        alert.addAction(UIAlertAction(title: "Upload a Photo", style: .default) { [weak self] _ in
            self?.presentPhotoPicker(purpose: .story, mediaFilter: .images)
        })
        alert.addAction(UIAlertAction(title: "Upload a Video", style: .default) { [weak self] _ in
            self?.presentPhotoPicker(purpose: .story, mediaFilter: .videos)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        topPresentationController().present(alert, animated: true)
    }

    private func presentCameraForStory() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker(purpose: .story, mediaFilter: .images)
            return
        }
        photoPickerPurpose = .story
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = true
        picker.delegate = self
        topPresentationController().present(picker, animated: true)
    }

    private func preloadNativeImage(urlString: String, cache: NSCache<NSString, UIImage>) {
        guard !urlString.isEmpty else { return }
        let key = NSString(string: urlString)
        guard cache.object(forKey: key) == nil, let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            cache.setObject(image, forKey: key)
        }.resume()
    }

    private func loadNativePostDetail(postID: Int) {
        guard !isLoadingNativePostDetail else { return }
        isLoadingNativePostDetail = true
        performNativeJSONRequest(path: "/api/post/\(postID)") { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingNativePostDetail = false
                switch result {
                case .success(let data):
                    guard let payload = try? JSONDecoder().decode(NativePostDetailResponse.self, from: data), payload.ok else {
                        self.nativePostDetailEmptyLabel.text = "Post couldn't load."
                        self.nativePostDetailEmptyLabel.isHidden = false
                        return
                    }
                    self.nativePostDetailPost = payload.post
                    self.nativePostDetailComments = payload.flatComments
                    self.nativePostDetailEmptyLabel.isHidden = true
                    self.nativePostDetailTableView.reloadData()
                    self.prefetchNativeFeedImages(for: [payload.post])
                case .failure(let error):
                    self.nativePostDetailEmptyLabel.text = "Post couldn't load."
                    self.nativePostDetailEmptyLabel.isHidden = false
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func loadNativeProfile(username: String, force: Bool) {
        guard !isLoadingNativeProfile else { return }
        if !force, nativeProfileUser?.username == username { return }
        isLoadingNativeProfile = true
        nativeProfileEmptyLabel.text = "Loading profile..."
        nativeProfileEmptyLabel.isHidden = false
        performNativeJSONRequest(path: "/api/users/\(username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username)") { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingNativeProfile = false
                switch result {
                case .success(let data):
                    guard let payload = try? JSONDecoder().decode(NativeProfileResponse.self, from: data), payload.ok else {
                        self.nativeProfileEmptyLabel.text = "Profile couldn't load."
                        self.nativeProfileEmptyLabel.isHidden = false
                        return
                    }
                    self.nativeProfileUser = payload.user
                    self.nativeProfilePosts = payload.posts
                    self.nativeProfileHeaderView.configure(user: payload.user, imageCache: self.nativeAvatarImageCache)
                    self.resizeNativeProfileHeader()
                    self.nativeProfileTableView.reloadData()
                    self.prefetchNativeFeedImages(for: Array(payload.posts.prefix(8)))
                    self.nativeProfileEmptyLabel.text = "No posts yet."
                    self.nativeProfileEmptyLabel.isHidden = !payload.posts.isEmpty
                case .failure(let error):
                    self.nativeProfileEmptyLabel.text = "Profile couldn't load."
                    self.nativeProfileEmptyLabel.isHidden = false
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func resizeNativeProfileHeader() {
        guard nativeProfileTableView.tableHeaderView === nativeProfileHeaderView else { return }
        let height = nativeProfileHeaderView.preferredHeight
        nativeProfileHeaderView.frame = CGRect(x: 0, y: 0, width: nativeProfileTableView.bounds.width, height: height)
        nativeProfileTableView.tableHeaderView = nativeProfileHeaderView
    }

    @objc private func nativeSearchTextChanged() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runNativeSearchFromField), object: nil)
        perform(#selector(runNativeSearchFromField), with: nil, afterDelay: 0.22)
    }

    @objc private func nativeSearchReturnPressed() {
        nativeSearchField.resignFirstResponder()
        loadNativeSearch(query: nativeSearchField.text ?? "")
    }

    @objc private func runNativeSearchFromField() {
        loadNativeSearch(query: nativeSearchField.text ?? "")
    }

    private func loadNativeSearch(query: String) {
        guard isLoggedIntoWebApp, !isLoadingNativeSearch else { return }
        isLoadingNativeSearch = true
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        performNativeJSONRequest(path: "/api/search?q=\(encoded)") { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingNativeSearch = false
                switch result {
                case .success(let data):
                    guard let payload = try? JSONDecoder().decode(NativeSearchResponse.self, from: data), payload.ok else {
                        self.nativeSearchEmptyLabel.text = "Search couldn't load."
                        self.nativeSearchEmptyLabel.isHidden = false
                        return
                    }
                    self.nativeSearchUsers = payload.users
                    self.nativeSearchPosts = payload.posts
                    self.nativeSearchTableView.reloadData()
                    self.prefetchNativeFeedImages(for: Array(payload.posts.prefix(8)))
                    self.nativeSearchEmptyLabel.text = payload.query.isEmpty ? "Discover people and fresh posts." : "No results yet."
                    self.nativeSearchEmptyLabel.isHidden = !(payload.users.isEmpty && payload.posts.isEmpty)
                case .failure(let error):
                    self.nativeSearchEmptyLabel.text = "Search couldn't load."
                    self.nativeSearchEmptyLabel.isHidden = false
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func presentNativeConnections(tab: String) {
        guard let username = nativeProfileUser?.username, !isLoadingNativeConnections else { return }
        isLoadingNativeConnections = true
        nativeConnectionsUsers = []
        nativeConnectionsTitleLabel.text = tab == "following" ? "Following" : "Followers"
        nativeConnectionsEmptyLabel.text = "Loading..."
        nativeConnectionsEmptyLabel.isHidden = false
        nativeConnectionsTableView.reloadData()
        nativeConnectionsDimView.isHidden = false
        nativeConnectionsSheet.isHidden = false
        view.bringSubviewToFront(nativeConnectionsDimView)
        view.bringSubviewToFront(nativeConnectionsSheet)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.nativeConnectionsDimView.alpha = 1
            self.nativeConnectionsSheet.alpha = 1
        }

        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        performNativeJSONRequest(path: "/api/users/\(encodedUsername)/connections?tab=\(tab)") { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoadingNativeConnections = false
                switch result {
                case .success(let data):
                    guard let payload = try? JSONDecoder().decode(NativeConnectionsResponse.self, from: data), payload.ok else {
                        self.nativeConnectionsEmptyLabel.text = "Couldn't load."
                        self.nativeConnectionsEmptyLabel.isHidden = false
                        return
                    }
                    self.nativeConnectionsTitleLabel.text = payload.tab == "following" ? "Following" : "Followers"
                    self.nativeConnectionsUsers = payload.users
                    self.nativeConnectionsTableView.reloadData()
                    self.nativeConnectionsEmptyLabel.text = "No people here yet."
                    self.nativeConnectionsEmptyLabel.isHidden = !payload.users.isEmpty
                case .failure(let error):
                    self.nativeConnectionsEmptyLabel.text = "Couldn't load."
                    self.nativeConnectionsEmptyLabel.isHidden = false
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    @objc private func dismissNativeConnections() {
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseInOut]) {
            self.nativeConnectionsDimView.alpha = 0
            self.nativeConnectionsSheet.alpha = 0
        } completion: { _ in
            self.nativeConnectionsDimView.isHidden = true
            self.nativeConnectionsSheet.isHidden = true
        }
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
                    guard let payload = try? JSONDecoder().decode(NativeInboxResponse.self, from: data) else {
                        self.showNativeFlash(message: "Inbox error: \(self.nativeResponsePreview(from: data))", category: "error")
                        self.nativeMessagesEmptyLabel.isHidden = false
                        return
                    }
                    self.nativeMessageConversations = payload.conversations
                    if let openUsername = self.nativeMessageTarget?.username {
                        self.clearNativeUnread(for: openUsername)
                    }
                    self.nativeMessagesListTableView.reloadData()
                    self.nativeMessagesEmptyLabel.isHidden = !payload.conversations.isEmpty || !self.nativeThreadContainer.isHidden
                case .failure(let error):
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func presentNativeThreadShell(for target: NativeUserSummary) {
        nativeMessageTarget = target
        clearNativeUnread(for: target.username)
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
        updateNativeThreadTextViewHeight(animated: false)
        updateNativeThreadTableInsets()
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
        renderNativeThreadMessages()
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
                        let errorMessage = self.parseNativeThreadPayload(from: data)?.error ?? "Thread error: \(self.nativeResponsePreview(from: data))"
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
                    self.renderNativeThreadMessages()
                    self.nativeThreadEmptyLabel.isHidden = !payload.messages.isEmpty
                    self.updateNativeThreadKeyboardPosition()
                    self.updateNativeThreadTableInsets()
                    self.view.layoutIfNeeded()
                    self.scrollNativeThreadToBottomWhenReady(animated: animate)
                    self.focusNativeThreadComposer()
                    self.startNativeThreadRefresh(for: target.username)
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
        nativeThreadTableView.layoutIfNeeded()
        let rowCount = nativeThreadTableView.numberOfRows(inSection: 0)
        guard rowCount > 0 else { return }
        let lastRow = min(nativeThreadMessages.count, rowCount) - 1
        guard lastRow >= 0 else { return }
        nativeThreadTableView.scrollToRow(at: IndexPath(row: lastRow, section: 0), at: .bottom, animated: animated)
    }

    private func scrollNativeThreadToBottomWhenReady(animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.nativeThreadTableView.layoutIfNeeded()
            self.scrollNativeThreadToBottom(animated: animated)
        }
    }

    private func focusNativeThreadComposer() {
        guard isShowingNativeMessages,
              !nativeThreadContainer.isHidden,
              nativeMessageTarget != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self,
                  self.isShowingNativeMessages,
                  !self.nativeThreadContainer.isHidden,
                  self.nativeMessageTarget != nil else { return }
            self.nativeThreadTextView.becomeFirstResponder()
            self.updateNativeThreadKeyboardPosition()
            self.updateNativeThreadComposeState()
        }
    }

    private func startNativeThreadRefresh(for username: String) {
        nativeThreadRefreshTimer?.invalidate()
        let timer = Timer(timeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.refreshNativeThreadIfNeeded(username: username)
        }
        RunLoop.main.add(timer, forMode: .common)
        nativeThreadRefreshTimer = timer
        nativeThreadRefreshTimer?.tolerance = 0.5
    }

    private func stopNativeThreadRefresh() {
        nativeThreadRefreshTimer?.invalidate()
        nativeThreadRefreshTimer = nil
        isRefreshingNativeThread = false
    }

    private func refreshNativeThreadIfNeeded(username: String) {
        guard isLoggedIntoWebApp,
              isShowingNativeMessages,
              !nativeThreadContainer.isHidden,
              nativeMessageTarget?.username == username,
              !isLoadingNativeThread,
              !isRefreshingNativeThread,
              !isSendingNativeMessage else { return }

        isRefreshingNativeThread = true
        performNativeJSONRequest(path: "/api/messages/thread?user=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username)") { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshingNativeThread = false
                guard self.nativeMessageTarget?.username == username else { return }
                guard case .success(let data) = result,
                      let payload = self.parseNativeThreadPayload(from: data),
                      payload.ok else { return }

                let currentIDs = Set(self.nativeThreadMessages.map(\.id))
                let newMessages = payload.messages.filter { !currentIDs.contains($0.id) }
                if !newMessages.isEmpty {
                    newMessages.forEach { self.appendNativeThreadMessage($0, animated: true) }
                    if let latest = newMessages.last, let target = self.nativeMessageTarget {
                        self.updateNativeConversationPreview(for: target, message: latest)
                    }
                } else if payload.messages.count != self.nativeThreadMessages.count {
                    self.nativeThreadMessages = payload.messages
                    self.renderNativeThreadMessages()
                }
                self.clearNativeUnread(for: username)
            }
        }
    }

    private func updateNativeThreadKeyboardPosition() {
        guard isShowingNativeMessages, !nativeThreadContainer.isHidden else { return }
        guard let keyboardFrame = currentKeyboardFrameInView else {
            nativeThreadComposerBottomConstraint?.constant = -14
            return
        }
        let containerFrame = nativeThreadContainer.convert(nativeThreadContainer.bounds, to: view)
        let overlap = max(0, containerFrame.maxY - keyboardFrame.minY)
        nativeThreadComposerBottomConstraint?.constant = -(overlap + 14)
    }

    private func updateNativeThreadTableInsets() {
        nativeThreadTableView.contentInset.bottom = 8
        nativeThreadTableView.verticalScrollIndicatorInsets.bottom = 8
    }

    private func updateNativeThreadTextViewHeight(animated: Bool) {
        let fittingSize = CGSize(width: max(nativeThreadTextView.bounds.width, 1), height: CGFloat.greatestFiniteMagnitude)
        let measuredHeight = nativeThreadTextView.sizeThatFits(fittingSize).height
        let targetHeight = min(max(measuredHeight, 44), 104)
        nativeThreadTextViewHeightConstraint?.constant = targetHeight
        nativeThreadTextView.isScrollEnabled = measuredHeight > 104
        updateNativeThreadTableInsets()
        let changes = {
            self.view.layoutIfNeeded()
            self.scrollNativeThreadToBottomWhenReady(animated: false)
        }
        if animated {
            UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .curveEaseOut], animations: changes)
        } else {
            changes()
        }
    }

    private func nativeCurrentUserSummary() -> NativeUserSummary {
        NativeUserSummary(
            id: 0,
            username: currentUsername,
            display_name: currentUsername.isEmpty ? "You" : currentUsername,
            avatar_url: "",
            avatar_emoji: "🦅",
            use_emoji: true,
            is_verified: false,
            is_creator: false
        )
    }

    private func appendNativeThreadMessage(_ message: NativeThreadMessage, animated: Bool) {
        let previousCount = nativeThreadMessages.count
        let tableRows = nativeThreadTableView.numberOfRows(inSection: 0)
        nativeThreadMessages.append(message)
        nativeThreadEmptyLabel.isHidden = true

        guard animated, tableRows == previousCount else {
            renderNativeThreadMessages()
            scrollNativeThreadToBottomWhenReady(animated: animated)
            return
        }

        let indexPath = IndexPath(row: previousCount, section: 0)
        nativeThreadTableView.performBatchUpdates({
            nativeThreadTableView.insertRows(at: [indexPath], with: .bottom)
        }, completion: { [weak self] _ in
            self?.scrollNativeThreadToBottomWhenReady(animated: true)
        })
    }

    private func replaceNativeThreadMessage(id: Int, with message: NativeThreadMessage) {
        guard let index = nativeThreadMessages.firstIndex(where: { $0.id == id }) else { return }
        nativeThreadMessages[index] = message
        let rowCount = nativeThreadTableView.numberOfRows(inSection: 0)
        guard index < rowCount else {
            renderNativeThreadMessages()
            return
        }
        nativeThreadTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
    }

    private func removeNativeThreadMessage(id: Int) {
        guard let index = nativeThreadMessages.firstIndex(where: { $0.id == id }) else { return }
        let previousCount = nativeThreadMessages.count
        let tableRows = nativeThreadTableView.numberOfRows(inSection: 0)
        nativeThreadMessages.remove(at: index)
        nativeThreadEmptyLabel.isHidden = !nativeThreadMessages.isEmpty

        guard tableRows == previousCount, index < tableRows else {
            renderNativeThreadMessages()
            return
        }

        nativeThreadTableView.performBatchUpdates({
            nativeThreadTableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        })
    }

    private func updateNativeConversationPreview(for target: NativeUserSummary, message: NativeThreadMessage) {
        if let convoIndex = nativeMessageConversations.firstIndex(where: { $0.username == target.username }) {
            nativeMessageConversations[convoIndex].latest_message = message.body
            nativeMessageConversations[convoIndex].latest_message_relative = message.created_at_relative
            nativeMessageConversations[convoIndex].latest_message_at = message.created_at
            nativeMessageConversations[convoIndex].unread_count = target.username == nativeMessageTarget?.username ? 0 : nativeMessageConversations[convoIndex].unread_count
            let updated = nativeMessageConversations.remove(at: convoIndex)
            nativeMessageConversations.insert(updated, at: 0)
        } else {
            var newConversation = NativeMessageConversation(from: target)
            newConversation.latest_message = message.body
            newConversation.latest_message_relative = message.created_at_relative
            newConversation.latest_message_at = message.created_at
            nativeMessageConversations.insert(newConversation, at: 0)
        }
        nativeMessagesListTableView.reloadData()
    }

    private func clearNativeUnread(for username: String) {
        guard let index = nativeMessageConversations.firstIndex(where: { $0.username == username }),
              nativeMessageConversations[index].unread_count != 0 else { return }
        nativeMessageConversations[index].unread_count = 0
        let rowCount = nativeMessagesListTableView.numberOfRows(inSection: 0)
        guard index < rowCount else {
            nativeMessagesListTableView.reloadData()
            return
        }
        nativeMessagesListTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
    }

    private func animateNativeSendPress() {
        UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.nativeThreadSendButton.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.nativeThreadComposerBar.transform = CGAffineTransform(translationX: 0, y: 1)
        } completion: { _ in
            UIView.animate(withDuration: 0.16, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.5, options: [.beginFromCurrentState]) {
                self.nativeThreadSendButton.transform = .identity
                self.nativeThreadComposerBar.transform = .identity
            }
        }
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

    private func storyMultipartBody(boundary: String, imageData: Data, imageName: String, mimeType: String) -> Data {
        var data = Data()
        let lineBreak = "\r\n"
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"body\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append(lineBreak.data(using: .utf8)!)
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"media\"; filename=\"\(imageName)\"\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append(imageData)
        data.append(lineBreak.data(using: .utf8)!)
        data.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return data
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == nativeJSONScriptMessageName {
            guard let payload = message.body as? [String: Any],
                  let id = payload["id"] as? String,
                  let completion = pendingNativeJSONRequests.removeValue(forKey: id) else { return }
            let responseText = payload["text"] as? String ?? ""
            let status = nativeInt(from: payload["status"]) ?? 0
            let preview = String(responseText.prefix(300)).replacingOccurrences(of: "\n", with: " ")
            print("Native DM response status=\(status) body=\(preview)")
            completion(.success(responseText.data(using: .utf8) ?? Data()))
            return
        }
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

    @objc private func handleNativeFeedRefresh() {
        loadNativeFeed(force: true)
    }

    @objc private func handleNativeFeedSegmentChanged() {
        switch nativeFeedSegment.selectedSegmentIndex {
        case 1:
            currentFeedTab = "fyp"
        case 2:
            currentFeedTab = "breaking"
        default:
            currentFeedTab = "home"
        }
        let route = currentFeedTab == "home" ? "/" : "/?tab=\(currentFeedTab)"
        currentRoute = route
        lastRouteBySection[.feed] = route
        nativeFeedPosts = []
        nativeFeedPolls = []
        nativeFeedTableView.reloadData()
        nativeFeedEmptyLabel.text = "Loading posts..."
        nativeFeedEmptyLabel.isHidden = false
        navigateWebView(to: route, replace: false)
        loadNativeFeed(force: true)
    }

    private func handleNativeFeedPostAction(_ post: NativeFeedPost, action: NativeFeedPostAction) {
        switch action {
        case .comment:
            presentNativeComments(for: post)
        case .like:
            guard !post.is_mine else {
                showNativeFlash(message: "You can't like your own post.", category: "error")
                return
            }
            updateNativeFeedPost(id: post.id) { item in
                item.has_liked.toggle()
                item.like_count = max(0, item.like_count + (item.has_liked ? 1 : -1))
            }
            performNativeFeedPostAction(path: "/post/\(post.id)/like")
        case .repost:
            guard !post.is_mine else {
                showNativeFlash(message: "You can't repost your own post.", category: "error")
                return
            }
            updateNativeFeedPost(id: post.id) { item in
                item.has_reposted.toggle()
                item.repost_count = max(0, item.repost_count + (item.has_reposted ? 1 : -1))
            }
            performNativeFeedPostAction(path: "/post/\(post.id)/repost")
        case .bookmark:
            updateNativeFeedPost(id: post.id) { item in
                item.has_bookmarked.toggle()
                item.bookmark_count = max(0, item.bookmark_count + (item.has_bookmarked ? 1 : -1))
            }
            performNativeFeedPostAction(path: "/post/\(post.id)/bookmark")
        }
    }

    private func presentNativeComments(for post: NativeFeedPost) {
        nativeCommentsPost = post
        nativeComments = []
        nativeCommentsTitleLabel.text = "Comments"
        nativeCommentsSubtitleLabel.text = post.comment_count == 1 ? "1 comment" : "\(post.comment_count) comments"
        if let currentUser = nativeCurrentUser {
            nativeCommentsComposerAvatar.configure(with: currentUser, imageCache: nativeAvatarImageCache)
        }
        nativeCommentsTextView.text = ""
        nativeCommentsReplyTarget = nil
        updateNativeCommentsReplyState()
        updateNativeCommentsComposeState()
        nativeCommentsTableView.reloadData()
        nativeCommentsDimView.isHidden = false
        nativeCommentsSheet.isHidden = false
        view.bringSubviewToFront(nativeCommentsDimView)
        view.bringSubviewToFront(nativeCommentsSheet)
        view.layoutIfNeeded()
        nativeCommentsSheetBottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut]) {
            self.nativeCommentsDimView.alpha = 1
            self.nativeCommentsSheet.alpha = 1
            self.view.layoutIfNeeded()
        }
        loadNativeComments(for: post)
    }

    @objc private func dismissNativeComments() {
        nativeCommentsTextView.resignFirstResponder()
        let reset = {
            self.nativeCommentsDimView.alpha = 0
            self.nativeCommentsSheet.alpha = 0
            self.nativeCommentsSheetBottomConstraint?.constant = 520
            self.view.layoutIfNeeded()
        }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: reset) { _ in
            self.nativeCommentsDimView.isHidden = true
            self.nativeCommentsSheet.isHidden = true
            self.nativeCommentsPost = nil
            self.nativeComments = []
            self.nativeCommentsReplyTarget = nil
            self.updateNativeCommentsReplyState()
            self.nativeCommentsTableView.reloadData()
        }
    }

    @objc private func dismissNativeCommentsKeyboard() {
        nativeCommentsTextView.resignFirstResponder()
    }

    @objc private func cancelNativeCommentReply() {
        nativeCommentsReplyTarget = nil
        updateNativeCommentsReplyState()
        nativeCommentsTextView.text = ""
        updateNativeCommentsComposeState()
    }

    @objc private func openNativeCommentsFullPost() {
        guard let post = nativeCommentsPost else { return }
        dismissNativeComments()
        showNativePostDetail(for: post)
    }

    private func loadNativeComments(for post: NativeFeedPost) {
        performNativeJSONRequest(path: "/api/post/\(post.id)/comments") { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.nativeCommentsPost?.id == post.id else { return }
                switch result {
                case .success(let data):
                    guard let payload = try? JSONDecoder().decode(NativeCommentsResponse.self, from: data), payload.ok else {
                        self.showNativeFlash(message: "Comments couldn't load.", category: "error")
                        return
                    }
                    self.nativeComments = payload.flatComments
                    if self.nativePostDetailPost?.id == post.id {
                        self.nativePostDetailComments = payload.flatComments
                        self.nativePostDetailTableView.reloadData()
                    }
                    if let updatedPost = payload.post {
                        self.nativeCommentsPost = updatedPost
                        self.updateNativeFeedPost(id: updatedPost.id) { item in
                            item.comment_count = updatedPost.comment_count
                        }
                    }
                    let count = self.nativeComments.count
                    self.nativeCommentsSubtitleLabel.text = count == 1 ? "1 comment" : "\(count) comments"
                    self.nativeCommentsTableView.reloadData()
                case .failure(let error):
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func beginNativeCommentReply(to comment: NativeComment) {
        nativeCommentsReplyTarget = comment
        updateNativeCommentsReplyState()
        nativeCommentsTextView.becomeFirstResponder()
    }

    private func toggleNativeCommentLike(_ comment: NativeComment) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        performNativeJSONRequest(path: "/post/\(comment.id)/like", method: "POST") { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let post = self.nativeCommentsPost {
                    self.loadNativeComments(for: post)
                }
                if let detailPost = self.nativePostDetailPost {
                    self.loadNativePostDetail(postID: detailPost.id)
                }
            }
        }
    }

    private func updateNativeCommentsReplyState() {
        if let target = nativeCommentsReplyTarget {
            nativeCommentsReplyingLabel.text = "Replying to @\(target.author.username)"
            nativeCommentsReplyingLabel.isHidden = false
            nativeCommentsCancelReplyButton.isHidden = false
            nativeCommentsPlaceholder.text = "Reply to @\(target.author.username)..."
        } else {
            nativeCommentsReplyingLabel.text = ""
            nativeCommentsReplyingLabel.isHidden = true
            nativeCommentsCancelReplyButton.isHidden = true
            nativeCommentsPlaceholder.text = "Add a comment for everyone to see..."
        }
    }

    @objc private func sendNativeComment() {
        guard let post = nativeCommentsPost else { return }
        let body = nativeCommentsTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        nativeCommentsSendButton.isEnabled = false
        nativeCommentsSendButton.alpha = 0.65
        var bodyObject: [String: Any] = ["body": body]
        if let replyTarget = nativeCommentsReplyTarget {
            bodyObject["reply_to_id"] = replyTarget.id
        }
        performNativeJSONRequest(path: "/api/post/\(post.id)/comments", method: "POST", bodyObject: bodyObject) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.nativeCommentsSendButton.isEnabled = true
                self.nativeCommentsSendButton.alpha = 1
                switch result {
                case .success(let data):
                    guard let payload = try? JSONDecoder().decode(NativeCommentsResponse.self, from: data), payload.ok else {
                        self.showNativeFlash(message: "Comment failed. Try again.", category: "error")
                        return
                    }
                    self.nativeCommentsTextView.text = ""
                    self.nativeCommentsReplyTarget = nil
                    self.updateNativeCommentsReplyState()
                    self.updateNativeCommentsComposeState()
                    self.nativeComments = payload.flatComments
                    if self.nativePostDetailPost?.id == post.id {
                        self.nativePostDetailComments = payload.flatComments
                        self.nativePostDetailTableView.reloadData()
                    }
                    if let updatedPost = payload.post {
                        self.nativeCommentsPost = updatedPost
                        self.updateNativeFeedPost(id: updatedPost.id) { item in
                            item.comment_count = updatedPost.comment_count
                        }
                    }
                    let count = self.nativeComments.count
                    self.nativeCommentsSubtitleLabel.text = count == 1 ? "1 comment" : "\(count) comments"
                    self.nativeCommentsTableView.reloadData()
                    if count > 0 {
                        self.nativeCommentsTableView.scrollToRow(at: IndexPath(row: count - 1, section: 0), at: .bottom, animated: true)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                case .failure(let error):
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func updateNativeCommentsComposeState() {
        let trimmed = nativeCommentsTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        nativeCommentsPlaceholder.isHidden = !trimmed.isEmpty
        nativeCommentsSendButton.isEnabled = !trimmed.isEmpty
        nativeCommentsSendButton.alpha = trimmed.isEmpty ? 0.55 : 1
        nativeCommentsSendButton.backgroundColor = trimmed.isEmpty
            ? UIColor(red: 123.0 / 255.0, green: 145.0 / 255.0, blue: 189.0 / 255.0, alpha: 0.82)
            : UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
        nativeCommentsSendButton.setTitleColor(.white, for: .normal)
        let targetHeight = min(max(nativeCommentsTextView.contentSize.height, 44), 112)
        nativeCommentsTextViewHeightConstraint?.constant = targetHeight
    }

    private func performNativeFeedPostAction(path: String) {
        performNativeJSONRequest(path: path, method: "POST", bodyObject: [:]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.loadNativeFeed(force: true)
                    }
                case .failure(let error):
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func voteNativePoll(_ poll: NativeFeedPoll, option: NativeFeedPollOption) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        performNativeJSONRequest(path: "/polls/\(poll.id)/vote", method: "POST", bodyObject: ["option_id": option.id]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.loadNativeFeed(force: true)
                case .failure(let error):
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func toggleNativeProfileFollow() {
        guard let user = nativeProfileUser, user.can_follow else { return }
        nativeProfileHeaderView.setFollowLoading(true)
        performNativeJSONRequest(path: "/api/users/\(user.username)/follow", method: "POST", bodyObject: [:]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.nativeProfileHeaderView.setFollowLoading(false)
                switch result {
                case .success(let data):
                    guard let payload = try? JSONDecoder().decode(NativeProfileFollowResponse.self, from: data), payload.ok else {
                        self.showNativeFlash(message: "Follow failed. Try again.", category: "error")
                        return
                    }
                    self.nativeProfileUser = payload.user
                    self.nativeProfileHeaderView.configure(user: payload.user, imageCache: self.nativeAvatarImageCache)
                case .failure(let error):
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                }
            }
        }
    }

    private func updateNativeFeedPost(id: Int, mutate: (inout NativeFeedPost) -> Void) {
        if let index = nativeFeedPosts.firstIndex(where: { $0.id == id }) {
            mutate(&nativeFeedPosts[index])
            let indexPath = IndexPath(row: nativeFeedPolls.count + index, section: 0)
            if nativeFeedTableView.indexPathsForVisibleRows?.contains(indexPath) == true {
                nativeFeedTableView.reloadRows(at: [indexPath], with: .none)
            }
        }
        if let detail = nativePostDetailPost, detail.id == id {
            var updated = detail
            mutate(&updated)
            nativePostDetailPost = updated
            if nativePostDetailTableView.numberOfRows(inSection: 0) > 0 {
                nativePostDetailTableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
        }
        if let profileIndex = nativeProfilePosts.firstIndex(where: { $0.id == id }) {
            mutate(&nativeProfilePosts[profileIndex])
            let profileIndexPath = IndexPath(row: profileIndex, section: 0)
            if nativeProfileTableView.indexPathsForVisibleRows?.contains(profileIndexPath) == true {
                nativeProfileTableView.reloadRows(at: [profileIndexPath], with: .none)
            }
        }
    }

    private func openPrimarySection(_ section: PrimarySection) {
        hideNativePostDetailIfNeeded()
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
                renderNativeThreadMessages()
                loadNativeInbox()
            }
            return
        }
        let targetUsername = currentUsername
        let escapedUsername = targetUsername
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let preferredRoute = section == .feed ? "/" : (lastRouteBySection[section] ?? {
            switch section {
            case .messages: return "/messages"
            case .feed: return "/"
            case .search: return "/search"
            case .profile: return targetUsername.isEmpty ? "/" : "/users/\(targetUsername)"
            }
        }())
        let escapedRoute = preferredRoute
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        currentPrimarySection = section
        updateNativeTabSelection(animated: true)
        hideNativeMessagesIfNeeded()
        if section == .feed {
            currentFeedTab = preferredRoute.contains("tab=fyp") ? "fyp" : (preferredRoute.contains("tab=breaking") ? "breaking" : "home")
            currentRoute = preferredRoute
            lastRouteBySection[.feed] = preferredRoute
            updateNativeSectionPresentation()
            loadNativeFeed(force: false)
        } else if section == .profile {
            currentRoute = preferredRoute
            lastRouteBySection[.profile] = preferredRoute
            hideNativeFeedIfNeeded()
            hideNativeMessagesIfNeeded()
            showNativeProfileIfNeeded(username: targetUsername)
        } else if section == .search {
            currentRoute = "/search"
            lastRouteBySection[.search] = "/search"
            hideNativeFeedIfNeeded()
            hideNativeMessagesIfNeeded()
            hideNativeProfileIfNeeded()
            showNativeSearchIfNeeded()
        } else {
            hideNativeFeedIfNeeded()
        }
        let script = "window.nativeOpenPrimaryRoute && window.nativeOpenPrimaryRoute(\"\(section.rawValue)\", \"\(escapedUsername)\", \"\(escapedRoute)\", true);"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    @objc private func handleNativeThreadBack() {
        nativeThreadTextView.resignFirstResponder()
        stopNativeThreadRefresh()
        nativeThreadContainer.isHidden = true
        nativeThreadMessages = []
        renderNativeThreadMessages()
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
        animateNativeSendPress()
        updateNativeThreadComposeState()
        let optimisticID = -Int(Date().timeIntervalSince1970 * 1000)
        let previousConversations = nativeMessageConversations
        let optimisticMessage = NativeThreadMessage(
            id: optimisticID,
            body: body,
            is_mine: true,
            is_read: true,
            created_at: "",
            created_at_relative: "now",
            sender: nativeCurrentUserSummary(),
            receiver: target
        )
        nativeThreadTextView.text = ""
        updateNativeThreadTextViewHeight(animated: true)
        appendNativeThreadMessage(optimisticMessage, animated: true)
        updateNativeConversationPreview(for: target, message: optimisticMessage)
        nativeThreadTextView.becomeFirstResponder()
        updateNativeThreadComposeState()

        performNativeJSONRequest(path: "/api/messages/send", method: "POST", bodyObject: ["receiver": target.username, "body": body]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSendingNativeMessage = false
                switch result {
                case .success(let data):
                    guard let payload = self.parseNativeSendMessagePayload(from: data), payload.ok else {
                        self.removeNativeThreadMessage(id: optimisticID)
                        self.nativeMessageConversations = previousConversations
                        self.nativeMessagesListTableView.reloadData()
                        self.nativeThreadTextView.text = body
                        self.updateNativeThreadTextViewHeight(animated: true)
                        if let payload = self.parseNativeSendMessagePayload(from: data), let error = payload.error, !error.isEmpty {
                            self.showNativeFlash(message: error, category: "error")
                        } else {
                            self.showNativeFlash(message: "Send error: \(self.nativeResponsePreview(from: data))", category: "error")
                        }
                        self.updateNativeThreadComposeState()
                        return
                    }
                    if let message = payload.message {
                        self.replaceNativeThreadMessage(id: optimisticID, with: message)
                        self.updateNativeConversationPreview(for: target, message: message)
                    }
                    self.updateNativeThreadComposeState()
                    self.nativeThreadTextView.becomeFirstResponder()
                case .failure(let error):
                    self.removeNativeThreadMessage(id: optimisticID)
                    self.nativeMessageConversations = previousConversations
                    self.nativeMessagesListTableView.reloadData()
                    self.nativeThreadTextView.text = body
                    self.updateNativeThreadTextViewHeight(animated: true)
                    self.showNativeFlash(message: error.localizedDescription, category: "error")
                    self.updateNativeThreadComposeState()
                    self.nativeThreadTextView.becomeFirstResponder()
                }
            }
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView === nativeThreadTextView {
            updateNativeThreadComposeState()
            updateNativeThreadTextViewHeight(animated: true)
            return
        }
        if textView === nativeCommentsTextView {
            updateNativeCommentsComposeState()
            UIView.animate(withDuration: 0.14) {
                self.view.layoutIfNeeded()
            }
            return
        }
        composerPlaceholder.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        updateComposerTextStyling()
        updateComposerMentionSuggestions()
        let targetHeight = min(max(textView.contentSize.height, 92), 180)
        composerTextViewHeightConstraint?.constant = targetHeight
        composerPostButton.isEnabled = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
        composerPostButton.alpha = composerPostButton.isEnabled ? 1 : 0.55
        UIView.animate(withDuration: 0.14) {
            self.view.layoutIfNeeded()
        }
    }

    private func renderNativeThreadMessages() {
        nativeThreadTableView.reloadData()
        nativeThreadEmptyLabel.isHidden = !nativeThreadMessages.isEmpty
        scrollNativeThreadToBottomWhenReady(animated: false)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === nativeFeedTableView {
            return nativeFeedPolls.count + nativeFeedPosts.count
        }
        if tableView === nativePostDetailTableView {
            return (nativePostDetailPost == nil ? 0 : 1) + nativePostDetailComments.count
        }
        if tableView === nativeProfileTableView {
            return nativeProfilePosts.count
        }
        if tableView === nativeSearchTableView {
            return nativeSearchUsers.count + nativeSearchPosts.count
        }
        if tableView === nativeConnectionsTableView {
            return nativeConnectionsUsers.count
        }
        if tableView === nativeMessagesListTableView {
            return nativeMessageConversations.count
        }
        if tableView === nativeCommentsTableView {
            return nativeComments.count
        }
        return nativeThreadMessages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView === nativeFeedTableView {
            if indexPath.row < nativeFeedPolls.count {
                let cell = tableView.dequeueReusableCell(withIdentifier: NativeFeedPollCell.reuseIdentifier, for: indexPath) as! NativeFeedPollCell
                cell.configure(with: nativeFeedPolls[indexPath.row])
                cell.onVote = { [weak self] poll, option in
                    self?.voteNativePoll(poll, option: option)
                }
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: NativeFeedPostCell.reuseIdentifier, for: indexPath) as! NativeFeedPostCell
            let postIndex = indexPath.row - nativeFeedPolls.count
            cell.configure(with: nativeFeedPosts[postIndex], avatarCache: nativeAvatarImageCache, mediaCache: nativeFeedImageCache)
            cell.onAction = { [weak self] post, action in
                self?.handleNativeFeedPostAction(post, action: action)
            }
            return cell
        }
        if tableView === nativePostDetailTableView {
            if indexPath.row == 0, let post = nativePostDetailPost {
                let cell = tableView.dequeueReusableCell(withIdentifier: NativeFeedPostCell.reuseIdentifier, for: indexPath) as! NativeFeedPostCell
                cell.configure(with: post, avatarCache: nativeAvatarImageCache, mediaCache: nativeFeedImageCache)
                cell.onAction = { [weak self] post, action in
                    self?.handleNativeFeedPostAction(post, action: action)
                }
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: NativeCommentCell.reuseIdentifier, for: indexPath) as! NativeCommentCell
            cell.configure(with: nativePostDetailComments[indexPath.row - 1], imageCache: nativeAvatarImageCache)
            cell.onLike = { [weak self] comment in self?.toggleNativeCommentLike(comment) }
            cell.onReply = { [weak self] comment in
                guard let self, let post = self.nativePostDetailPost else { return }
                self.presentNativeComments(for: post)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.beginNativeCommentReply(to: comment)
                }
            }
            return cell
        }
        if tableView === nativeProfileTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: NativeFeedPostCell.reuseIdentifier, for: indexPath) as! NativeFeedPostCell
            cell.configure(with: nativeProfilePosts[indexPath.row], avatarCache: nativeAvatarImageCache, mediaCache: nativeFeedImageCache)
            cell.onAction = { [weak self] post, action in
                self?.handleNativeFeedPostAction(post, action: action)
            }
            return cell
        }
        if tableView === nativeSearchTableView {
            if indexPath.row < nativeSearchUsers.count {
                let cell = tableView.dequeueReusableCell(withIdentifier: NativeConnectionCell.reuseIdentifier, for: indexPath) as! NativeConnectionCell
                cell.configure(user: nativeSearchUsers[indexPath.row], imageCache: nativeAvatarImageCache)
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: NativeFeedPostCell.reuseIdentifier, for: indexPath) as! NativeFeedPostCell
            let post = nativeSearchPosts[indexPath.row - nativeSearchUsers.count]
            cell.configure(with: post, avatarCache: nativeAvatarImageCache, mediaCache: nativeFeedImageCache)
            cell.onAction = { [weak self] post, action in
                self?.handleNativeFeedPostAction(post, action: action)
            }
            return cell
        }
        if tableView === nativeConnectionsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: NativeConnectionCell.reuseIdentifier, for: indexPath) as! NativeConnectionCell
            cell.configure(user: nativeConnectionsUsers[indexPath.row], imageCache: nativeAvatarImageCache)
            return cell
        }
        if tableView === nativeMessagesListTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: NativeConversationCell.reuseIdentifier, for: indexPath) as! NativeConversationCell
            cell.configure(with: nativeMessageConversations[indexPath.row], imageCache: nativeAvatarImageCache)
            return cell
        }
        if tableView === nativeCommentsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: NativeCommentCell.reuseIdentifier, for: indexPath) as! NativeCommentCell
            cell.configure(with: nativeComments[indexPath.row], imageCache: nativeAvatarImageCache)
            cell.onLike = { [weak self] comment in self?.toggleNativeCommentLike(comment) }
            cell.onReply = { [weak self] comment in self?.beginNativeCommentReply(to: comment) }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: NativeThreadMessageCell.reuseIdentifier, for: indexPath) as! NativeThreadMessageCell
        cell.configure(with: nativeThreadMessages[indexPath.row], imageCache: nativeAvatarImageCache)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView === nativeFeedTableView {
            guard indexPath.row >= nativeFeedPolls.count else { return }
            let post = nativeFeedPosts[indexPath.row - nativeFeedPolls.count]
            showNativePostDetail(for: post)
            return
        }
        if tableView === nativeProfileTableView {
            showNativePostDetail(for: nativeProfilePosts[indexPath.row])
            return
        }
        if tableView === nativeSearchTableView {
            if indexPath.row < nativeSearchUsers.count {
                let user = nativeSearchUsers[indexPath.row]
                nativeRouteOverrideUntil = Date().addingTimeInterval(3)
                currentPrimarySection = .profile
                currentRoute = "/users/\(user.username)"
                lastRouteBySection[.profile] = currentRoute
                updateNativeTabSelection(animated: true)
                dismissNativeConnections()
                updateNativeSectionPresentation()
            } else {
                showNativePostDetail(for: nativeSearchPosts[indexPath.row - nativeSearchUsers.count])
            }
            return
        }
        if tableView === nativeConnectionsTableView {
            let user = nativeConnectionsUsers[indexPath.row]
            dismissNativeConnections()
            nativeRouteOverrideUntil = Date().addingTimeInterval(3)
            currentPrimarySection = .profile
            currentRoute = "/users/\(user.username)"
            lastRouteBySection[.profile] = currentRoute
            updateNativeTabSelection(animated: true)
            updateNativeSectionPresentation()
            return
        }
        if tableView === nativePostDetailTableView {
            if indexPath.row == 0, let post = nativePostDetailPost {
                presentNativeComments(for: post)
            }
            return
        }
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
        if tableView === nativeCommentsTableView {
            nativeCommentsTextView.becomeFirstResponder()
        }
    }

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        let posts: [NativeFeedPost]
        if tableView === nativeFeedTableView {
            posts = indexPaths.compactMap { indexPath in
                let postIndex = indexPath.row - nativeFeedPolls.count
                return postIndex >= 0 && postIndex < nativeFeedPosts.count ? nativeFeedPosts[postIndex] : nil
            }
        } else if tableView === nativeProfileTableView {
            posts = indexPaths.compactMap { indexPath in
                indexPath.row < nativeProfilePosts.count ? nativeProfilePosts[indexPath.row] : nil
            }
        } else if tableView === nativePostDetailTableView {
            posts = nativePostDetailPost.map { [$0] } ?? []
        } else if tableView === nativeSearchTableView {
            posts = indexPaths.compactMap { indexPath in
                let postIndex = indexPath.row - nativeSearchUsers.count
                return postIndex >= 0 && postIndex < nativeSearchPosts.count ? nativeSearchPosts[postIndex] : nil
            }
        } else {
            return
        }
        prefetchNativeFeedImages(for: posts)
    }

    @objc private func openPhotoPicker() {
        presentPhotoPicker(purpose: .post, mediaFilter: .any(of: [.images, .videos]))
    }

    private func presentPhotoPicker(purpose: NativePhotoPickerPurpose, mediaFilter: PHPickerFilter = .any(of: [.images, .videos])) {
        photoPickerPurpose = purpose
        DispatchQueue.main.async {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = mediaFilter
            configuration.selectionLimit = 1
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            picker.modalPresentationStyle = .pageSheet
            if self.presentedViewController != nil {
                self.dismiss(animated: false) {
                    self.topPresentationController().present(picker, animated: true)
                }
            } else {
                self.topPresentationController().present(picker, animated: true)
            }
        }
    }

    private func topPresentationController() -> UIViewController {
        var controller: UIViewController = self
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
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
        composerPreviewImageView.contentMode = .scaleAspectFill
        composerPreviewContainer.isHidden = true
        composerPreviewHeightConstraint?.constant = 0
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        let purpose = photoPickerPurpose
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, _ in
                guard let self, let url, let data = try? Data(contentsOf: url) else { return }
                let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                DispatchQueue.main.async {
                    if purpose == .story {
                        self.uploadNativeStory(imageData: data, imageName: "story.\(ext)", mimeType: ext.lowercased() == "mp4" ? "video/mp4" : "video/quicktime")
                        return
                    }
                    self.composerPreviewImageView.image = UIImage(systemName: "play.rectangle.fill")
                    self.composerPreviewImageView.tintColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
                    self.composerPreviewImageView.contentMode = .center
                    self.composerPreviewContainer.isHidden = false
                    self.composerPreviewHeightConstraint?.constant = 140
                    self.selectedImageData = data
                    self.selectedImageName = "video.\(ext)"
                    self.selectedImageMimeType = ext.lowercased() == "mp4" ? "video/mp4" : "video/quicktime"
                    self.textViewDidChange(self.composerTextView)
                }
            }
            return
        }
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self, let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    if purpose == .story {
                        guard let imageData = image.jpegData(compressionQuality: 0.88) else {
                            self.showNativeFlash(message: "Story upload failed. Try again.", category: "error")
                            return
                        }
                        self.uploadNativeStory(imageData: imageData, imageName: "story.jpg", mimeType: "image/jpeg")
                        return
                    }
                    self.presentNativeImageAdjuster(image)
                }
            }
        }
    }

    private func presentNativeImageAdjuster(_ image: UIImage) {
        let editor = NativeImageAdjustViewController(image: image) { [weak self] adjusted in
            guard let self else { return }
            self.composerPreviewImageView.image = adjusted
            self.composerPreviewImageView.contentMode = .scaleAspectFit
            self.composerPreviewContainer.isHidden = false
            self.composerPreviewHeightConstraint?.constant = 140
            self.selectedImageData = adjusted.jpegData(compressionQuality: 0.9)
            self.selectedImageName = "photo.jpg"
            self.selectedImageMimeType = "image/jpeg"
            self.textViewDidChange(self.composerTextView)
        }
        editor.modalPresentationStyle = .pageSheet
        topPresentationController().present(editor, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        guard let image, let data = image.jpegData(compressionQuality: 0.88) else { return }
        if photoPickerPurpose == .story {
            uploadNativeStory(imageData: data, imageName: "story.jpg", mimeType: "image/jpeg")
            return
        }
        composerPreviewImageView.image = image
        composerPreviewImageView.contentMode = .scaleAspectFit
        composerPreviewContainer.isHidden = false
        composerPreviewHeightConstraint?.constant = 140
        selectedImageData = data
        selectedImageName = "photo.jpg"
        selectedImageMimeType = "image/jpeg"
        textViewDidChange(composerTextView)
    }

    private func uploadNativeStory(imageData: Data, imageName: String, mimeType: String) {
        guard let targetURL = URL(string: "/story/create", relativeTo: webView?.url)?.absoluteURL else { return }
        showNativeFlash(message: "Uploading story...", category: "success")
        fetchCookieHeader(for: targetURL) { [weak self] cookieHeader in
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
            request.httpBody = self.storyMultipartBody(boundary: boundary, imageData: imageData, imageName: imageName, mimeType: mimeType)

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if error != nil {
                        self.showNativeFlash(message: "Story upload failed. Try again.", category: "error")
                        return
                    }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 0 || (200..<400).contains(status),
                          let data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          (json["ok"] as? Bool) == true else {
                        let message = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["error"] as? String
                        self.showNativeFlash(message: message ?? "Story upload failed. Try again.", category: "error")
                        return
                    }
                    self.loadNativeFeed(force: true)
                    self.showNativeFlash(message: "Story posted.", category: "success")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }.resume()
        }
    }
}

private struct NativeFeedResponse: Decodable {
    let ok: Bool
    let feed_mode: String
    let latest_post_id: Int
    let posts: [NativeFeedPost]
    let stories: [NativeFeedStory]
    let polls: [NativeFeedPoll]
    let current_user: NativeUserSummary?
    let current_user_story: Bool

    private enum CodingKeys: String, CodingKey {
        case ok
        case feed_mode
        case latest_post_id
        case posts
        case stories
        case polls
        case current_user
        case current_user_story
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decode(Bool.self, forKey: .ok)
        feed_mode = try container.decode(String.self, forKey: .feed_mode)
        latest_post_id = try container.decode(Int.self, forKey: .latest_post_id)
        posts = try container.decode([NativeFeedPost].self, forKey: .posts)
        stories = try container.decodeIfPresent([NativeFeedStory].self, forKey: .stories) ?? []
        polls = try container.decodeIfPresent([NativeFeedPoll].self, forKey: .polls) ?? []
        current_user = try container.decodeIfPresent(NativeUserSummary.self, forKey: .current_user)
        current_user_story = try container.decodeIfPresent(Bool.self, forKey: .current_user_story) ?? false
    }
}

fileprivate struct NativeFeedStory: Decodable {
    let id: Int
    let author: NativeUserSummary
    let body: String
    let media_url: String
    let media_type: String
    let url: String
    let expires_at: String
}

fileprivate struct NativeFeedPoll: Decodable {
    let id: Int
    let question: String
    let is_hidden_results: Bool
    let results_visible: Bool
    let selected_option_id: Int?
    let options: [NativeFeedPollOption]
}

fileprivate struct NativeFeedPollOption: Decodable {
    let id: Int
    let label: String
    let votes: Int
}

fileprivate struct NativeMentionResponse: Decodable {
    let users: [NativeMentionUser]
}

fileprivate struct NativeMentionUser: Decodable {
    let username: String
    let display_name: String
    let avatar_url: String
    let avatar_emoji: String
    let use_emoji: Bool

    var summary: NativeUserSummary {
        NativeUserSummary(
            id: 0,
            username: username,
            display_name: display_name,
            avatar_url: avatar_url,
            avatar_emoji: avatar_emoji,
            use_emoji: use_emoji,
            is_verified: false,
            is_creator: false
        )
    }
}

private struct NativeFeedPost: Decodable {
    let id: Int
    let body: String
    let author: NativeUserSummary
    let created_at_relative: String
    let feed_tab: String
    let media_url: String
    let media_type: String
    let quote: NativeFeedQuote?
    let reposted_by: NativeUserSummary?
    let url: String
    var view_count: Int
    var like_count: Int
    var comment_count: Int
    var repost_count: Int
    var bookmark_count: Int
    var has_liked: Bool
    var has_reposted: Bool
    var has_bookmarked: Bool
    let is_mine: Bool
    let is_breaking: Bool
}

private struct NativeFeedQuote: Decodable {
    let id: Int
    let body: String
    let author: NativeUserSummary?
    let media_url: String
    let media_type: String
}

private struct NativeAPIErrorResponse: Decodable {
    let ok: Bool?
    let error: String?
}

private struct NativeCommentsResponse: Decodable {
    let ok: Bool
    let post: NativeFeedPost?
    let comments: [NativeComment]

    var flatComments: [NativeComment] {
        comments.flatMap { $0.flattened() }
    }
}

private struct NativePostDetailResponse: Decodable {
    let ok: Bool
    let post: NativeFeedPost
    let comments: [NativeComment]

    var flatComments: [NativeComment] {
        comments.flatMap { $0.flattened() }
    }
}

private struct NativeProfileResponse: Decodable {
    let ok: Bool
    let user: NativeProfileUser
    let posts: [NativeFeedPost]
}

private struct NativeProfileFollowResponse: Decodable {
    let ok: Bool
    let user: NativeProfileUser
}

private struct NativeSearchResponse: Decodable {
    let ok: Bool
    let query: String
    let users: [NativeProfileUser]
    let posts: [NativeFeedPost]
}

private struct NativeConnectionsResponse: Decodable {
    let ok: Bool
    let tab: String
    let users: [NativeProfileUser]
}

private struct NativeComment: Decodable {
    let id: Int
    let body: String
    let author: NativeUserSummary
    let created_at_relative: String
    let like_count: Int
    let has_liked: Bool
    let depth: Int
    let replies: [NativeComment]

    func flattened() -> [NativeComment] {
        [self] + replies.flatMap { $0.flattened() }
    }
}

private struct NativeProfileUser: Decodable {
    let id: Int
    let username: String
    let display_name: String
    let avatar_url: String
    let avatar_emoji: String
    let use_emoji: Bool
    let is_verified: Bool
    let is_creator: Bool
    let bio: String
    let location: String
    let website: String
    let banner_url: String
    let follower_count: Int
    let following_count: Int
    let post_count: Int
    let is_following: Bool
    let can_follow: Bool

    var summary: NativeUserSummary {
        NativeUserSummary(
            id: id,
            username: username,
            display_name: display_name,
            avatar_url: avatar_url,
            avatar_emoji: avatar_emoji,
            use_emoji: use_emoji,
            is_verified: is_verified,
            is_creator: is_creator
        )
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

    init(id: Int, username: String, display_name: String, avatar_url: String, avatar_emoji: String, use_emoji: Bool, is_verified: Bool, is_creator: Bool) {
        self.id = id
        self.username = username
        self.display_name = display_name
        self.avatar_url = avatar_url
        self.avatar_emoji = avatar_emoji
        self.use_emoji = use_emoji
        self.is_verified = is_verified
        self.is_creator = is_creator
    }
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

    init(id: Int, body: String, is_mine: Bool, is_read: Bool, created_at: String, created_at_relative: String, sender: NativeUserSummary, receiver: NativeUserSummary) {
        self.id = id
        self.body = body
        self.is_mine = is_mine
        self.is_read = is_read
        self.created_at = created_at
        self.created_at_relative = created_at_relative
        self.sender = sender
        self.receiver = receiver
    }
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
        imageView.contentMode = .scaleAspectFit
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

private final class NativeProfileHeaderView: UIView {
    private let cardView = UIView()
    private let bannerView = UIView()
    private let bannerGradient = CAGradientLayer()
    private let bannerImageView = UIImageView()
    private let avatarView = NativeAvatarView()
    private let nameLabel = UILabel()
    private let verifiedBadgeView = UIImageView()
    private let usernameLabel = UILabel()
    private let bioLabel = UILabel()
    private let statsStack = UIStackView()
    private let postsButton = UIButton(type: .system)
    private let followersButton = UIButton(type: .system)
    private let followingButton = UIButton(type: .system)
    private let metaLabel = UILabel()
    private let followButton = UIButton(type: .system)
    private var currentBannerKey = ""
    var onFollowTap: (() -> Void)?
    var onFollowersTap: (() -> Void)?
    var onFollowingTap: (() -> Void)?
    var preferredHeight: CGFloat { 374 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        cardView.layer.cornerRadius = 24
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.08).cgColor
        cardView.clipsToBounds = true
        addSubview(cardView)

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.backgroundColor = UIColor(red: 22.0 / 255.0, green: 83.0 / 255.0, blue: 161.0 / 255.0, alpha: 1)
        cardView.addSubview(bannerView)

        bannerGradient.colors = [
            UIColor(red: 12.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1).cgColor,
            UIColor(red: 191.0 / 255.0, green: 10.0 / 255.0, blue: 48.0 / 255.0, alpha: 0.82).cgColor,
            UIColor(red: 255.0 / 255.0, green: 184.0 / 255.0, blue: 77.0 / 255.0, alpha: 0.88).cgColor
        ]
        bannerGradient.startPoint = CGPoint(x: 0, y: 0)
        bannerGradient.endPoint = CGPoint(x: 1, y: 1)
        bannerView.layer.addSublayer(bannerGradient)

        bannerImageView.translatesAutoresizingMaskIntoConstraints = false
        bannerImageView.contentMode = .scaleAspectFill
        bannerImageView.clipsToBounds = true
        bannerImageView.alpha = 0
        bannerView.addSubview(bannerImageView)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.layer.shadowColor = UIColor.black.cgColor
        avatarView.layer.shadowOpacity = 0.14
        avatarView.layer.shadowRadius = 10
        avatarView.layer.shadowOffset = CGSize(width: 0, height: 5)
        cardView.addSubview(avatarView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 25, weight: .bold)
        nameLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        cardView.addSubview(nameLabel)

        verifiedBadgeView.translatesAutoresizingMaskIntoConstraints = false
        verifiedBadgeView.image = UIImage(systemName: "checkmark.seal.fill")
        verifiedBadgeView.tintColor = UIColor(red: 62.0 / 255.0, green: 164.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
        verifiedBadgeView.contentMode = .scaleAspectFit
        verifiedBadgeView.isHidden = true
        cardView.addSubview(verifiedBadgeView)

        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        usernameLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.88)
        cardView.addSubview(usernameLabel)

        bioLabel.translatesAutoresizingMaskIntoConstraints = false
        bioLabel.font = .systemFont(ofSize: 15)
        bioLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.94)
        bioLabel.numberOfLines = 2
        cardView.addSubview(bioLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        metaLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.8)
        metaLabel.numberOfLines = 2
        cardView.addSubview(metaLabel)

        statsStack.translatesAutoresizingMaskIntoConstraints = false
        statsStack.axis = .horizontal
        statsStack.distribution = .fillEqually
        statsStack.spacing = 8
        [postsButton, followersButton, followingButton].forEach { button in
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.backgroundColor = UIColor(red: 242.0 / 255.0, green: 247.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.88)
            button.layer.cornerRadius = 16
            button.layer.cornerCurve = .continuous
            button.setTitleColor(UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.92), for: .normal)
            statsStack.addArrangedSubview(button)
        }
        followersButton.addTarget(self, action: #selector(handleFollowersTap), for: .touchUpInside)
        followingButton.addTarget(self, action: #selector(handleFollowingTap), for: .touchUpInside)
        cardView.addSubview(statsStack)

        followButton.translatesAutoresizingMaskIntoConstraints = false
        followButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        followButton.layer.cornerRadius = 18
        followButton.layer.cornerCurve = .continuous
        followButton.addTarget(self, action: #selector(handleFollowTap), for: .touchUpInside)
        cardView.addSubview(followButton)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            bannerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            bannerView.topAnchor.constraint(equalTo: cardView.topAnchor),
            bannerView.heightAnchor.constraint(equalToConstant: 116),
            bannerImageView.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor),
            bannerImageView.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor),
            bannerImageView.topAnchor.constraint(equalTo: bannerView.topAnchor),
            bannerImageView.bottomAnchor.constraint(equalTo: bannerView.bottomAnchor),
            avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            avatarView.topAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: -34),
            avatarView.widthAnchor.constraint(equalToConstant: 74),
            avatarView.heightAnchor.constraint(equalToConstant: 74),
            followButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            followButton.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            followButton.widthAnchor.constraint(equalToConstant: 104),
            followButton.heightAnchor.constraint(equalToConstant: 36),
            nameLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: verifiedBadgeView.leadingAnchor, constant: -6),
            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 14),
            verifiedBadgeView.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            verifiedBadgeView.widthAnchor.constraint(equalToConstant: 20),
            verifiedBadgeView.heightAnchor.constraint(equalToConstant: 20),
            verifiedBadgeView.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -18),
            usernameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            usernameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            bioLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            bioLabel.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),
            bioLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 12),
            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),
            metaLabel.topAnchor.constraint(equalTo: bioLabel.bottomAnchor, constant: 10),
            statsStack.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            statsStack.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),
            statsStack.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 12),
            statsStack.heightAnchor.constraint(equalToConstant: 64),
            statsStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -18)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bannerGradient.frame = bannerView.bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(user: NativeProfileUser, imageCache: NSCache<NSString, UIImage>) {
        avatarView.configure(with: user.summary, imageCache: imageCache)
        nameLabel.text = user.display_name
        verifiedBadgeView.isHidden = !user.is_verified
        usernameLabel.text = "@\(user.username)"
        bioLabel.text = user.bio.isEmpty ? "No bio yet." : user.bio
        let metaParts = [user.location, user.website].filter { !$0.isEmpty }
        metaLabel.text = metaParts.joined(separator: "  ")
        metaLabel.isHidden = metaParts.isEmpty
        configureStatButton(postsButton, value: user.post_count, label: "Posts")
        configureStatButton(followersButton, value: user.follower_count, label: "Followers")
        configureStatButton(followingButton, value: user.following_count, label: "Following")
        configureBanner(urlString: user.banner_url, imageCache: imageCache)
        followButton.isHidden = !user.can_follow
        followButton.setTitle(user.is_following ? "Following" : "Follow", for: .normal)
        followButton.setTitleColor(user.is_following ? UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1) : .white, for: .normal)
        followButton.backgroundColor = user.is_following
            ? UIColor(red: 241.0 / 255.0, green: 245.0 / 255.0, blue: 252.0 / 255.0, alpha: 1)
            : UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
    }

    private func configureStatButton(_ button: UIButton, value: Int, label: String) {
        let text = NSMutableAttributedString(
            string: "\(value)\n",
            attributes: [.font: UIFont.systemFont(ofSize: 16, weight: .bold)]
        )
        text.append(NSAttributedString(
            string: label,
            attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.84)
            ]
        ))
        button.setAttributedTitle(text, for: .normal)
    }

    private func configureBanner(urlString: String, imageCache: NSCache<NSString, UIImage>) {
        currentBannerKey = urlString
        bannerImageView.alpha = 0
        bannerImageView.image = nil
        guard !urlString.isEmpty else { return }
        let key = NSString(string: urlString)
        if let cached = imageCache.object(forKey: key) {
            bannerImageView.image = cached
            bannerImageView.alpha = 1
            return
        }
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            imageCache.setObject(image, forKey: key)
            DispatchQueue.main.async {
                guard self.currentBannerKey == urlString else { return }
                self.bannerImageView.image = image
                UIView.animate(withDuration: 0.18) {
                    self.bannerImageView.alpha = 1
                }
            }
        }.resume()
    }

    func setFollowLoading(_ loading: Bool) {
        followButton.isEnabled = !loading
        followButton.alpha = loading ? 0.65 : 1
        if loading {
            followButton.setTitle("...", for: .normal)
        }
    }

    @objc private func handleFollowTap() {
        onFollowTap?()
    }

    @objc private func handleFollowersTap() {
        onFollowersTap?()
    }

    @objc private func handleFollowingTap() {
        onFollowingTap?()
    }
}

private final class NativeStoryViewerView: UIView {
    private let dimView = UIView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let avatarView = NativeAvatarView()
    private let nameLabel = UILabel()
    private let bodyLabel = UILabel()
    private let videoButton = UIButton(type: .system)
    private var currentMediaKey = ""
    private var videoURL: URL?
    var onClose: (() -> Void)?
    var onOpenVideo: ((URL) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        addSubview(dimView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        addSubview(imageView)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(avatarView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = .white
        addSubview(nameLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.34)
        closeButton.layer.cornerRadius = 18
        closeButton.layer.cornerCurve = .continuous
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        addSubview(closeButton)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        bodyLabel.textColor = .white
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center
        addSubview(bodyLabel)

        videoButton.translatesAutoresizingMaskIntoConstraints = false
        videoButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        videoButton.tintColor = .white
        videoButton.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        videoButton.layer.cornerRadius = 36
        videoButton.layer.cornerCurve = .continuous
        videoButton.addTarget(self, action: #selector(handleVideo), for: .touchUpInside)
        videoButton.isHidden = true
        addSubview(videoButton)

        NSLayoutConstraint.activate([
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            avatarView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 18),
            avatarView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: 38),
            avatarView.heightAnchor.constraint(equalToConstant: 38),
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -18),
            closeButton.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            bodyLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 28),
            bodyLabel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -28),
            bodyLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -46),
            videoButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            videoButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            videoButton.widthAnchor.constraint(equalToConstant: 72),
            videoButton.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(story: NativeFeedStory, avatarCache: NSCache<NSString, UIImage>, mediaCache: NSCache<NSString, UIImage>) {
        avatarView.configure(with: story.author, imageCache: avatarCache)
        nameLabel.text = story.author.display_name
        bodyLabel.text = story.body
        bodyLabel.isHidden = story.body.isEmpty
        videoURL = URL(string: story.media_url)
        videoButton.isHidden = story.media_type != "video" || videoURL == nil
        imageView.image = nil
        currentMediaKey = story.media_url
        guard !story.media_url.isEmpty, story.media_type != "video" else { return }
        let key = NSString(string: story.media_url)
        if let cached = mediaCache.object(forKey: key) {
            imageView.image = cached
            return
        }
        guard let url = URL(string: story.media_url) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            mediaCache.setObject(image, forKey: key)
            DispatchQueue.main.async {
                guard self.currentMediaKey == story.media_url else { return }
                self.imageView.image = image
            }
        }.resume()
    }

    func prepareForReuse() {
        currentMediaKey = ""
        imageView.image = nil
        videoURL = nil
    }

    @objc private func handleClose() {
        onClose?()
    }

    @objc private func handleVideo() {
        guard let videoURL else { return }
        onOpenVideo?(videoURL)
    }
}

private final class NativeImageAdjustViewController: UIViewController, UIScrollViewDelegate {
    private let image: UIImage
    private let completion: (UIImage) -> Void
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let cropGuide = UIView()

    init(image: UIImage, completion: @escaping (UIImage) -> Void) {
        self.image = image
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 238.0 / 255.0, green: 244.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Adjust Photo"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        view.addSubview(titleLabel)

        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        view.addSubview(cancelButton)

        let useButton = UIButton(type: .system)
        useButton.translatesAutoresizingMaskIntoConstraints = false
        useButton.setTitle("Use", for: .normal)
        useButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        useButton.setTitleColor(.white, for: .normal)
        useButton.backgroundColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
        useButton.layer.cornerRadius = 18
        useButton.layer.cornerCurve = .continuous
        useButton.addTarget(self, action: #selector(useImage), for: .touchUpInside)
        view.addSubview(useButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.backgroundColor = .black
        scrollView.layer.cornerRadius = 22
        scrollView.layer.cornerCurve = .continuous
        scrollView.clipsToBounds = true
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)

        cropGuide.translatesAutoresizingMaskIntoConstraints = false
        cropGuide.isUserInteractionEnabled = false
        cropGuide.layer.borderWidth = 2
        cropGuide.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        cropGuide.layer.cornerRadius = 18
        cropGuide.layer.cornerCurve = .continuous
        view.addSubview(cropGuide)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            cancelButton.trailingAnchor.constraint(equalTo: useButton.leadingAnchor, constant: -12),
            cancelButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            useButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            useButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            useButton.widthAnchor.constraint(equalToConstant: 72),
            useButton.heightAnchor.constraint(equalToConstant: 36),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 22),
            scrollView.heightAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: 0.72),
            cropGuide.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            cropGuide.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            cropGuide.topAnchor.constraint(equalTo: scrollView.topAnchor),
            cropGuide.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func useImage() {
        let renderer = UIGraphicsImageRenderer(size: scrollView.bounds.size)
        let rendered = renderer.image { context in
            scrollView.drawHierarchy(in: scrollView.bounds, afterScreenUpdates: true)
        }
        dismiss(animated: true) {
            self.completion(rendered)
        }
    }
}

private final class NativeStoriesHeaderView: UIView {
    private let titleLabel = UILabel()
    private let discoverButton = UIButton(type: .system)
    private let storiesScrollView = UIScrollView()
    private let stackView = UIStackView()
    var onAddStory: (() -> Void)?
    var onOpenStory: ((NativeFeedStory) -> Void)?
    var onDiscover: (() -> Void)?
    var preferredHeight: CGFloat {
        120
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Stories"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        addSubview(titleLabel)

        discoverButton.translatesAutoresizingMaskIntoConstraints = false
        discoverButton.setTitle("Discover", for: .normal)
        discoverButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        discoverButton.setTitleColor(UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.84), for: .normal)
        discoverButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        discoverButton.addTarget(self, action: #selector(handleDiscoverTap), for: .touchUpInside)
        addSubview(discoverButton)

        storiesScrollView.translatesAutoresizingMaskIntoConstraints = false
        storiesScrollView.showsHorizontalScrollIndicator = false
        storiesScrollView.alwaysBounceHorizontal = true
        storiesScrollView.delaysContentTouches = false
        addSubview(storiesScrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 12
        storiesScrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            discoverButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            discoverButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            storiesScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            storiesScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            storiesScrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            storiesScrollView.heightAnchor.constraint(equalToConstant: 78),
            stackView.leadingAnchor.constraint(equalTo: storiesScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: storiesScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: storiesScrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: storiesScrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: storiesScrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(stories: [NativeFeedStory], currentUser: NativeUserSummary?, hasCurrentUserStory: Bool, imageCache: NSCache<NSString, UIImage>) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if let currentUser {
            let addChip = NativeStoryChipView()
            addChip.configure(user: currentUser, title: "Your Story", active: hasCurrentUserStory, showsAddBadge: true, imageCache: imageCache)
            addChip.addTarget(self, action: #selector(handleAddStoryTap), for: .touchUpInside)
            stackView.addArrangedSubview(addChip)
        }

        stories.forEach { story in
            let chip = NativeStoryChipView()
            chip.configure(user: story.author, title: "@\(story.author.username)", active: true, showsAddBadge: false, imageCache: imageCache)
            chip.story = story
            chip.addTarget(self, action: #selector(handleStoryTap(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(chip)
        }

    }

    @objc private func handleAddStoryTap() {
        onAddStory?()
    }

    @objc private func handleStoryTap(_ sender: NativeStoryChipView) {
        guard let story = sender.story else { return }
        onOpenStory?(story)
    }

    @objc private func handleDiscoverTap() {
        onDiscover?()
    }
}

private final class NativeStoryChipView: UIControl {
    private let avatarView = NativeAvatarView()
    private let titleLabel = UILabel()
    private let addBadge = UILabel()
    var story: NativeFeedStory?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isExclusiveTouch = true
        accessibilityTraits = [.button]

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.isUserInteractionEnabled = false
        addSubview(avatarView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.96)
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)

        addBadge.translatesAutoresizingMaskIntoConstraints = false
        addBadge.text = "+"
        addBadge.textColor = .white
        addBadge.font = .systemFont(ofSize: 16, weight: .bold)
        addBadge.textAlignment = .center
        addBadge.backgroundColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1)
        addBadge.layer.cornerRadius = 12
        addBadge.layer.cornerCurve = .continuous
        addBadge.clipsToBounds = true
        addSubview(addBadge)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 84),
            heightAnchor.constraint(equalToConstant: 78),
            avatarView.topAnchor.constraint(equalTo: topAnchor),
            avatarView.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 54),
            avatarView.heightAnchor.constraint(equalToConstant: 54),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 6),
            addBadge.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 2),
            addBadge.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 2),
            addBadge.widthAnchor.constraint(equalToConstant: 24),
            addBadge.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(user: NativeUserSummary, title: String, active: Bool, showsAddBadge: Bool, imageCache: NSCache<NSString, UIImage>) {
        avatarView.configure(with: user, imageCache: imageCache)
        avatarView.layer.cornerRadius = 27
        avatarView.layer.cornerCurve = .continuous
        avatarView.layer.borderWidth = active ? 2 : 0
        avatarView.layer.borderColor = UIColor(red: 191.0 / 255.0, green: 10.0 / 255.0, blue: 48.0 / 255.0, alpha: 0.84).cgColor
        titleLabel.text = title
        addBadge.isHidden = !showsAddBadge
    }
}

private final class NativeMentionSuggestionButton: UIControl {
    let user: NativeMentionUser
    private let avatarView = NativeAvatarView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()

    init(user: NativeMentionUser, imageCache: NSCache<NSString, UIImage>) {
        self.user = user
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        backgroundColor = .white.withAlphaComponent(0.85)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.isUserInteractionEnabled = false
        avatarView.configure(with: user.summary, imageCache: imageCache)
        addSubview(avatarView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = user.display_name
        nameLabel.font = .systemFont(ofSize: 14, weight: .bold)
        nameLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        addSubview(nameLabel)

        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.text = "@\(user.username)"
        usernameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        usernameLabel.textColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.86)
        addSubview(usernameLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),
            avatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            avatarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 34),
            avatarView.heightAnchor.constraint(equalToConstant: 34),
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            usernameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            usernameLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class NativeFeedMediaView: UIView {
    private let imageView = UIImageView()
    private let videoBadge = UILabel()
    private var currentURL = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 241.0 / 255.0, green: 245.0 / 255.0, blue: 252.0 / 255.0, alpha: 1)
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)

        videoBadge.translatesAutoresizingMaskIntoConstraints = false
        videoBadge.text = "Video"
        videoBadge.textColor = .white
        videoBadge.font = .systemFont(ofSize: 13, weight: .bold)
        videoBadge.textAlignment = .center
        videoBadge.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        videoBadge.layer.cornerRadius = 12
        videoBadge.layer.cornerCurve = .continuous
        videoBadge.clipsToBounds = true
        videoBadge.isHidden = true
        addSubview(videoBadge)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            videoBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            videoBadge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            videoBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 58),
            videoBadge.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(urlString: String, mediaType: String, cache: NSCache<NSString, UIImage>) {
        currentURL = urlString
        videoBadge.isHidden = mediaType != "video"
        imageView.image = nil
        isHidden = urlString.isEmpty
        guard !urlString.isEmpty else { return }
        let key = NSString(string: urlString)
        if let cached = cache.object(forKey: key) {
            imageView.image = cached
            return
        }
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            cache.setObject(image, forKey: key)
            DispatchQueue.main.async {
                guard self.currentURL == urlString else { return }
                self.imageView.image = image
            }
        }.resume()
    }
}

private enum NativeFeedPostAction: Int {
    case like = 0
    case repost = 1
    case comment = 2
    case bookmark = 3
}

private final class NativeFeedPollCell: UITableViewCell {
    static let reuseIdentifier = "NativeFeedPollCell"

    private let cardView = UIView()
    private let eyebrowLabel = UILabel()
    private let questionLabel = UILabel()
    private let optionsStack = UIStackView()
    private let footerLabel = UILabel()
    private var currentPoll: NativeFeedPoll?
    var onVote: ((NativeFeedPoll, NativeFeedPollOption) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        cardView.layer.cornerRadius = 22
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.08).cgColor
        contentView.addSubview(cardView)

        eyebrowLabel.translatesAutoresizingMaskIntoConstraints = false
        eyebrowLabel.text = "Poll"
        eyebrowLabel.font = .systemFont(ofSize: 13, weight: .bold)
        eyebrowLabel.textColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.78)
        cardView.addSubview(eyebrowLabel)

        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        questionLabel.font = .systemFont(ofSize: 18, weight: .bold)
        questionLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        questionLabel.numberOfLines = 0
        cardView.addSubview(questionLabel)

        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.axis = .vertical
        optionsStack.spacing = 8
        cardView.addSubview(optionsStack)

        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        footerLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.78)
        footerLabel.numberOfLines = 0
        cardView.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            eyebrowLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            eyebrowLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            eyebrowLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),

            questionLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            questionLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            questionLabel.topAnchor.constraint(equalTo: eyebrowLabel.bottomAnchor, constant: 6),

            optionsStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            optionsStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            optionsStack.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 14),

            footerLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            footerLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            footerLabel.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: 12),
            footerLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentPoll = nil
        onVote = nil
        optionsStack.arrangedSubviews.forEach { view in
            optionsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    func configure(with poll: NativeFeedPoll) {
        currentPoll = poll
        questionLabel.text = poll.question
        let totalVotes = poll.options.reduce(0) { $0 + $1.votes }
        footerLabel.text = poll.results_visible ? "\(totalVotes) votes" : "Results hidden until you vote"

        poll.options.enumerated().forEach { index, option in
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tag = index
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            button.titleLabel?.numberOfLines = 0
            button.setTitle(optionTitle(option, totalVotes: totalVotes, poll: poll), for: .normal)
            button.setTitleColor(UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1), for: .normal)
            button.backgroundColor = option.id == poll.selected_option_id
                ? UIColor(red: 219.0 / 255.0, green: 235.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
                : UIColor(red: 245.0 / 255.0, green: 248.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.95)
            button.layer.cornerRadius = 15
            button.layer.cornerCurve = .continuous
            button.layer.borderWidth = 1
            button.layer.borderColor = option.id == poll.selected_option_id
                ? UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.25).cgColor
                : UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.08).cgColor
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
            button.addTarget(self, action: #selector(handleOptionTap(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 46).isActive = true
            optionsStack.addArrangedSubview(button)
        }
    }

    private func optionTitle(_ option: NativeFeedPollOption, totalVotes: Int, poll: NativeFeedPoll) -> String {
        guard poll.results_visible else { return option.label }
        let percentage = totalVotes > 0 ? Int(round((Double(option.votes) / Double(totalVotes)) * 100)) : 0
        return "\(option.label)  \(percentage)%"
    }

    @objc private func handleOptionTap(_ sender: UIButton) {
        guard let poll = currentPoll, sender.tag >= 0, sender.tag < poll.options.count else { return }
        onVote?(poll, poll.options[sender.tag])
    }
}

private final class NativeFeedPostCell: UITableViewCell {
    static let reuseIdentifier = "NativeFeedPostCell"

    private let cardView = UIView()
    private let repostLabel = UILabel()
    private let avatarView = NativeAvatarView()
    private let nameLabel = UILabel()
    private let verifiedBadgeView = UIImageView()
    private let usernameLabel = UILabel()
    private let timeLabel = UILabel()
    private let breakingLabel = UILabel()
    private let bodyLabel = UILabel()
    private let mediaView = NativeFeedMediaView()
    private let quoteView = UIView()
    private let quoteLabel = UILabel()
    private let quoteBodyLabel = UILabel()
    private let quoteMediaView = NativeFeedMediaView()
    private let statsLabel = UILabel()
    private let actionStack = UIStackView()
    private var mediaHeightConstraint: NSLayoutConstraint!
    private var quoteMediaHeightConstraint: NSLayoutConstraint!
    private var bodyTopToAvatarConstraint: NSLayoutConstraint!
    private var bodyTopToBreakingConstraint: NSLayoutConstraint!
    private var currentPost: NativeFeedPost?
    var onAction: ((NativeFeedPost, NativeFeedPostAction) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.isUserInteractionEnabled = true
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        cardView.layer.cornerRadius = 22
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.08).cgColor
        contentView.addSubview(cardView)

        repostLabel.translatesAutoresizingMaskIntoConstraints = false
        repostLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        repostLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.8)
        repostLabel.isHidden = true
        cardView.addSubview(repostLabel)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(avatarView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 17, weight: .bold)
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

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        timeLabel.textColor = UIColor(red: 107.0 / 255.0, green: 119.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.86)
        timeLabel.textAlignment = .right
        cardView.addSubview(timeLabel)

        breakingLabel.translatesAutoresizingMaskIntoConstraints = false
        breakingLabel.text = "Breaking"
        breakingLabel.font = .systemFont(ofSize: 12, weight: .bold)
        breakingLabel.textColor = UIColor(red: 191.0 / 255.0, green: 10.0 / 255.0, blue: 48.0 / 255.0, alpha: 1)
        breakingLabel.backgroundColor = UIColor(red: 255.0 / 255.0, green: 235.0 / 255.0, blue: 240.0 / 255.0, alpha: 1)
        breakingLabel.textAlignment = .center
        breakingLabel.layer.cornerRadius = 10
        breakingLabel.layer.cornerCurve = .continuous
        breakingLabel.clipsToBounds = true
        breakingLabel.isHidden = true
        cardView.addSubview(breakingLabel)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 17, weight: .regular)
        bodyLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        bodyLabel.numberOfLines = 0
        cardView.addSubview(bodyLabel)

        cardView.addSubview(mediaView)

        quoteView.translatesAutoresizingMaskIntoConstraints = false
        quoteView.backgroundColor = UIColor(red: 247.0 / 255.0, green: 250.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
        quoteView.layer.cornerRadius = 16
        quoteView.layer.cornerCurve = .continuous
        quoteView.layer.borderWidth = 1
        quoteView.layer.borderColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.08).cgColor
        quoteView.isHidden = true
        cardView.addSubview(quoteView)

        quoteLabel.translatesAutoresizingMaskIntoConstraints = false
        quoteLabel.font = .systemFont(ofSize: 13, weight: .bold)
        quoteLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.92)
        quoteView.addSubview(quoteLabel)

        quoteBodyLabel.translatesAutoresizingMaskIntoConstraints = false
        quoteBodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        quoteBodyLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.94)
        quoteBodyLabel.numberOfLines = 3
        quoteView.addSubview(quoteBodyLabel)
        quoteView.addSubview(quoteMediaView)

        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statsLabel.textColor = UIColor(red: 107.0 / 255.0, green: 119.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.88)
        cardView.addSubview(statsLabel)

        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .horizontal
        actionStack.distribution = .fillEqually
        actionStack.spacing = 8
        ["heart", "arrow.2.squarepath", "bubble.left", "bookmark"].enumerated().forEach { index, symbol in
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: symbol), for: .normal)
            button.tintColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.86)
            button.tag = index
            button.addTarget(self, action: #selector(handleActionTap(_:)), for: .touchUpInside)
            button.imageView?.contentMode = .scaleAspectFit
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            button.backgroundColor = UIColor(red: 245.0 / 255.0, green: 248.0 / 255.0, blue: 255.0 / 255.0, alpha: 0.72)
            button.layer.cornerRadius = 20
            button.layer.cornerCurve = .continuous
            button.accessibilityLabel = ["Like", "Repost", "Comment", "Save"][index]
            actionStack.addArrangedSubview(button)
        }
        cardView.addSubview(actionStack)

        mediaHeightConstraint = mediaView.heightAnchor.constraint(equalToConstant: 220)
        quoteMediaHeightConstraint = quoteMediaView.heightAnchor.constraint(equalToConstant: 116)
        bodyTopToAvatarConstraint = bodyLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 14)
        bodyTopToBreakingConstraint = bodyLabel.topAnchor.constraint(equalTo: breakingLabel.bottomAnchor, constant: 8)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),

            repostLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            repostLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            repostLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),

            avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            avatarView.topAnchor.constraint(equalTo: repostLabel.bottomAnchor, constant: 10),
            avatarView.widthAnchor.constraint(equalToConstant: 48),
            avatarView.heightAnchor.constraint(equalToConstant: 48),

            timeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            timeLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 2),
            timeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 92),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 1),
            verifiedBadgeView.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 5),
            verifiedBadgeView.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            verifiedBadgeView.widthAnchor.constraint(equalToConstant: 17),
            verifiedBadgeView.heightAnchor.constraint(equalToConstant: 17),
            verifiedBadgeView.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            usernameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            usernameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            breakingLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            breakingLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 7),
            breakingLabel.widthAnchor.constraint(equalToConstant: 76),
            breakingLabel.heightAnchor.constraint(equalToConstant: 22),

            bodyLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            bodyLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            bodyTopToAvatarConstraint,

            mediaView.leadingAnchor.constraint(equalTo: bodyLabel.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: bodyLabel.trailingAnchor),
            mediaView.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
            mediaHeightConstraint,

            quoteView.leadingAnchor.constraint(equalTo: bodyLabel.leadingAnchor),
            quoteView.trailingAnchor.constraint(equalTo: bodyLabel.trailingAnchor),
            quoteView.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 12),

            quoteLabel.leadingAnchor.constraint(equalTo: quoteView.leadingAnchor, constant: 14),
            quoteLabel.trailingAnchor.constraint(equalTo: quoteView.trailingAnchor, constant: -14),
            quoteLabel.topAnchor.constraint(equalTo: quoteView.topAnchor, constant: 12),
            quoteBodyLabel.leadingAnchor.constraint(equalTo: quoteLabel.leadingAnchor),
            quoteBodyLabel.trailingAnchor.constraint(equalTo: quoteLabel.trailingAnchor),
            quoteBodyLabel.topAnchor.constraint(equalTo: quoteLabel.bottomAnchor, constant: 6),
            quoteMediaView.leadingAnchor.constraint(equalTo: quoteLabel.leadingAnchor),
            quoteMediaView.trailingAnchor.constraint(equalTo: quoteLabel.trailingAnchor),
            quoteMediaView.topAnchor.constraint(equalTo: quoteBodyLabel.bottomAnchor, constant: 10),
            quoteMediaHeightConstraint,
            quoteMediaView.bottomAnchor.constraint(equalTo: quoteView.bottomAnchor, constant: -12),

            statsLabel.leadingAnchor.constraint(equalTo: bodyLabel.leadingAnchor),
            statsLabel.trailingAnchor.constraint(equalTo: bodyLabel.trailingAnchor),
            statsLabel.topAnchor.constraint(equalTo: quoteView.bottomAnchor, constant: 12),

            actionStack.leadingAnchor.constraint(equalTo: bodyLabel.leadingAnchor),
            actionStack.trailingAnchor.constraint(equalTo: bodyLabel.trailingAnchor),
            actionStack.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 12),
            actionStack.heightAnchor.constraint(equalToConstant: 44),
            actionStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        repostLabel.isHidden = true
        breakingLabel.isHidden = true
        quoteView.isHidden = true
        mediaView.isHidden = true
        quoteMediaView.isHidden = true
        currentPost = nil
    }

    func configure(with post: NativeFeedPost, avatarCache: NSCache<NSString, UIImage>, mediaCache: NSCache<NSString, UIImage>) {
        currentPost = post
        repostLabel.text = post.reposted_by.map { "@\($0.username) reposted this" }
        repostLabel.isHidden = post.reposted_by == nil
        avatarView.configure(with: post.author, imageCache: avatarCache)
        nameLabel.text = post.author.display_name
        verifiedBadgeView.isHidden = !post.author.is_verified
        usernameLabel.text = "@\(post.author.username)"
        timeLabel.text = post.created_at_relative
        breakingLabel.isHidden = !post.is_breaking
        bodyTopToAvatarConstraint.isActive = !post.is_breaking
        bodyTopToBreakingConstraint.isActive = post.is_breaking
        bodyLabel.text = post.body.isEmpty ? "Media post" : post.body
        mediaHeightConstraint.constant = post.media_url.isEmpty ? 0 : 220
        mediaView.configure(urlString: post.media_url, mediaType: post.media_type, cache: mediaCache)

        if let quote = post.quote {
            quoteView.isHidden = false
            quoteView.layer.borderWidth = 1
            quoteView.backgroundColor = UIColor(red: 247.0 / 255.0, green: 250.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
            quoteLabel.text = quote.author.map { "Quoted @\($0.username)" } ?? "Quoted post"
            quoteBodyLabel.text = quote.body.isEmpty ? "Media post" : quote.body
            quoteMediaHeightConstraint.constant = quote.media_url.isEmpty ? 0 : 116
            quoteMediaView.configure(urlString: quote.media_url, mediaType: quote.media_type, cache: mediaCache)
        } else {
            quoteView.isHidden = false
            quoteView.layer.borderWidth = 0
            quoteView.backgroundColor = .clear
            quoteLabel.text = ""
            quoteBodyLabel.text = ""
            quoteMediaHeightConstraint.constant = 0
            quoteMediaView.configure(urlString: "", mediaType: "", cache: mediaCache)
        }

        statsLabel.text = "\(post.view_count) views  \(post.like_count) likes  \(post.comment_count) comments  \(post.repost_count) reposts  \(post.bookmark_count) saves"
        if actionStack.arrangedSubviews.count == 4 {
            let disabledColor = UIColor(red: 145.0 / 255.0, green: 155.0 / 255.0, blue: 178.0 / 255.0, alpha: 0.38)
            let defaultColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.86)
            actionStack.arrangedSubviews[0].tintColor = post.is_mine ? disabledColor : (post.has_liked ? UIColor(red: 191.0 / 255.0, green: 10.0 / 255.0, blue: 48.0 / 255.0, alpha: 1) : defaultColor)
            actionStack.arrangedSubviews[1].tintColor = post.is_mine ? disabledColor : (post.has_reposted ? UIColor(red: 11.0 / 255.0, green: 145.0 / 255.0, blue: 92.0 / 255.0, alpha: 1) : defaultColor)
            actionStack.arrangedSubviews[3].tintColor = post.has_bookmarked ? UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 1) : UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.86)
            actionStack.arrangedSubviews[0].alpha = post.is_mine ? 0.55 : 1
            actionStack.arrangedSubviews[1].alpha = post.is_mine ? 0.55 : 1
        }
    }

    @objc private func handleActionTap(_ sender: UIButton) {
        guard let currentPost, let action = NativeFeedPostAction(rawValue: sender.tag) else { return }
        UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            sender.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        } completion: { _ in
            UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.6, options: [.beginFromCurrentState]) {
                sender.transform = .identity
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onAction?(currentPost, action)
    }
}

private final class NativeCommentCell: UITableViewCell {
    static let reuseIdentifier = "NativeCommentCell"

    private let threadLine = UIView()
    private let avatarView = NativeAvatarView()
    private let bubbleView = UIView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let bodyLabel = UILabel()
    private let likesLabel = UILabel()
    private let likeButton = UIButton(type: .system)
    private let replyButton = UIButton(type: .system)
    private var leadingConstraint: NSLayoutConstraint!
    private var currentComment: NativeComment?
    var onLike: ((NativeComment) -> Void)?
    var onReply: ((NativeComment) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        threadLine.translatesAutoresizingMaskIntoConstraints = false
        threadLine.backgroundColor = UIColor(red: 190.0 / 255.0, green: 202.0 / 255.0, blue: 224.0 / 255.0, alpha: 0.8)
        threadLine.layer.cornerRadius = 1
        contentView.addSubview(threadLine)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatarView)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.backgroundColor = .clear
        contentView.addSubview(bubbleView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 14, weight: .bold)
        nameLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        bubbleView.addSubview(nameLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 12, weight: .medium)
        metaLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.72)
        bubbleView.addSubview(metaLabel)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 15)
        bodyLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.96)
        bodyLabel.numberOfLines = 0
        bubbleView.addSubview(bodyLabel)

        likesLabel.translatesAutoresizingMaskIntoConstraints = false
        likesLabel.font = .systemFont(ofSize: 12, weight: .bold)
        likesLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.72)
        bubbleView.addSubview(likesLabel)

        likeButton.translatesAutoresizingMaskIntoConstraints = false
        likeButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        likeButton.setTitle("Like", for: .normal)
        likeButton.addTarget(self, action: #selector(handleLikeTap), for: .touchUpInside)
        bubbleView.addSubview(likeButton)

        replyButton.translatesAutoresizingMaskIntoConstraints = false
        replyButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        replyButton.setTitle("Reply", for: .normal)
        replyButton.setTitleColor(UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.9), for: .normal)
        replyButton.addTarget(self, action: #selector(handleReplyTap), for: .touchUpInside)
        bubbleView.addSubview(replyButton)

        leadingConstraint = avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18)
        NSLayoutConstraint.activate([
            leadingConstraint,
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            avatarView.widthAnchor.constraint(equalToConstant: 36),
            avatarView.heightAnchor.constraint(equalToConstant: 36),
            threadLine.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            threadLine.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 5),
            threadLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            threadLine.widthAnchor.constraint(equalToConstant: 2),

            bubbleView.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            nameLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            nameLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor),

            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
            metaLabel.trailingAnchor.constraint(lessThanOrEqualTo: bubbleView.trailingAnchor),
            metaLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),

            bodyLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),

            likesLabel.leadingAnchor.constraint(equalTo: bodyLabel.leadingAnchor),
            likesLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 6),
            likesLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),

            likeButton.leadingAnchor.constraint(equalTo: likesLabel.trailingAnchor, constant: 12),
            likeButton.centerYAnchor.constraint(equalTo: likesLabel.centerYAnchor),
            replyButton.leadingAnchor.constraint(equalTo: likeButton.trailingAnchor, constant: 10),
            replyButton.trailingAnchor.constraint(lessThanOrEqualTo: bubbleView.trailingAnchor),
            replyButton.centerYAnchor.constraint(equalTo: likesLabel.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with comment: NativeComment, imageCache: NSCache<NSString, UIImage>) {
        currentComment = comment
        avatarView.configure(with: comment.author, imageCache: imageCache)
        nameLabel.text = comment.author.display_name
        metaLabel.text = comment.created_at_relative
        bodyLabel.text = comment.body
        let likeText = comment.like_count == 1 ? "1 like" : "\(comment.like_count) likes"
        likesLabel.text = likeText
        likeButton.setTitle(comment.has_liked ? "Liked" : "Like", for: .normal)
        likeButton.setTitleColor(comment.has_liked ? UIColor(red: 191.0 / 255.0, green: 10.0 / 255.0, blue: 48.0 / 255.0, alpha: 1) : UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.9), for: .normal)
        leadingConstraint.constant = 18 + CGFloat(min(comment.depth, 2) * 18)
        threadLine.isHidden = comment.depth > 1
    }

    @objc private func handleLikeTap() {
        guard let currentComment else { return }
        onLike?(currentComment)
    }

    @objc private func handleReplyTap() {
        guard let currentComment else { return }
        onReply?(currentComment)
    }
}

private final class NativeConnectionCell: UITableViewCell {
    static let reuseIdentifier = "NativeConnectionCell"

    private let cardView = UIView()
    private let avatarView = NativeAvatarView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let bioLabel = UILabel()
    private let chevronView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.86)
        cardView.layer.cornerRadius = 20
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor(red: 218.0 / 255.0, green: 226.0 / 255.0, blue: 240.0 / 255.0, alpha: 0.74).cgColor
        contentView.addSubview(cardView)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(avatarView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
        cardView.addSubview(nameLabel)

        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        usernameLabel.textColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.82)
        cardView.addSubview(usernameLabel)

        bioLabel.translatesAutoresizingMaskIntoConstraints = false
        bioLabel.font = .systemFont(ofSize: 13)
        bioLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 0.82)
        bioLabel.numberOfLines = 2
        cardView.addSubview(bioLabel)

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.image = UIImage(systemName: "chevron.right")
        chevronView.tintColor = UIColor(red: 88.0 / 255.0, green: 99.0 / 255.0, blue: 126.0 / 255.0, alpha: 0.45)
        cardView.addSubview(chevronView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            avatarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            avatarView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            avatarView.widthAnchor.constraint(equalToConstant: 48),
            avatarView.heightAnchor.constraint(equalToConstant: 48),
            chevronView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevronView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 14),
            chevronView.heightAnchor.constraint(equalToConstant: 18),
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -10),
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 13),
            usernameLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            usernameLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            bioLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            bioLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            bioLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 5),
            bioLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(user: NativeProfileUser, imageCache: NSCache<NSString, UIImage>) {
        avatarView.configure(with: user.summary, imageCache: imageCache)
        nameLabel.text = user.display_name
        usernameLabel.text = "@\(user.username)"
        bioLabel.text = user.bio.isEmpty ? "\(user.follower_count) followers" : user.bio
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

private final class NativeThreadMessageBubbleView: UIView {
    private let avatarView = NativeAvatarView()
    private let bubbleView = UIView()
    private let bodyLabel = UILabel()
    private let metaLabel = UILabel()
    private var avatarLeadingConstraint: NSLayoutConstraint!
    private var bubbleLeadingToAvatarConstraint: NSLayoutConstraint!
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    private var bubbleTrailingToContentConstraint: NSLayoutConstraint!
    private var metaLeadingConstraint: NSLayoutConstraint!
    private var metaTrailingConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(avatarView)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 20
        bubbleView.layer.cornerCurve = .continuous
        addSubview(bubbleView)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 17, weight: .medium)
        bodyLabel.numberOfLines = 0
        bubbleView.addSubview(bodyLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        metaLabel.textColor = UIColor(red: 107.0 / 255.0, green: 119.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.84)
        addSubview(metaLabel)

        avatarLeadingConstraint = avatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        bubbleLeadingToAvatarConstraint = bubbleView.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10)
        bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 72)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -58)
        bubbleTrailingToContentConstraint = bubbleView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        metaLeadingConstraint = metaLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 6)
        metaTrailingConstraint = metaLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -6)

        NSLayoutConstraint.activate([
            avatarLeadingConstraint,
            avatarView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            avatarView.widthAnchor.constraint(equalToConstant: 36),
            avatarView.heightAnchor.constraint(equalToConstant: 36),

            bubbleView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            bubbleLeadingToAvatarConstraint,
            bubbleTrailingConstraint,

            bodyLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
            bodyLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            bodyLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),

            metaLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 6),
            metaLeadingConstraint,
            metaTrailingConstraint,
            metaLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with message: NativeThreadMessage, imageCache: NSCache<NSString, UIImage>) {
        avatarView.configure(with: message.sender, imageCache: imageCache)
        bodyLabel.text = message.body
        metaLabel.text = message.created_at_relative.isEmpty ? "now" : message.created_at_relative

        if message.is_mine {
            avatarView.isHidden = true
            avatarLeadingConstraint.isActive = false
            bubbleLeadingToAvatarConstraint.isActive = false
            bubbleTrailingConstraint.isActive = false
            bubbleLeadingConstraint.isActive = true
            bubbleTrailingToContentConstraint.isActive = true
            metaLeadingConstraint.isActive = false
            metaTrailingConstraint.isActive = true
            bubbleView.backgroundColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.95)
            bodyLabel.textColor = .white
            metaLabel.textAlignment = .right
        } else {
            avatarView.isHidden = false
            avatarLeadingConstraint.isActive = true
            bubbleLeadingConstraint.isActive = false
            bubbleTrailingToContentConstraint.isActive = false
            bubbleLeadingToAvatarConstraint.isActive = true
            bubbleTrailingConstraint.isActive = true
            metaTrailingConstraint.isActive = false
            metaLeadingConstraint.isActive = true
            bubbleView.backgroundColor = UIColor(red: 241.0 / 255.0, green: 245.0 / 255.0, blue: 252.0 / 255.0, alpha: 1)
            bodyLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
            metaLabel.textAlignment = .left
        }
    }
}

private final class NativeThreadMessageCell: UITableViewCell {
    static let reuseIdentifier = "NativeThreadMessageCell"

    private let avatarView = NativeAvatarView()
    private let bubbleView = UIView()
    private let bodyLabel = UILabel()
    private let metaLabel = UILabel()
    private var avatarLeadingConstraint: NSLayoutConstraint!
    private var bubbleLeadingToAvatarConstraint: NSLayoutConstraint!
    private var bubbleLeadingConstraint: NSLayoutConstraint!
    private var bubbleTrailingConstraint: NSLayoutConstraint!
    private var bubbleTrailingToContentConstraint: NSLayoutConstraint!
    private var metaLeadingConstraint: NSLayoutConstraint!
    private var metaTrailingConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatarView)

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 20
        bubbleView.layer.cornerCurve = .continuous
        contentView.addSubview(bubbleView)

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 17, weight: .medium)
        bodyLabel.numberOfLines = 0
        bubbleView.addSubview(bodyLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        metaLabel.textColor = UIColor(red: 107.0 / 255.0, green: 119.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.84)
        contentView.addSubview(metaLabel)

        avatarLeadingConstraint = avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8)
        bubbleLeadingToAvatarConstraint = bubbleView.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10)
        bubbleLeadingConstraint = bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 72)
        bubbleTrailingConstraint = bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -58)
        bubbleTrailingToContentConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        metaLeadingConstraint = metaLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 6)
        metaTrailingConstraint = metaLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -6)

        NSLayoutConstraint.activate([
            avatarLeadingConstraint,
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),

            avatarView.widthAnchor.constraint(equalToConstant: 36),
            avatarView.heightAnchor.constraint(equalToConstant: 36),

            bodyLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
            bodyLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            bodyLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),

            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            bubbleLeadingToAvatarConstraint,
            bubbleTrailingConstraint,

            metaLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 6),
            metaLeadingConstraint,
            metaTrailingConstraint,
            metaLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with message: NativeThreadMessage, imageCache: NSCache<NSString, UIImage>) {
        avatarView.configure(with: message.sender, imageCache: imageCache)
        bodyLabel.text = message.body
        metaLabel.text = message.created_at_relative.isEmpty ? "now" : message.created_at_relative
        if message.is_mine {
            avatarView.isHidden = true
            avatarLeadingConstraint.isActive = false
            bubbleLeadingToAvatarConstraint.isActive = false
            bubbleTrailingConstraint.isActive = false
            bubbleLeadingConstraint.isActive = true
            bubbleTrailingToContentConstraint.isActive = true
            metaLeadingConstraint.isActive = false
            metaTrailingConstraint.isActive = true
            bubbleView.backgroundColor = UIColor(red: 11.0 / 255.0, green: 61.0 / 255.0, blue: 145.0 / 255.0, alpha: 0.95)
            bodyLabel.textColor = .white
            metaLabel.textAlignment = .right
        } else {
            avatarView.isHidden = false
            avatarLeadingConstraint.isActive = true
            bubbleLeadingConstraint.isActive = false
            bubbleTrailingToContentConstraint.isActive = false
            bubbleLeadingToAvatarConstraint.isActive = true
            bubbleTrailingConstraint.isActive = true
            metaTrailingConstraint.isActive = false
            metaLeadingConstraint.isActive = true
            bubbleView.backgroundColor = UIColor(red: 241.0 / 255.0, green: 245.0 / 255.0, blue: 252.0 / 255.0, alpha: 1)
            bodyLabel.textColor = UIColor(red: 20.0 / 255.0, green: 33.0 / 255.0, blue: 61.0 / 255.0, alpha: 1)
            metaLabel.textAlignment = .left
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
