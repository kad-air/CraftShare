import SwiftUI

// MARK: - View Model

@MainActor
class BrowserViewModel: ObservableObject {
    @Published var collections: [CraftCollection] = []
    @Published var items: [[String: Any]] = []
    @Published var schema: [CraftProperty] = []
    @Published var contentKey: String = ""
    @Published var contentName: String = "Title"
    @Published var isLoadingCollections = true
    @Published var isLoadingItems = false
    @Published var errorMessage: String?
    @Published var editingItem: [String: Any]?
    @Published var editingItemId: String?
    @Published var isSaving = false

    let credentials: CredentialsManager
    private var currentTask: Task<Void, Never>?

    init(credentials: CredentialsManager) {
        self.credentials = credentials
    }

    deinit {
        currentTask?.cancel()
    }

    private var api: CraftAPI {
        CraftAPI(token: credentials.craftToken, spaceId: credentials.spaceId)
    }

    func fetchCollections() {
        guard credentials.isValid else {
            errorMessage = "Missing API credentials. Configure them in Settings."
            isLoadingCollections = false
            return
        }

        isLoadingCollections = true
        errorMessage = nil

        currentTask?.cancel()
        currentTask = Task {
            do {
                let fetched = try await api.fetchCollections()
                self.collections = fetched
                self.isLoadingCollections = false
            } catch is CancellationError {
            } catch let urlError as URLError where urlError.code == .cancelled {
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoadingCollections = false
            }
        }
    }

    func fetchItems(for collection: CraftCollection) {
        isLoadingItems = true
        items = []
        errorMessage = nil

        currentTask?.cancel()
        currentTask = Task {
            do {
                async let schemaResult = api.fetchSchema(collectionId: collection.id)
                async let itemsResult = api.fetchItems(collectionId: collection.id)

                let (schemaData, rawItems) = try await (schemaResult, itemsResult)

                self.schema = schemaData.properties
                self.contentKey = schemaData.contentKey
                self.contentName = schemaData.contentName

                // Flatten items: merge top-level content key with nested properties
                var flatItems: [[String: Any]] = []
                for raw in rawItems {
                    var flat: [String: Any] = [:]
                    flat["id"] = raw["id"]

                    if let contentValue = raw[schemaData.contentKey] {
                        flat[schemaData.contentKey] = contentValue
                    }

                    if let props = raw["properties"] as? [String: Any] {
                        for (k, v) in props {
                            flat[k] = v
                        }
                    }

                    flatItems.append(flat)
                }

                self.items = flatItems
                self.isLoadingItems = false
            } catch is CancellationError {
            } catch let urlError as URLError where urlError.code == .cancelled {
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoadingItems = false
            }
        }
    }

    func startEditing(item: [String: Any]) {
        editingItemId = item["id"] as? String
        var editable = item
        editable.removeValue(forKey: "id")
        editingItem = editable
    }

    func saveItem(for collection: CraftCollection) {
        guard let itemId = editingItemId, let item = editingItem else { return }
        isSaving = true

        currentTask?.cancel()
        currentTask = Task {
            do {
                try await api.updateItem(
                    collectionId: collection.id,
                    itemId: itemId,
                    item: item,
                    contentKey: contentKey
                )

                self.editingItem = nil
                self.editingItemId = nil
                self.isSaving = false
                self.fetchItems(for: collection)
            } catch is CancellationError {
            } catch let urlError as URLError where urlError.code == .cancelled {
            } catch {
                self.errorMessage = error.localizedDescription
                self.isSaving = false
            }
        }
    }

    func cancelEditing() {
        editingItem = nil
        editingItemId = nil
    }
}

// MARK: - Collection List

struct CollectionBrowserView: View {
    @StateObject private var viewModel: BrowserViewModel

    init(credentials: CredentialsManager) {
        _viewModel = StateObject(wrappedValue: BrowserViewModel(credentials: credentials))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()

                Group {
                    if let error = viewModel.errorMessage, viewModel.collections.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Button("Retry") { viewModel.fetchCollections() }
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.isLoadingCollections {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading collections...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.collections.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Collections")
                                .font(.headline)
                            Text("Create collections in Craft to browse them here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.collections) { collection in
                                    NavigationLink(value: collection) {
                                        GlassCard(padding: 16) {
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
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .refreshable { viewModel.fetchCollections() }
                    }
                }
            }
            .navigationTitle("Collections")
            .navigationDestination(for: CraftCollection.self) { collection in
                CollectionItemsView(collection: collection, viewModel: viewModel)
            }
        }
        .onAppear { viewModel.fetchCollections() }
    }
}

// MARK: - Item List

struct CollectionItemsView: View {
    let collection: CraftCollection
    @ObservedObject var viewModel: BrowserViewModel

    var body: some View {
        ZStack {
            MeshGradientBackground().ignoresSafeArea()

            Group {
                if let error = viewModel.errorMessage, viewModel.items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Retry") { viewModel.fetchItems(for: collection) }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isLoadingItems {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading items...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No Items")
                            .font(.headline)
                        Text("This collection is empty.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(viewModel.items.enumerated()), id: \.offset) { _, item in
                                Button {
                                    viewModel.startEditing(item: item)
                                } label: {
                                    ItemCardView(
                                        item: item,
                                        contentKey: viewModel.contentKey,
                                        schema: viewModel.schema
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .refreshable { viewModel.fetchItems(for: collection) }
                }
            }
        }
        .navigationTitle(collection.name)
        .sheet(isPresented: Binding(
            get: { viewModel.editingItem != nil },
            set: { if !$0 { viewModel.cancelEditing() } }
        )) {
            if viewModel.editingItem != nil {
                ItemEditSheet(
                    collection: collection,
                    viewModel: viewModel
                )
            }
        }
        .onAppear { viewModel.fetchItems(for: collection) }
    }
}

// MARK: - Item Card

struct ItemCardView: View {
    let item: [String: Any]
    let contentKey: String
    let schema: [CraftProperty]

    private var title: String {
        if let t = item[contentKey] as? String, !t.isEmpty { return t }
        return "Untitled"
    }

    private var propertyPreviews: [(String, String)] {
        var previews: [(String, String)] = []
        for prop in schema where prop.key != contentKey {
            guard let value = item[prop.key] else { continue }
            let display: String
            if let arr = value as? [String] {
                display = arr.joined(separator: ", ")
            } else if let str = value as? String, !str.isEmpty {
                display = str
            } else if let num = value as? NSNumber {
                display = num.stringValue
            } else {
                continue
            }
            previews.append((prop.name, display))
            if previews.count >= 3 { break }
        }
        return previews
    }

    var body: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if !propertyPreviews.isEmpty {
                    ForEach(propertyPreviews, id: \.0) { name, value in
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(value)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Item Edit Sheet

struct ItemEditSheet: View {
    let collection: CraftCollection
    @ObservedObject var viewModel: BrowserViewModel

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Title field
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(viewModel.contentName.uppercased(), systemImage: "doc.text.fill")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)

                                TextField("Enter \(viewModel.contentName.lowercased())...", text: stringBinding(for: viewModel.contentKey))
                                    .font(.system(size: 22, weight: .semibold))
                                    .padding(.vertical, 8)
                            }
                        }

                        // Properties
                        if !viewModel.schema.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 20) {
                                    Label("PROPERTIES", systemImage: "slider.horizontal.3")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)

                                    ForEach(viewModel.schema, id: \.key) { prop in
                                        if prop.key != viewModel.contentKey {
                                            propertyControl(for: prop)

                                            if prop.key != viewModel.schema.last?.key {
                                                Divider()
                                                    .background(Color.primary.opacity(0.1))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancelEditing() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { viewModel.saveItem(for: collection) }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Property Controls

    @ViewBuilder
    private func propertyControl(for prop: CraftProperty) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prop.name.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary.opacity(0.8))

            Group {
                if prop.type == "date" {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        DatePicker("", selection: dateBinding(for: prop.key), displayedComponents: .date)
                            .labelsHidden()
                    }
                } else if prop.type == "singleSelect" || prop.type == "select", let options = prop.options {
                    Menu {
                        Button("None") { viewModel.editingItem?[prop.key] = "" }
                        ForEach(options, id: \.name) { option in
                            Button(option.name) { viewModel.editingItem?[prop.key] = option.name }
                        }
                    } label: {
                        HStack {
                            Text(stringBinding(for: prop.key).wrappedValue.isEmpty ? "Select..." : stringBinding(for: prop.key).wrappedValue)
                                .foregroundColor(stringBinding(for: prop.key).wrappedValue.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                    }
                } else if prop.type == "multiSelect", let options = prop.options {
                    MultiSelectView(
                        options: options.map { $0.name },
                        selectedValues: multiSelectBinding(for: prop.key)
                    )
                } else if prop.type == "number" {
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(.orange)
                        TextField("0", text: stringBinding(for: prop.key))
                            .keyboardType(.decimalPad)
                    }
                } else if prop.type == "url" || prop.type == "image" {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                        TextField("https://...", text: stringBinding(for: prop.key))
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .foregroundColor(.blue)
                    }
                } else {
                    TextField(prop.name, text: stringBinding(for: prop.key))
                }
            }
            .font(.system(size: 16))
        }
    }

    // MARK: - Bindings

    private func stringBinding(for key: String) -> Binding<String> {
        Binding(
            get: {
                guard let item = viewModel.editingItem else { return "" }
                if let str = item[key] as? String { return str }
                if let num = item[key] as? NSNumber { return num.stringValue }
                if let d = item[key] as? Double {
                    return floor(d) == d ? String(format: "%.0f", d) : String(d)
                }
                if let i = item[key] as? Int { return String(i) }
                return ""
            },
            set: { viewModel.editingItem?[key] = $0 }
        )
    }

    private func dateBinding(for key: String) -> Binding<Date> {
        Binding(
            get: {
                if let str = viewModel.editingItem?[key] as? String,
                   let date = dateFormatter.date(from: str) {
                    return date
                }
                return Date()
            },
            set: { viewModel.editingItem?[key] = dateFormatter.string(from: $0) }
        )
    }

    private func multiSelectBinding(for key: String) -> Binding<[String]> {
        Binding(
            get: {
                if let arr = viewModel.editingItem?[key] as? [String] { return arr }
                if let str = viewModel.editingItem?[key] as? String, !str.isEmpty {
                    return str.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
                }
                return []
            },
            set: { viewModel.editingItem?[key] = $0 }
        )
    }
}
