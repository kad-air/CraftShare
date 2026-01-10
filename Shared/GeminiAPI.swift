import Foundation

class GeminiAPI {
    let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generateItem(url: String, pageContent: String, schema: [CraftProperty], contentKey: String, userGuidance: String, suggestedImageUrl: String) async throws -> [String: Any] {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)"
        guard let urlObj = URL(string: urlString) else { return [:] }
        
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
        
        let promptText = """
        I have a Craft Document Collection with the following schema:
        \(schemaDescription)
        
        REQUIRED FIELD: You MUST include a field named "\(contentKey)" which represents the main Title of the item.
        
        SUGGESTED IMAGE URL: \(suggestedImageUrl)
        (If the schema has a field of type 'image', 'url' or named 'Cover'/'Image', please populate it with this URL).
        
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
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse Gemini Response to get the text
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            
            // Clean up Markdown code blocks if present
            let cleanedText = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let data = cleanedText.data(using: .utf8),
               let item = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return item
            } else {
                // If we got text but it wasn't valid JSON, throw an error with the text
                throw NSError(domain: "GeminiAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Gemini returned invalid JSON: \(cleanedText.prefix(200))..."])
            }
        }
        
        // If we didn't get candidates/content/parts/text
        let rawResponse = String(data: data, encoding: .utf8) ?? "Unknown Gemini Error"
        throw NSError(domain: "GeminiAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Gemini API Error: \(rawResponse.prefix(200))"])
    }
}
