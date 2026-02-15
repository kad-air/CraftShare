import SwiftUI
import Combine

// MARK: - Models

struct IdentifiableItem: Identifiable {
    let id: String
    let data: [String: Any]
}

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
    @Published var selectedCollection: CraftCollection?

    var identifiableItems: [IdentifiableItem] {
        items.enumerated().map { index, item in
            IdentifiableItem(
                id: (item["id"] as? String) ?? "\(index)",
                data: item
            )
        }
    }

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
                try Task.checkCancellation()
                let fetched = try await api.fetchCollections()

                try Task.checkCancellation()
                self.collections = fetched
                self.isLoadingCollections = false
            } catch is CancellationError {
                // Silent cancellation - do nothing
            } catch let urlError as URLError where urlError.code == .cancelled {
                // Silent cancellation - do nothing
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
                try Task.checkCancellation()

                async let schemaResult = api.fetchSchema(collectionId: collection.id)
                async let itemsResult = api.fetchItems(collectionId: collection.id)

                let (schemaData, rawItems) = try await (schemaResult, itemsResult)

                try Task.checkCancellation()

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

                try Task.checkCancellation()
                self.items = flatItems
                self.isLoadingItems = false
            } catch is CancellationError {
                // Silent cancellation - do nothing
            } catch let urlError as URLError where urlError.code == .cancelled {
                // Silent cancellation - do nothing
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoadingItems = false
            }
        }
    }

    func selectCollection(_ collection: CraftCollection) {
        selectedCollection = collection
        fetchItems(for: collection)
    }

    func goBackToCollections() {
        selectedCollection = nil
        items = []
        errorMessage = nil
    }

    func startEditing(item: [String: Any]) {
        editingItemId = item["id"] as? String
        var editable = item
        editable.removeValue(forKey: "id")
        editingItem = editable
    }

    func saveItem() {
        guard let collection = selectedCollection,
              let itemId = editingItemId,
              let item = editingItem else { return }
        isSaving = true

        currentTask?.cancel()
        currentTask = Task {
            do {
                try Task.checkCancellation()
                try await api.updateItem(
                    collectionId: collection.id,
                    itemId: itemId,
                    item: item,
                    contentKey: contentKey
                )

                try Task.checkCancellation()
                self.editingItem = nil
                self.editingItemId = nil
                self.isSaving = false
                self.fetchItems(for: collection)
            } catch is CancellationError {
                // Silent cancellation - do nothing
                self.isSaving = false
            } catch let urlError as URLError where urlError.code == .cancelled {
                // Silent cancellation - do nothing
                self.isSaving = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isSaving = false
            }
        }
    }

    func deleteItem(id itemId: String) {
        guard let collection = selectedCollection else { return }

        items.removeAll { ($0["id"] as? String) == itemId }

        currentTask?.cancel()
        currentTask = Task {
            do {
                try Task.checkCancellation()
                try await api.deleteItem(collectionId: collection.id, itemId: itemId)
            } catch is CancellationError {
                // Silent cancellation
            } catch let urlError as URLError where urlError.code == .cancelled {
                // Silent cancellation
            } catch {
                self.errorMessage = error.localizedDescription
                self.fetchItems(for: collection)
            }
        }
    }

    func refreshCollections() async {
        fetchCollections()
        await currentTask?.value
    }

    func refreshItems() async {
        guard let collection = selectedCollection else { return }
        fetchItems(for: collection)
        await currentTask?.value
    }

    func cancelEditing() {
        editingItem = nil
        editingItemId = nil
        isSaving = false
    }

    func cancelAll() {
        currentTask?.cancel()
        currentTask = nil
    }
}

// Convenience computed property on the view model
extension BrowserViewModel {
    var isEditing: Bool {
        editingItem != nil
    }
}

// MARK: - Collection Browser

struct CollectionBrowserView: View {
    @StateObject private var viewModel: BrowserViewModel

    init(credentials: CredentialsManager) {
        _viewModel = StateObject(wrappedValue: BrowserViewModel(credentials: credentials))
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
                .ignoresSafeArea()

            GlassEffectContainer {
            VStack(spacing: 0) {
                if let error = viewModel.errorMessage, viewModel.selectedCollection == nil {
                    GlassCard {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Error: \(error)")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                            Button("Retry") { viewModel.fetchCollections() }
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                } else if viewModel.isEditing {
                    // Edit Item View
                    ItemEditView(
                        schema: viewModel.schema,
                        contentKey: viewModel.contentKey,
                        contentName: viewModel.contentName,
                        itemData: Binding(
                            get: { viewModel.editingItem ?? [:] },
                            set: { viewModel.editingItem = $0 }
                        ),
                        isSaving: viewModel.isSaving,
                        onSave: { viewModel.saveItem() },
                        onCancel: { viewModel.cancelEditing() }
                    )
                    .transition(.move(edge: .trailing))
                } else if viewModel.selectedCollection != nil {
                    // Item List
                    CollectionItemsView(viewModel: viewModel)
                        .transition(.move(edge: .trailing))
                } else if viewModel.isLoadingCollections {
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading Collections...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Collection List
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Collections")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .padding(.horizontal)
                                .padding(.top, 20)

                            Text("Browse your Craft collections.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            if viewModel.collections.isEmpty {
                                GlassCard {
                                    VStack(spacing: 12) {
                                        Image(systemName: "tray")
                                            .font(.system(size: 30))
                                            .foregroundColor(.secondary)
                                        Text("No collections found.")
                                            .foregroundColor(.secondary)
                                        Text("Create collections in Craft to browse them here.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal)
                            } else {
                                ForEach(viewModel.collections) { collection in
                                    Button(action: {
                                        viewModel.selectCollection(collection)
                                    }) {
                                        GlassCard {
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
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await viewModel.refreshCollections()
                    }
                }
            }
            } // GlassEffectContainer
        }
        .animation(.spring(), value: viewModel.isEditing)
        .animation(.spring(), value: viewModel.selectedCollection != nil)
        .onAppear {
            viewModel.fetchCollections()
        }
        .onDisappear {
            viewModel.cancelAll()
        }
    }
}

// MARK: - Collection Items View

private struct CollectionItemsView: View {
    @ObservedObject var viewModel: BrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                GlassCard {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Error: \(error)")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        Button("Retry") {
                            if let collection = viewModel.selectedCollection {
                                viewModel.fetchItems(for: collection)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
            } else if viewModel.isLoadingItems {
                VStack(spacing: 24) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading Items...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        Text(viewModel.selectedCollection?.name ?? "Items")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 0, trailing: 16))

                        Text("\(viewModel.items.count) items")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }

                    if viewModel.items.isEmpty {
                        Section {
                            GlassCard {
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 30))
                                        .foregroundColor(.secondary)
                                    Text("This collection is empty.")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    } else {
                        Section {
                            ForEach(viewModel.identifiableItems) { entry in
                                Button {
                                    viewModel.startEditing(item: entry.data)
                                } label: {
                                    ItemCardView(
                                        item: entry.data,
                                        contentKey: viewModel.contentKey,
                                        schema: viewModel.schema
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        viewModel.deleteItem(id: entry.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await viewModel.refreshItems()
                }
            }
        }
        .overlay(
            // Back Button Top Left
            Button(action: { viewModel.goBackToCollections() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .glassEffect(.regular, in: .circle)
            }
            .padding(),
            alignment: .topLeading
        )
    }
}

// MARK: - Item Card

private struct ItemCardView: View {
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
        GlassCard {
            HStack {
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
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Item Edit View

private struct ItemEditView: View {
    let schema: [CraftProperty]
    let contentKey: String
    let contentName: String
    @Binding var itemData: [String: Any]
    var isSaving: Bool
    var onSave: () -> Void
    var onCancel: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Edit Item")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)

                // Main Content Card (Title)
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(contentName.uppercased(), systemImage: "doc.text.fill")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)

                        TextField("Enter \(contentName.lowercased())...", text: binding(for: contentKey))
                            .font(.system(size: 22, weight: .semibold, design: .default))
                            .padding(.vertical, 8)
                    }
                }

                // Properties Card
                if !schema.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Label("PROPERTIES", systemImage: "slider.horizontal.3")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)

                            ForEach(schema, id: \.key) { prop in
                                if prop.key != contentKey {
                                    RenderLiquidControl(for: prop)

                                    if prop.key != schema.last?.key {
                                        Divider()
                                            .background(Color.primary.opacity(0.1))
                                    }
                                }
                            }
                        }
                    }
                }

                // Action Button
                if isSaving {
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Saving...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 40)
                } else {
                    Button(action: onSave) {
                        Text("Save Changes")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .padding(.vertical)
        }
        .navigationBarHidden(true)
        .overlay(
            // Close Button Top Right
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            , alignment: .topTrailing
        )
    }

    // MARK: - Custom Controls

    @ViewBuilder
    private func RenderLiquidControl(for prop: CraftProperty) -> some View {
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
                        Button("None", action: { itemData[prop.key] = "" })
                        ForEach(options, id: \.name) { option in
                            Button(option.name) {
                                itemData[prop.key] = option.name
                            }
                        }
                    } label: {
                        HStack {
                            Text(binding(for: prop.key).wrappedValue.isEmpty ? "Select..." : binding(for: prop.key).wrappedValue)
                                .foregroundColor(binding(for: prop.key).wrappedValue.isEmpty ? .secondary : .primary)
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
                        TextField("0", text: binding(for: prop.key))
                            .keyboardType(.decimalPad)
                    }
                } else if prop.type == "url" || prop.type == "image" {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                        TextField("https://...", text: binding(for: prop.key))
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .foregroundColor(.blue)
                    }
                } else {
                    TextField(prop.name, text: binding(for: prop.key))
                }
            }
            .font(.system(size: 16))
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: {
                if let stringVal = itemData[key] as? String {
                    return stringVal
                } else if let numVal = itemData[key] as? NSNumber {
                    return numVal.stringValue
                } else if let doubleVal = itemData[key] as? Double {
                    if floor(doubleVal) == doubleVal {
                        return String(format: "%.0f", doubleVal)
                    } else {
                        return String(doubleVal)
                    }
                } else if let intVal = itemData[key] as? Int {
                    return String(intVal)
                }
                return ""
            },
            set: { itemData[key] = $0 }
        )
    }

    private func dateBinding(for key: String) -> Binding<Date> {
        Binding(
            get: {
                if let dateString = itemData[key] as? String,
                   let date = dateFormatter.date(from: dateString) {
                    return date
                }
                return Date()
            },
            set: { itemData[key] = dateFormatter.string(from: $0) }
        )
    }

    private func multiSelectBinding(for key: String) -> Binding<[String]> {
        Binding(
            get: {
                if let array = itemData[key] as? [String] {
                    return array
                } else if let stringVal = itemData[key] as? String, !stringVal.isEmpty {
                    return stringVal.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
                }
                return []
            },
            set: { itemData[key] = $0 }
        )
    }
}
