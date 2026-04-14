import UIKit
import WebKit
import Capacitor

class AppViewController: CAPBridgeViewController {
    private let shellBackground = UIColor(red: 238.0 / 255.0, green: 244.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
    private let topGradient = UIColor(red: 247.0 / 255.0, green: 250.0 / 255.0, blue: 255.0 / 255.0, alpha: 1).cgColor
    private let bottomGradient = UIColor(red: 255.0 / 255.0, green: 247.0 / 255.0, blue: 239.0 / 255.0, alpha: 1).cgColor
    private let gradientLayer = CAGradientLayer()

    override open func capacitorDidLoad() {
        super.capacitorDidLoad()

        view.backgroundColor = shellBackground
        gradientLayer.colors = [topGradient, shellBackground.cgColor, bottomGradient]
        gradientLayer.locations = [0.0, 0.58, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        if gradientLayer.superlayer == nil {
            view.layer.insertSublayer(gradientLayer, at: 0)
        }

        guard let webView = webView else { return }
        webView.isOpaque = false
        webView.backgroundColor = shellBackground
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }
}
