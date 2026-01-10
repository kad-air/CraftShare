import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    // IMPORTANT: This must match your "Keychain Sharing" group in Xcode
    // Format: "AppIdentifierPrefix.group.kad-air.CraftShare" or just the group name depending on setup.
    // For simplicity, we usually just pass the access group during the query if strictly needed,
    // but often just having the entitlement is enough for the system to group them if we don't specify strict ACLs.
    // We will use a generic save/load that relies on the shared entitlement group.
    
    func save(_ value: String, service: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // This ensures it's available even when device is locked (optional, but good for background extensions)
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
