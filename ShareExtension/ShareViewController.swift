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
        
        let urlType = UTType.url.identifier
        
        // Find the first attachment that is a URL
        if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { (item, error) in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        self.presentShareView(with: url)
                    } else {
                        self.close()
                    }
                }
            }
        } else {
            // Future: Could add fallback here to check for public.plain-text and see if it casts to a URL
            self.close()
        }
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
