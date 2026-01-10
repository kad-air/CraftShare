//
//  DesignSystem.swift
//  CraftShare
//
//  Consolidated UI components shared between the main app and share extension.
//

import SwiftUI
import UIKit

// MARK: - GlassCard

/// A container view with glass morphism styling (frosted glass effect).
/// Use this to wrap content in a visually distinct card with subtle shadow.
struct GlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat

    /// Creates a glass card container.
    /// - Parameters:
    ///   - padding: Internal padding for the card content. Default is 20.
    ///   - content: The content to display inside the card.
    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 10)
    }
}

// MARK: - MeshGradientBackground

/// A decorative background with blurred gradient circles creating a liquid/mesh effect.
/// Adapts to the container size using GeometryReader.
struct MeshGradientBackground: View {
    var body: some View {
        ZStack {
            // Base background color
            Color(UIColor.systemGroupedBackground)

            // Gradient orbs
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

// MARK: - FlowLayout

/// A custom Layout that arranges subviews in a flowing, wrapping manner.
/// Items are placed left-to-right and wrap to the next line when they exceed the available width.
struct FlowLayout: Layout {
    var spacing: CGFloat

    /// Creates a flow layout with the specified spacing between items.
    /// - Parameter spacing: The spacing between items, both horizontally and vertically. Default is 8.
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: .unspecified
            )
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

            // Wrap to next line if this item would exceed the width
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

// MARK: - MultiSelectView

/// A toggleable chip selector for multi-select fields.
/// Displays options as tappable chips that can be selected or deselected.
struct MultiSelectView: View {
    let options: [String]
    @Binding var selectedValues: [String]

    /// Creates a multi-select view.
    /// - Parameters:
    ///   - options: The available options to display as chips.
    ///   - selectedValues: A binding to the array of currently selected values.
    init(options: [String], selectedValues: Binding<[String]>) {
        self.options = options
        self._selectedValues = selectedValues
    }

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

// MARK: - Previews

#Preview("GlassCard") {
    ZStack {
        MeshGradientBackground()
            .ignoresSafeArea()

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Glass Card Preview")
                    .font(.headline)
                Text("This is a sample card with glass morphism styling.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview("MeshGradientBackground") {
    MeshGradientBackground()
        .ignoresSafeArea()
}

#Preview("FlowLayout") {
    FlowLayout(spacing: 8) {
        ForEach(["Swift", "SwiftUI", "UIKit", "Combine", "Foundation", "Core Data"], id: \.self) { tag in
            Text(tag)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
    }
    .padding()
}

#Preview("MultiSelectView") {
    struct PreviewWrapper: View {
        @State private var selected: [String] = ["Option 1"]

        var body: some View {
            MultiSelectView(
                options: ["Option 1", "Option 2", "Option 3", "Long Option Name", "Another"],
                selectedValues: $selected
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
