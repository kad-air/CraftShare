import SwiftUI

struct EditItemView: View {
    let schema: [CraftProperty]
    let contentKey: String
    let contentName: String
    @Binding var itemData: [String: Any]
    var onSave: () -> Void
    var onCancel: () -> Void
    
    // Helper to format dates for Craft (YYYY-MM-DD)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    var body: some View {
        ZStack {
            // 1. Liquid Background
            MeshGradientBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Review Item")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // 2. Main Content Card (Title)
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
                    
                    // 3. Properties Card
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
                                        
                                        // Divider between items, but not after the last one
                                        if prop.key != schema.last?.key {
                                            Divider()
                                                .background(Color.primary.opacity(0.1))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 4. Action Button
                    Button(action: onSave) {
                        Text("Save to Craft")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                .padding(.vertical)
            }
        }
        .navigationBarHidden(true) // We draw our own header
        .overlay(
            // Close Button Top Right
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(.ultraThinMaterial, in: Circle())
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
                            .autocapitalization(.none)
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
                    // Check if it's an integer (e.g. 5.0 -> "5")
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
                    // Handle comma-separated string format
                    return stringVal.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
                }
                return []
            },
            set: { itemData[key] = $0 }
        )
    }
}

// MARK: - Visual Components

struct MultiSelectView: View {
    let options: [String]
    @Binding var selectedValues: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = selectedValues.contains(option)
                Button(action: {
                    if isSelected {
                        selectedValues.removeAll { $0 == option }
                    } else {
                        selectedValues.append(option)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                        Text(option)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.blue.opacity(0.15) : Color.primary.opacity(0.05))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
            .padding(.horizontal)
    }
}

struct MeshGradientBackground: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground) // Base
            
            // Orbs
            GeometryReader { proxy in
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -50, y: -100)
                
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: proxy.size.width - 200, y: proxy.size.height / 3)
                
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: 50, y: proxy.size.height - 200)
            }
        }
    }
}