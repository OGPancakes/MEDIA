import UIKit
import WebKit
import Capacitor
import ObjectiveC.runtime
import PhotosUI
import UserNotifications

final class AppViewController: CAPBridgeViewController, WKScriptMessageHandler, UITextViewDelegate, PHPickerViewControllerDelegate {
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
    private let nativeTabStack = UIStackView()
    private let messagesTabButton = UIButton(type: .system)
    private let feedTabButton = UIButton(type: .system)
    private let searchTabButton = UIButton(type: .system)
    private let profileTabButton = UIButton(type: .system)

    private var composerSheetBottomConstraint: NSLayoutConstraint?
    private var composeButtonBottomConstraint: NSLayoutConstraint?
    private var composerTextViewHeightConstraint: NSLayoutConstraint?
    private var composerPreviewHeightConstraint: NSLayoutConstraint?
    private var keyboardObserversInstalled = false
    private var nativeComposerAvailable = false
    private var isPostingComposer = false
    private var isLoggedIntoWebApp = false
    private var lastRegisteredPushToken: String?
    private var stateSyncTimer: Timer?
    private var selectedImageData: Data?
    private var selectedImageName: String?
    private var selectedImageMimeType = "image/jpeg"
    private var currentFeedTab = "home"
    private var currentUsername = ""
    private var currentPrimarySection: PrimarySection = .feed
    private var warmedRoutesForUsername: String?
    private var lastRouteBySection: [PrimarySection: String] = [
        .messages: "/messages",
        .feed: "/",
        .search: "/search"
    ]

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
        nativeTabBar.translatesAutoresizingMaskIntoConstraints = false
        nativeTabBar.layer.cornerRadius = 26
        nativeTabBar.layer.cornerCurve = .continuous
        nativeTabBar.clipsToBounds = true
        nativeTabBar.contentView.backgroundColor = UIColor.white.withAlphaComponent(0.9)
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

        NSLayoutConstraint.activate([
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
        }
        let completion: (Bool) -> Void = { _ in
            if !visible {
                self.nativeTabBar.isHidden = true
            }
        }
        if animated {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut], animations: changes, completion: completion)
        } else {
            changes()
            completion(true)
        }
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
                if let section = PrimarySection(rawValue: payload["primarySection"] as? String ?? "feed") {
                    self.currentPrimarySection = section
                } else {
                    self.currentPrimarySection = .feed
                }
                self.currentUsername = username
                if let route = payload["currentRoute"] as? String, !route.isEmpty {
                    self.lastRouteBySection[self.currentPrimarySection] = route
                }
                if !username.isEmpty {
                    self.lastRouteBySection[.profile] = "/users/\(username)"
                }
                self.handleLoginState(loggedIn: loggedIn, username: username)
                self.setComposeButtonVisible(loggedIn && isFeed && canCompose, animated: true)
                self.updateNativeTabSelection(animated: true)
                self.prefetchPrimaryRoutesIfNeeded(username: username)
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
            lastRouteBySection = [
                .messages: "/messages",
                .feed: "/",
                .search: "/search"
            ]
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
        fetchCookieHeader { [weak self] cookieHeader in
            guard let self else { return }
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
        guard !composerSheet.isHidden,
              let frameValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardFrame = view.convert(frameValue.cgRectValue, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardFrame.minY)
        composerSheetBottomConstraint?.constant = max(0, -view.safeAreaInsets.bottom) - overlap + view.safeAreaInsets.bottom
        animateWithKeyboard(note)
    }

    @objc private func handleKeyboardWillHide(_ note: Notification) {
        guard !composerSheet.isHidden else { return }
        composerSheetBottomConstraint?.constant = 0
        animateWithKeyboard(note)
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
        if let section = PrimarySection(rawValue: payload["primarySection"] as? String ?? "feed") {
            currentPrimarySection = section
        } else {
            currentPrimarySection = .feed
        }
        currentUsername = username
        if let route = payload["currentRoute"] as? String, !route.isEmpty {
            lastRouteBySection[currentPrimarySection] = route
        }
        if !username.isEmpty {
            lastRouteBySection[.profile] = "/users/\(username)"
        }
        DispatchQueue.main.async {
            self.handleLoginState(loggedIn: loggedIn, username: username)
            self.setComposeButtonVisible(loggedIn && isFeed && canCompose, animated: true)
            self.updateNativeTabSelection(animated: true)
            self.prefetchPrimaryRoutesIfNeeded(username: username)
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
        let script = "window.nativeOpenPrimaryRoute && window.nativeOpenPrimaryRoute(\"\(section.rawValue)\", \"\(escapedUsername)\", \"\(escapedRoute)\", true);"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func textViewDidChange(_ textView: UITextView) {
        composerPlaceholder.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let targetHeight = min(max(textView.contentSize.height, 92), 180)
        composerTextViewHeightConstraint?.constant = targetHeight
        composerPostButton.isEnabled = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
        composerPostButton.alpha = composerPostButton.isEnabled ? 1 : 0.55
        UIView.animate(withDuration: 0.14) {
            self.view.layoutIfNeeded()
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
