import Foundation

// MARK: - Models

struct CraftCollection: Identifiable, Codable {
    let id: String
    let name: String
    let itemCount: Int
}

struct CraftCollectionsResponse: Codable {
    let items: [CraftCollection]
}

struct CraftSchemaResponse: Codable {
    let contentPropDetails: CraftContentPropDetails
    let properties: [CraftProperty]
}

struct CraftContentPropDetails: Codable {
    let key: String
    let name: String?
}

struct CraftSelectOption: Codable {
    let name: String
}

struct CraftProperty: Codable {
    let key: String
    let name: String
    let type: String
    let options: [CraftSelectOption]?
}

struct CraftCreateItemResponse: Codable {
    let items: [CraftItemResponse]
}

struct CraftItemResponse: Codable {
    let id: String
}

// MARK: - API Service

class CraftAPI {
    let token: String
    let spaceId: String

    init(token: String, spaceId: String) {
        self.token = token
        self.spaceId = spaceId
    }

    private var baseURL: String {
        "https://connect.craft.do/links/\(spaceId)/api/v1"
    }

    // MARK: - Request Building

    /// Builds a URLRequest with proper headers and optional body
    private func buildRequest(endpoint: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        let urlString = "\(baseURL)\(endpoint)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        return request
    }

    /// URL-encodes a collection ID to prevent injection attacks
    private func encodeCollectionId(_ collectionId: String) throws -> String {
        guard let encoded = collectionId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.invalidURL(collectionId)
        }
        return encoded
    }

    // MARK: - Request Execution

    /// Executes a request with retry logic for rate limiting and server errors
    private func executeRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?

        for attempt in 0..<NetworkConfig.maxRetries {
            do {
                let (data, response) = try await NetworkConfig.session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                // Validate status code BEFORE attempting to decode
                switch httpResponse.statusCode {
                case 200...299:
                    return (data, httpResponse)

                case 429:
                    // Rate limited - retry with exponential backoff
                    if attempt < NetworkConfig.maxRetries - 1 {
                        let delay = NetworkConfig.retryBaseDelay * pow(2.0, Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    let errorText = String(data: data, encoding: .utf8) ?? "Rate limited"
                    throw APIError.httpError(statusCode: 429, body: errorText)

                case 500...599:
                    // Server error - retry with exponential backoff
                    if attempt < NetworkConfig.maxRetries - 1 {
                        let delay = NetworkConfig.retryBaseDelay * pow(2.0, Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    let errorText = String(data: data, encoding: .utf8) ?? "Server error"
                    throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorText)

                default:
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorText)
                }

            } catch let error as APIError {
                throw error
            } catch {
                lastError = error
                // Network error - retry with exponential backoff
                if attempt < NetworkConfig.maxRetries - 1 {
                    let delay = NetworkConfig.retryBaseDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
            }
        }

        throw lastError ?? APIError.networkError(NSError(domain: "CraftAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"]))
    }

    // MARK: - API Methods

    func fetchCollections() async throws -> [CraftCollection] {
        let request = try buildRequest(endpoint: "/collections")
        let (data, _) = try await executeRequest(request)

        do {
            let decodedResponse = try JSONDecoder().decode(CraftCollectionsResponse.self, from: data)
            return decodedResponse.items
        } catch {
            let rawString = String(data: data, encoding: .utf8) ?? "Empty response"
            let snippet = String(rawString.prefix(200))
            throw APIError.decodingError("JSON Format Error. Received: \(snippet)...")
        }
    }

    func fetchSchema(collectionId: String) async throws -> (contentKey: String, contentName: String, properties: [CraftProperty]) {
        let encodedId = try encodeCollectionId(collectionId)
        let request = try buildRequest(endpoint: "/collections/\(encodedId)/schema?format=schema")
        let (data, _) = try await executeRequest(request)

        do {
            let decodedResponse = try JSONDecoder().decode(CraftSchemaResponse.self, from: data)
            return (decodedResponse.contentPropDetails.key, decodedResponse.contentPropDetails.name ?? "Title", decodedResponse.properties)
        } catch {
            let rawString = String(data: data, encoding: .utf8) ?? "Empty response"
            let snippet = String(rawString.prefix(500))
            throw APIError.decodingError("Schema Decode Error. Received: \(snippet)...")
        }
    }

    func createItem(collectionId: String, item: [String: Any], contentKey: String) async throws -> String {
        // Restructure the flat Gemini JSON into Craft's nested format
        var craftItem: [String: Any] = [:]
        var properties: [String: Any] = [:]

        for (key, value) in item {
            if key == contentKey {
                craftItem[key] = value
            } else {
                properties[key] = value
            }
        }

        craftItem["properties"] = properties

        let payload: [String: Any] = ["items": [craftItem]]
        let body = try JSONSerialization.data(withJSONObject: payload)

        let encodedId = try encodeCollectionId(collectionId)
        let request = try buildRequest(endpoint: "/collections/\(encodedId)/items", method: "POST", body: body)
        let (data, _) = try await executeRequest(request)

        let decoded = try JSONDecoder().decode(CraftCreateItemResponse.self, from: data)

        guard let itemId = decoded.items.first?.id, !itemId.isEmpty else {
            throw APIError.emptyResponse
        }

        return itemId
    }

    func addInitialDocumentContent(documentId: String, url: String, imageUrl: String?) async throws {
        var blocks: [[String: Any]] = [
            [
                "type": "richUrl",
                "url": url
            ]
        ]

        if let imageUrl = imageUrl, !imageUrl.isEmpty {
            blocks.append([
                "type": "image",
                "url": imageUrl,
                "markdown": "![](\(imageUrl))"
            ])
        }

        let payload: [String: Any] = [
            "blocks": blocks,
            "position": [
                "position": "end",
                "pageId": documentId
            ]
        ]

        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = try buildRequest(endpoint: "/blocks", method: "POST", body: body)
        let _ = try await executeRequest(request)
    }
}
