import UIKit
import WebKit
import Capacitor

class AppViewController: CAPBridgeViewController {
    private let shellBackground = UIColor(red: 238.0 / 255.0, green: 244.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)

    override open func capacitorDidLoad() {
        super.capacitorDidLoad()

        view.backgroundColor = shellBackground

        guard let webView = webView else { return }
        webView.isOpaque = false
        webView.backgroundColor = shellBackground
        webView.scrollView.backgroundColor = shellBackground
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.keyboardDismissMode = .interactive
    }
}
