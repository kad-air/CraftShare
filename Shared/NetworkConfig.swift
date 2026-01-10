// Shared/NetworkConfig.swift
import Foundation

enum NetworkConfig {
    /// Custom URLSession with appropriate timeouts for share extension
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15  // 15 seconds for request
        config.timeoutIntervalForResource = 30 // 30 seconds total
        config.waitsForConnectivity = false    // Fail fast in extension
        return URLSession(configuration: config)
    }()

    /// Maximum HTML content size to download (5MB)
    static let maxHTMLDownloadSize = 5 * 1024 * 1024

    /// Retry configuration
    static let maxRetries = 3
    static let retryBaseDelay: TimeInterval = 1.0
}
