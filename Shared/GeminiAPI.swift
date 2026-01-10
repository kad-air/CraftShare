import Foundation

// MARK: - Gemini API Client

class GeminiAPI {
    let apiKey: String

    private static let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Generate item data from webpage content using Gemini AI
    /// - Parameters:
    ///   - url: The webpage URL
    ///   - pageContent: The HTML content of the webpage
    ///   - schema: Array of property definitions from CraftAPI
    ///   - contentKey: The key for the main content field
    ///   - userGuidance: User-provided guidance for extraction
    ///   - suggestedImageUrl: Suggested image URL from OG metadata
    /// - Returns: Dictionary of extracted values matching schema keys
    func generateItem(url: String, pageContent: String, schema: [CraftProperty], contentKey: String, userGuidance: String, suggestedImageUrl: String) async throws -> [String: Any] {
        // SECURITY: API key is no longer in the URL - it's passed via header
        guard let urlObj = URL(string: Self.baseURL) else {
            throw APIError.invalidURL(Self.baseURL)
        }

        // Construct a prompt that describes the schema
        let schemaDescription = schema.map { prop -> String in
            var desc = "- \(prop.key) (Type: \(prop.type))"
            if prop.type == "date" {
                desc += " [Format: YYYY-MM-DD]"
            }
            if let options = prop.options {
                let values = options.map { $0.name }.joined(separator: ", ")
                desc += " [Options: \(values)]"
            }
            return desc
        }.joined(separator: "\n")

        // Get URL-specific extraction hints
        let siteHints = Self.extractionHints(for: url)

        let promptText = """
        I have a Craft Document Collection with the following schema:
        \(schemaDescription)

        REQUIRED FIELD: You MUST include a field named "\(contentKey)" which represents the main Title of the item.

        SUGGESTED IMAGE URL: \(suggestedImageUrl)
        (If the schema has a field of type 'image', 'url' or named 'Cover'/'Image', please populate it with this URL).
        \(siteHints)
        I want you to extract information from the following webpage text and map it to a single JSON object that fits this schema.

        USER GUIDANCE:
        \(userGuidance)

        Webpage URL: \(url)
        Webpage Content:
        \(pageContent.prefix(100000))

        Return ONLY valid JSON. The keys in the JSON must match the schema keys exactly.
        For 'select' types, try to pick the best option if known, or infer a value.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: urlObj)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // SECURITY: API key passed via header instead of URL query string
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await NetworkConfig.session.data(for: request)

        // Validate HTTP response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        let statusCode = httpResponse.statusCode

        // Handle error status codes
        if statusCode != 200 {
            let errorBody = parseGeminiError(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown error"

            switch statusCode {
            case 429:
                throw APIError.rateLimited
            case 500...599:
                throw APIError.serverError(statusCode)
            default:
                throw APIError.httpError(statusCode: statusCode, body: errorBody)
            }
        }

        // Parse Gemini Response to get the text
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {

            // Clean up Markdown code blocks if present
            let cleanedText = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            if let jsonData = cleanedText.data(using: String.Encoding.utf8),
               let item = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return item
            } else {
                throw APIError.decodingError("Gemini returned invalid JSON: \(cleanedText.prefix(200))...")
            }
        }

        // If we didn't get candidates/content/parts/text, check for error in response
        let errorMessage = parseGeminiError(from: data) ?? String(data: data, encoding: .utf8) ?? "Unknown Gemini response format"
        throw APIError.decodingError("Unexpected Gemini response: \(errorMessage.prefix(200))")
    }

    /// Parse Gemini API error response to extract meaningful error message
    private func parseGeminiError(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            return nil
        }

        var message = ""

        if let errorMessage = error["message"] as? String {
            message = errorMessage
        }

        if let status = error["status"] as? String {
            message = message.isEmpty ? status : "\(status): \(message)"
        }

        if let code = error["code"] as? Int {
            message = message.isEmpty ? "Error code \(code)" : "[\(code)] \(message)"
        }

        return message.isEmpty ? nil : message
    }

    /// Returns URL-specific extraction hints to help Gemini focus on the right content
    private static func extractionHints(for urlString: String) -> String {
        let lowercased = urlString.lowercased()

        // YouTube - focus on the main video, not recommendations
        if lowercased.contains("youtube.com") || lowercased.contains("youtu.be") {
            let videoId = extractYouTubeVideoId(from: urlString)
            let videoIdHint = videoId.map { "- The VIDEO ID we want is: \($0)" } ?? ""
            return """

            IMPORTANT - YOUTUBE VIDEO PAGE:
            This is a YouTube video page. Extract information ONLY about the PRIMARY video being watched.
            \(videoIdHint)
            - Use ONLY the og:title meta tag or the main <title> tag for the video title
            - The title often ends with " - YouTube" which you should remove
            - IGNORE ALL "recommended videos", "up next", playlist suggestions, related videos, and sidebar content
            - IGNORE any video titles that appear in lists or grids - these are recommendations
            - The channel name is the video's uploader/creator (look for the channel link near the video)
            - Look for the video description in the primary content area, not comments
            """
        }

        // Vimeo
        if lowercased.contains("vimeo.com") {
            return """

            IMPORTANT - VIMEO VIDEO PAGE:
            This is a Vimeo video page. Extract information ONLY about the PRIMARY video.
            - IGNORE any related or recommended videos
            - Focus on the main video title, creator, and description
            """
        }

        // Twitter/X - focus on the specific tweet
        if lowercased.contains("twitter.com") || lowercased.contains("x.com") {
            return """

            IMPORTANT - TWITTER/X POST:
            This is a Twitter/X post. Extract information about the SPECIFIC tweet/post in the URL.
            - IGNORE replies, quoted tweets in the thread, and recommended content
            - Focus on the main post's author and content
            """
        }

        // Reddit - focus on the specific post
        if lowercased.contains("reddit.com") {
            return """

            IMPORTANT - REDDIT POST:
            This is a Reddit post. Extract information about the SPECIFIC post in the URL.
            - IGNORE comments, sidebar content, and recommended posts
            - Focus on the post title, author, subreddit, and post content
            """
        }

        // News articles - focus on the article, not ads/related
        if lowercased.contains("news") || lowercased.contains("article") ||
           lowercased.contains("nytimes.com") || lowercased.contains("washingtonpost.com") ||
           lowercased.contains("theguardian.com") || lowercased.contains("bbc.") ||
           lowercased.contains("cnn.com") || lowercased.contains("reuters.com") {
            return """

            IMPORTANT - NEWS ARTICLE:
            This is a news article. Extract information about the PRIMARY article only.
            - IGNORE related articles, advertisements, and sidebar content
            - Focus on the headline, author, publication date, and main article body
            """
        }

        // No specific hints for other URLs
        return ""
    }

    /// Extracts YouTube video ID from various URL formats
    private static func extractYouTubeVideoId(from urlString: String) -> String? {
        // Handle youtu.be/VIDEO_ID
        if let range = urlString.range(of: "youtu.be/([a-zA-Z0-9_-]{11})", options: .regularExpression) {
            let match = String(urlString[range])
            return String(match.dropFirst(9)) // Remove "youtu.be/"
        }

        // Handle youtube.com/watch?v=VIDEO_ID
        if let range = urlString.range(of: "[?&]v=([a-zA-Z0-9_-]{11})", options: .regularExpression) {
            let match = String(urlString[range])
            return String(match.dropFirst(3)) // Remove "?v=" or "&v="
        }

        // Handle youtube.com/shorts/VIDEO_ID
        if let range = urlString.range(of: "/shorts/([a-zA-Z0-9_-]{11})", options: .regularExpression) {
            let match = String(urlString[range])
            return String(match.dropFirst(8)) // Remove "/shorts/"
        }

        // Handle youtube.com/embed/VIDEO_ID
        if let range = urlString.range(of: "/embed/([a-zA-Z0-9_-]{11})", options: .regularExpression) {
            let match = String(urlString[range])
            return String(match.dropFirst(7)) // Remove "/embed/"
        }

        return nil
    }
}
