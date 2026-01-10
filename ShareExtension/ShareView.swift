import SwiftUI

struct ShareView: View {
    let url: URL
    @ObservedObject var credentials: CredentialsManager
    var onDismiss: () -> Void
    
    @State private var collections: [CraftCollection] = []
    @State private var status: String = "Initializing..."
    @State private var isLoading = true
    @State private var selectedCollection: CraftCollection?
    @State private var errorMessage: String?
    
    // New State for Editing
    @State private var isEditing = false
    @State private var draftItem: [String: Any] = [:]
    @State private var currentSchema: [CraftProperty] = []
    @State private var currentContentKey: String = ""
    @State private var currentContentName: String = "Content"
    @State private var extractedImageUrl: String? = nil
    
    var body: some View {
        ZStack {
            // 1. Liquid Background
            MeshGradientBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if let error = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Error: \(error)")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        Button("Close", action: onDismiss)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .glassCard()
                } else if isEditing {
                    // Show the Editor
                    EditItemView(
                        schema: currentSchema,
                        contentKey: currentContentKey,
                        contentName: currentContentName,
                        itemData: $draftItem,
                        onSave: saveFinalItem,
                        onCancel: {
                            isEditing = false
                            selectedCollection = nil
                        }
                    )
                    .transition(.move(edge: .trailing))
                } else if isLoading || selectedCollection != nil {
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(status)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Modern Collection List
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Save to Craft")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .padding(.horizontal)
                                .padding(.top, 20)
                            
                            Text("Select a collection to store this link.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            ForEach(collections) { collection in
                                Button(action: {
                                    startProcessing(collection: collection)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(collection.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("\(collection.itemCount) items")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .glassCard()
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .animation(.spring(), value: isEditing)
        .animation(.spring(), value: selectedCollection != nil)
        .overlay(
            Group {
                if !isEditing {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding()
                }
            },
            alignment: .topTrailing
        )
        .onAppear {
            fetchCollections()
        }
    }
    
    private func fetchCollections() {
        guard credentials.isValid else {
            errorMessage = "Missing API Keys. Please configure the main app."
            isLoading = false
            return
        }
        
        status = "Fetching Collections..."
        let api = CraftAPI(token: credentials.craftToken, spaceId: credentials.spaceId)
        
        Task {
            do {
                self.collections = try await api.fetchCollections()
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func startProcessing(collection: CraftCollection) {
        selectedCollection = collection
        status = "Analyzing..."
        
        Task {
            do {
                // 1. Fetch Webpage Content
                let (data, _) = try await URLSession.shared.data(from: url)
                let html = String(data: data, encoding: .utf8) ?? ""
                let pageText = html 
                
                // 2. Fetch Schema
                let api = CraftAPI(token: credentials.craftToken, spaceId: credentials.spaceId)
                let schemaData = try await api.fetchSchema(collectionId: collection.id)
                let schema = schemaData.properties
                let contentKey = schemaData.contentKey
                let contentName = schemaData.contentName
                
                // Improved Metadata Extraction (Handles " or ' and variations)
                var mainImageUrl = ""
                let patterns = [
                    "<meta [^>]*property=[\"']og:image[\"'] [^>]*content=[\"'](.*?)[\"']",
                    "<meta [^>]*content=[\"'](.*?)[\"'] [^>]*property=[\"']og:image[\"']",
                    "<meta [^>]*name=[\"']twitter:image[\"'] [^>]*content=[\"'](.*?)[\"']"
                ]
                
                for pattern in patterns {
                    if let range = pageText.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                        // Extract the capture group (the URL)
                        let fullMatch = String(pageText[range])
                        if let urlRange = fullMatch.range(of: "(?<=content=[\"'])(.*?)(?=[\"'])", options: .regularExpression) {
                            mainImageUrl = String(fullMatch[urlRange])
                            break
                        }
                    }
                }
                
                // 3. Generate Item with Gemini
                let gemini = GeminiAPI(apiKey: credentials.geminiKey)
                var itemData = try await gemini.generateItem(
                    url: url.absoluteString, 
                    pageContent: pageText, 
                    schema: schema, 
                    contentKey: contentKey,
                    userGuidance: credentials.userGuidance,
                    suggestedImageUrl: mainImageUrl
                )
                
                // Safety Check: Ensure the main content key exists
                if itemData[contentKey] == nil {
                     // Fallback: Try to use the page title if we extracted it
                     let titleMatch = pageText.range(of: "<title>(.*?)</title>", options: .regularExpression)
                     let extractedTitle = titleMatch.map { String(pageText[$0]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil) } ?? "Shared Link"
                     itemData[contentKey] = extractedTitle
                }
                
                // Switch to Edit Mode instead of saving immediately
                DispatchQueue.main.async {
                    self.currentSchema = schema
                    self.currentContentKey = contentKey
                    self.currentContentName = contentName
                    self.draftItem = itemData
                    self.extractedImageUrl = mainImageUrl.isEmpty ? nil : mainImageUrl
                    self.isEditing = true
                    self.isLoading = false
                }
                
            } catch {
                errorMessage = error.localizedDescription
                selectedCollection = nil 
            }
        }
    }
    
    private func saveFinalItem() {
        guard let collection = selectedCollection else { return }
        isLoading = true
        isEditing = false // Hide editor, show spinner
        status = "Saving to Craft..."
        
        // Date formatter for Craft
        let craftDateFormatter = DateFormatter()
        craftDateFormatter.dateFormat = "yyyy-MM-dd"
        craftDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Data Detector for parsing natural language dates from Gemini
        let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        
        // Sanitize Data before sending
        var finalItem = draftItem
        for prop in currentSchema {
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
            // 2. Handle Dates: Ensure YYYY-MM-DD format
            else if prop.type == "date", let strVal = value as? String {
                // Check if it's already correct
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
            // 3. Remove empty strings for other optional fields
            else if let strVal = value as? String, strVal.isEmpty {
                finalItem.removeValue(forKey: key)
            }
            // 4. Remove actual Nulls
            else if value is NSNull {
                finalItem.removeValue(forKey: key)
            }
        }
        
        Task {
            do {
                let api = CraftAPI(token: credentials.craftToken, spaceId: credentials.spaceId)
                
                // 1. Create the Item (Document)
                let newItemId = try await api.createItem(collectionId: collection.id, item: finalItem, contentKey: currentContentKey)
                
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
                
                onDismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false // Show error state
            }
        }
    }
}

// MARK: - Visual Components

extension View {
    func glassCard() -> some View {
        self.padding()
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
    }
}
