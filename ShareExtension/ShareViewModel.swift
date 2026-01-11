import SwiftUI
import Foundation
import Combine

@MainActor
class ShareViewModel: ObservableObject {
    // MARK: - Published State for UI
    @Published var collections: [CraftCollection] = []
    @Published var status: String = "Initializing..."
    @Published var isLoading = true
    @Published var selectedCollection: CraftCollection?
    @Published var errorMessage: String?
    @Published var isEditing = false
    @Published var draftItem: [String: Any] = [:]
    @Published var currentSchema: [CraftProperty] = []
    @Published var currentContentKey: String = ""
    @Published var currentContentName: String = "Content"
    @Published var extractedImageUrl: String?

    // MARK: - Dependencies
    private let url: URL
    private let credentials: CredentialsManager

    // MARK: - Task Management
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization
    init(url: URL, credentials: CredentialsManager) {
        self.url = url
        self.credentials = credentials
    }

    deinit {
        currentTask?.cancel()
    }

    // MARK: - Public Methods

    func fetchCollections() {
        guard credentials.isValid else {
            errorMessage = "Missing API Keys. Please configure the main app."
            isLoading = false
            return
        }

        status = "Fetching Collections..."

        currentTask?.cancel()
        currentTask = Task {
            do {
                try Task.checkCancellation()
                let api = CraftAPI(token: credentials.craftToken, spaceId: credentials.spaceId)
                let fetchedCollections = try await api.fetchCollections()

                try Task.checkCancellation()
                self.collections = fetchedCollections
                self.isLoading = false
            } catch is CancellationError {
                // Silent cancellation - do nothing
            } catch let urlError as URLError where urlError.code == .cancelled {
                // Silent cancellation - do nothing
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func startProcessing(collection: CraftCollection) {
        selectedCollection = collection
        status = "Analyzing..."

        currentTask?.cancel()
        currentTask = Task {
            do {
                // 1. Fetch Webpage Content with size limit
                try Task.checkCancellation()
                let html = try await fetchHTMLWithSizeLimit(from: url)
                let pageText = html

                try Task.checkCancellation()

                // 2. Fetch Schema
                let api = CraftAPI(token: credentials.craftToken, spaceId: credentials.spaceId)
                let schemaData = try await api.fetchSchema(collectionId: collection.id)
                let schema = schemaData.properties
                let contentKey = schemaData.contentKey
                let contentName = schemaData.contentName

                try Task.checkCancellation()

                // 3. Extract OG Image
                let mainImageUrl = extractOGImage(from: pageText)

                // 4. Generate Item with Gemini
                let gemini = GeminiAPI(apiKey: credentials.geminiKey)
                var itemData = try await gemini.generateItem(
                    url: url.absoluteString,
                    pageContent: pageText,
                    schema: schema,
                    contentKey: contentKey,
                    userGuidance: credentials.userGuidance,
                    suggestedImageUrl: mainImageUrl
                )

                try Task.checkCancellation()

                // Safety Check: Ensure the main content key exists
                if itemData[contentKey] == nil {
                    let titleMatch = pageText.range(of: "<title>(.*?)</title>", options: .regularExpression)
                    let extractedTitle = titleMatch.map { String(pageText[$0]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil) } ?? "Shared Link"
                    itemData[contentKey] = extractedTitle
                }

                // Switch to Edit Mode
                self.currentSchema = schema
                self.currentContentKey = contentKey
                self.currentContentName = contentName
                self.draftItem = itemData
                self.extractedImageUrl = mainImageUrl.isEmpty ? nil : mainImageUrl
                self.isEditing = true
                self.isLoading = false

            } catch is CancellationError {
                // Silent cancellation - do nothing
            } catch let urlError as URLError where urlError.code == .cancelled {
                // Silent cancellation - do nothing
            } catch {
                self.errorMessage = error.localizedDescription
                self.selectedCollection = nil
            }
        }
    }

    func saveFinalItem(onDismiss: @escaping () -> Void) {
        guard let collection = selectedCollection else { return }
        isLoading = true
        isEditing = false
        status = "Saving to Craft..."

        // Sanitize the draft item before saving
        let finalItem = sanitizeItemData(draftItem, schema: currentSchema)

        currentTask?.cancel()
        currentTask = Task {
            do {
                try Task.checkCancellation()
                let api = CraftAPI(token: credentials.craftToken, spaceId: credentials.spaceId)

                // 1. Create the Item (Document)
                let newItemId = try await api.createItem(collectionId: collection.id, item: finalItem, contentKey: currentContentKey)

                try Task.checkCancellation()

                // 2. Add Source Link and Image to the document content
                var imageUrlToUse = extractedImageUrl

                // If the user edited a column that looks like an image, use that URL instead
                for (key, value) in draftItem {
                    if let stringVal = value as? String, !stringVal.isEmpty {
                        let lowerKey = key.lowercased()
                        if lowerKey.contains("image") || lowerKey.contains("cover") {
                            imageUrlToUse = stringVal
                        }
                    }
                }

                status = "Adding Content..."
                try await api.addInitialDocumentContent(
                    documentId: newItemId,
                    url: url.absoluteString,
                    imageUrl: imageUrlToUse
                )

                try Task.checkCancellation()
                onDismiss()

            } catch is CancellationError {
                // Silent cancellation - do nothing
            } catch let urlError as URLError where urlError.code == .cancelled {
                // Silent cancellation - do nothing
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func cancelEditing() {
        isEditing = false
        selectedCollection = nil
    }

    func cancelAll() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Private Helpers

    /// Fetches HTML content with a size limit using streaming download
    private func fetchHTMLWithSizeLimit(from url: URL) async throws -> String {
        let (bytes, response) = try await NetworkConfig.session.bytes(from: url)

        // Check expected content length if available
        if let httpResponse = response as? HTTPURLResponse,
           let contentLengthStr = httpResponse.value(forHTTPHeaderField: "Content-Length"),
           let contentLength = Int(contentLengthStr),
           contentLength > NetworkConfig.maxHTMLDownloadSize {
            throw APIError.httpError(
                statusCode: 413,
                body: "Page too large (\(contentLength / 1024 / 1024)MB). Max: \(NetworkConfig.maxHTMLDownloadSize / 1024 / 1024)MB"
            )
        }

        var data = Data()
        data.reserveCapacity(min(NetworkConfig.maxHTMLDownloadSize, 1024 * 1024)) // Reserve up to 1MB initially

        for try await byte in bytes {
            try Task.checkCancellation()
            data.append(byte)

            if data.count > NetworkConfig.maxHTMLDownloadSize {
                // Reached size limit, stop downloading
                break
            }
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Extracts OG image URL from HTML content
    private func extractOGImage(from html: String) -> String {
        let patterns = [
            "<meta [^>]*property=[\"']og:image[\"'] [^>]*content=[\"'](.*?)[\"']",
            "<meta [^>]*content=[\"'](.*?)[\"'] [^>]*property=[\"']og:image[\"']",
            "<meta [^>]*name=[\"']twitter:image[\"'] [^>]*content=[\"'](.*?)[\"']"
        ]

        for pattern in patterns {
            if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let fullMatch = String(html[range])
                if let urlRange = fullMatch.range(of: "(?<=content=[\"'])(.*?)(?=[\"'])", options: .regularExpression) {
                    return String(fullMatch[urlRange])
                }
            }
        }

        return ""
    }

    /// Sanitizes item data before sending to Craft API
    private func sanitizeItemData(_ item: [String: Any], schema: [CraftProperty]) -> [String: Any] {
        // Date formatter for Craft
        let craftDateFormatter = DateFormatter()
        craftDateFormatter.dateFormat = "yyyy-MM-dd"
        craftDateFormatter.locale = Locale(identifier: "en_US_POSIX")

        // Data Detector for parsing natural language dates from Gemini
        let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

        var finalItem = item

        for prop in schema {
            let key = prop.key
            let value = finalItem[key]

            // 1. Handle Numbers: Convert String -> Double, or remove if empty/invalid
            if prop.type == "number" {
                if let strVal = value as? String {
                    if let numVal = Double(strVal) {
                        finalItem[key] = numVal
                    } else {
                        finalItem.removeValue(forKey: key)
                    }
                } else if value == nil || value is NSNull {
                    finalItem.removeValue(forKey: key)
                }
            }
            // 2. Handle Select fields: Validate against allowed options
            else if prop.type == "select" || prop.type == "singleSelect" {
                if let strVal = value as? String, let options = prop.options {
                    let validOptions = options.map { $0.name }
                    if !validOptions.contains(strVal) {
                        // Try case-insensitive match
                        if let match = validOptions.first(where: { $0.lowercased() == strVal.lowercased() }) {
                            finalItem[key] = match
                        } else {
                            finalItem.removeValue(forKey: key)
                        }
                    }
                } else if value == nil || value is NSNull || (value as? String)?.isEmpty == true {
                    finalItem.removeValue(forKey: key)
                }
            }
            // 3. Handle MultiSelect fields: Filter to valid options only
            else if prop.type == "multiSelect" {
                if let options = prop.options {
                    let validOptions = options.map { $0.name }
                    let validOptionsLower = validOptions.map { $0.lowercased() }

                    var validValues: [String] = []

                    // Handle array of strings
                    if let arrayVal = value as? [String] {
                        for val in arrayVal {
                            if validOptions.contains(val) {
                                validValues.append(val)
                            } else if let idx = validOptionsLower.firstIndex(of: val.lowercased()) {
                                // Case-insensitive match - use the correct casing
                                validValues.append(validOptions[idx])
                            }
                        }
                    }
                    // Handle single string (Gemini sometimes returns string instead of array)
                    else if let strVal = value as? String {
                        if validOptions.contains(strVal) {
                            validValues.append(strVal)
                        } else if let idx = validOptionsLower.firstIndex(of: strVal.lowercased()) {
                            validValues.append(validOptions[idx])
                        }
                    }

                    if validValues.isEmpty {
                        finalItem.removeValue(forKey: key)
                    } else {
                        finalItem[key] = validValues
                    }
                } else {
                    finalItem.removeValue(forKey: key)
                }
            }
            // 4. Handle Dates: Ensure YYYY-MM-DD format
            else if prop.type == "date", let strVal = value as? String {
                if craftDateFormatter.date(from: strVal) == nil {
                    // Try to parse natural date (e.g. "Oct 5, 2023")
                    if let detector = dateDetector,
                       let match = detector.firstMatch(in: strVal, options: [], range: NSRange(location: 0, length: strVal.utf16.count)),
                       let date = match.date {
                        finalItem[key] = craftDateFormatter.string(from: date)
                    } else {
                        // Failed to parse, remove it to avoid API error
                        finalItem.removeValue(forKey: key)
                    }
                }
            }
            // 5. Remove empty strings for other optional fields
            else if let strVal = value as? String, strVal.isEmpty {
                finalItem.removeValue(forKey: key)
            }
            // 6. Remove actual Nulls
            else if value is NSNull {
                finalItem.removeValue(forKey: key)
            }
        }

        return finalItem
    }
}
