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

    

    private func request(_ endpoint: String, method: String = "GET", body: Data? = nil) -> URLRequest {

        var request = URLRequest(url: URL(string: "\(baseURL)\(endpoint)")!)

        request.httpMethod = method

        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = body

        return request

    }

    

    func fetchCollections() async throws -> [CraftCollection] {

        let req = request("/collections")

        let (data, response) = try await URLSession.shared.data(for: req)

        

        if let httpResp = response as? HTTPURLResponse, !(200...299).contains(httpResp.statusCode) {

            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"

            throw NSError(domain: "CraftAPI", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error (\(httpResp.statusCode)): \(errorText)"])

        }

        

        do {

            let decodedResponse = try JSONDecoder().decode(CraftCollectionsResponse.self, from: data)

            return decodedResponse.items

        } catch {

            let rawString = String(data: data, encoding: .utf8) ?? "Empty response"

            let snippet = rawString.prefix(200)

            throw NSError(domain: "CraftAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "JSON Format Error. Received: \(snippet)..."])

        }

    }

    

        func fetchSchema(collectionId: String) async throws -> (contentKey: String, contentName: String, properties: [CraftProperty]) {

    

            let req = request("/collections/\(collectionId)/schema?format=schema")

    

            let (data, response) = try await URLSession.shared.data(for: req)

    

            

    

            if let httpResp = response as? HTTPURLResponse, !(200...299).contains(httpResp.statusCode) {

    

                 let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"

    

                 throw NSError(domain: "CraftAPI", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "Schema Fetch Error (\(httpResp.statusCode)): \(errorText)"])

    

             }

    

            

    

            do {

    

                let decodedResponse = try JSONDecoder().decode(CraftSchemaResponse.self, from: data)

    

                return (decodedResponse.contentPropDetails.key, decodedResponse.contentPropDetails.name ?? "Title", decodedResponse.properties)

    

            } catch {

    

                 let rawString = String(data: data, encoding: .utf8) ?? "Empty response"

    

                 // Truncate if too long, but keep enough to see the structure

    

                 let snippet = rawString.prefix(500) 

    

                 throw NSError(domain: "CraftAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Schema Decode Error. Received: \(snippet)..."])

    

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

        

        let req = request("/collections/\(collectionId)/items", method: "POST", body: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        

        if let httpResp = response as? HTTPURLResponse, !(200...299).contains(httpResp.statusCode) {

            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"

            throw NSError(domain: "CraftAPI", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "Craft Save Failed (\(httpResp.statusCode)): \(errorText)"])

        }

        

        let decoded = try JSONDecoder().decode(CraftCreateItemResponse.self, from: data)

        return decoded.items.first?.id ?? ""

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

    

            let req = request("/blocks", method: "POST", body: body)

    

            let (data, response) = try await URLSession.shared.data(for: req)

    

            

    

            if let httpResp = response as? HTTPURLResponse, !(200...299).contains(httpResp.statusCode) {

    

                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"

    

                throw NSError(domain: "CraftAPI", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to add Document Content: \(errorText)"])

    

            }

    

        }

}


