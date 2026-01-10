import UIKit
import SwiftUI
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. Extract URL from Extension Context (Scan all attachments)
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            self.close()
            return
        }

        // Try to extract URL from attachments in order of preference
        extractURL(from: attachments) { [weak self] url in
            DispatchQueue.main.async {
                if let url = url {
                    self?.presentShareView(with: url)
                } else {
                    self?.close()
                }
            }
        }
    }

    /// Extracts a URL from attachments, trying multiple type identifiers
    /// YouTube and some apps share URLs as plain text instead of URL type
    private func extractURL(from attachments: [NSItemProvider], completion: @escaping (URL?) -> Void) {
        // Priority order: URL type first, then plain text
        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        // Try URL type first
        if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { (item, error) in
                if let url = item as? URL {
                    completion(url)
                    return
                }
                // Some apps provide URL as String even with URL type identifier
                if let urlString = item as? String, let url = URL(string: urlString) {
                    completion(url)
                    return
                }
                // URL type failed, try plain text fallback
                self.extractURLFromText(attachments: attachments, completion: completion)
            }
            return
        }

        // No URL type found, try plain text (YouTube, etc.)
        extractURLFromText(attachments: attachments, completion: completion)
    }

    /// Extracts URL from plain text attachment (handles YouTube shares)
    private func extractURLFromText(attachments: [NSItemProvider], completion: @escaping (URL?) -> Void) {
        let textType = UTType.plainText.identifier

        guard let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) else {
            completion(nil)
            return
        }

        provider.loadItem(forTypeIdentifier: textType, options: nil) { (item, error) in
            guard let text = item as? String else {
                completion(nil)
                return
            }

            // Try to find a URL in the shared text
            // YouTube often shares: "Video Title\nhttps://youtu.be/..."
            if let url = self.findURL(in: text) {
                completion(url)
            } else {
                completion(nil)
            }
        }
    }

    /// Finds the first valid URL in a string using NSDataDetector
    private func findURL(in text: String) -> URL? {
        // First try: if the entire trimmed text is a URL
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true {
            return url
        }

        // Second try: use NSDataDetector to find URLs in text
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)

        // Return the first HTTP/HTTPS URL found
        for match in matches {
            if let url = match.url, url.scheme?.hasPrefix("http") == true {
                return url
            }
        }

        return nil
    }
    
    private func presentShareView(with url: URL) {
        let credentials = CredentialsManager()
        let rootView = ShareView(url: url, credentials: credentials) {
            self.close()
        }
        
        let hostingController = UIHostingController(rootView: rootView)
        self.addChild(hostingController)
        self.view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    func close() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
