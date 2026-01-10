import Foundation
import SwiftUI
import Combine

class CredentialsManager: ObservableObject {
    // IMPORTANT: In a real app, you must set this App Group ID in your Xcode project settings (Signing & Capabilities)
    // for both the App and the Extension targets.
    static let suiteName = "group.kad-air.CraftShare"
    
    private let defaults = UserDefaults(suiteName: suiteName)
    private let keychain = KeychainHelper.shared
    private let service = "com.kad-air.CraftShare"
    
    @Published var craftToken: String {
        didSet { keychain.save(craftToken, service: service, account: "craftToken") }
    }
    
    @Published var spaceId: String {
        didSet { defaults?.set(spaceId, forKey: "spaceId") }
    }
    
    @Published var geminiKey: String {
        didSet { keychain.save(geminiKey, service: service, account: "geminiKey") }
    }
    
    @Published var userGuidance: String {
        didSet { defaults?.set(userGuidance, forKey: "userGuidance") }
    }
    
    init() {
        self.craftToken = keychain.read(service: service, account: "craftToken") ?? ""
        self.spaceId = defaults?.string(forKey: "spaceId") ?? ""
        self.geminiKey = keychain.read(service: service, account: "geminiKey") ?? ""
        self.userGuidance = defaults?.string(forKey: "userGuidance") ?? ""
    }
    
    var isValid: Bool {
        !craftToken.isEmpty && !spaceId.isEmpty && !geminiKey.isEmpty
    }
}
