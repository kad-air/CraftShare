import Foundation
import SwiftUI
import Combine

class CredentialsManager: ObservableObject {
    // IMPORTANT: In a real app, you must set this App Group ID in your Xcode project settings (Signing & Capabilities)
    // for both the App and the Extension targets.
    static let suiteName = "group.kad-air.CraftShare"

    private let defaults: UserDefaults?
    private let keychain = KeychainHelper.shared
    private let service = "com.kad-air.CraftShare"

    /// Indicates whether the App Group is properly configured
    let isAppGroupAvailable: Bool

    /// Tracks the last keychain save error for debugging
    @Published private(set) var lastKeychainError: Bool = false

    @Published var craftToken: String {
        didSet {
            let success = keychain.save(craftToken, service: service, account: "craftToken")
            lastKeychainError = !success
        }
    }

    @Published var spaceId: String {
        didSet {
            if let defaults = defaults {
                defaults.set(spaceId, forKey: "spaceId")
            }
        }
    }

    @Published var geminiKey: String {
        didSet {
            let success = keychain.save(geminiKey, service: service, account: "geminiKey")
            lastKeychainError = !success
        }
    }

    @Published var userGuidance: String {
        didSet {
            if let defaults = defaults {
                defaults.set(userGuidance, forKey: "userGuidance")
            }
        }
    }

    init() {
        let defaults = UserDefaults(suiteName: Self.suiteName)
        self.defaults = defaults
        self.isAppGroupAvailable = defaults != nil

        self.craftToken = keychain.read(service: service, account: "craftToken") ?? ""
        self.spaceId = defaults?.string(forKey: "spaceId") ?? ""
        self.geminiKey = keychain.read(service: service, account: "geminiKey") ?? ""
        self.userGuidance = defaults?.string(forKey: "userGuidance") ?? ""
    }

    var isValid: Bool {
        !craftToken.isEmpty && !spaceId.isEmpty && !geminiKey.isEmpty
    }

    /// Returns a user-facing error message if there's a configuration problem, or nil if everything is OK
    var configurationError: String? {
        if !isAppGroupAvailable {
            return "App Group is not configured. Please enable the '\(Self.suiteName)' App Group in Xcode for both the main app and share extension targets."
        }
        if lastKeychainError {
            return "Failed to save credentials to Keychain. Please ensure the Keychain Sharing capability is enabled with the correct access group."
        }
        return nil
    }

    /// Deletes all stored credentials from keychain
    func clearKeychainCredentials() {
        keychain.delete(service: service, account: "craftToken")
        keychain.delete(service: service, account: "geminiKey")
        craftToken = ""
        geminiKey = ""
    }
}
