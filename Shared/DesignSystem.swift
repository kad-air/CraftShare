//
//  DesignSystem.swift
//  CraftShare
//
//  iOS 26 Liquid Glass design system components.
//

import SwiftUI
import UIKit

// MARK: - Glass Effect Modifier

/// A view modifier that applies iOS 26 glass effect, or falls back to material background on older versions.
struct GlassContainerModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

extension View {
    /// Applies glass container styling - uses .glassEffect() on iOS 26+, material background on older versions.
    func glassContainer(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassContainerModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - GlassCard

/// A container view with iOS 26 Liquid Glass styling.
/// Uses .glassEffect() for authentic glass appearance with specular highlights on iOS 26+.
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
            .glassContainer(cornerRadius: 20)
    }
}

// MARK: - LiquidGlassBackground

/// A clean, minimal background for iOS 26 Liquid Glass aesthetic.
/// Uses system background colors without colorful gradient orbs.
struct LiquidGlassBackground: View {
    var body: some View {
        Color(UIColor.systemBackground)
    }
}

// MARK: - MeshGradientBackground (Deprecated - kept for compatibility)

/// Deprecated: Use LiquidGlassBackground instead.
/// Now renders as a clean system background for iOS 26 Liquid Glass aesthetic.
struct MeshGradientBackground: View {
    var body: some View {
        Color(UIColor.systemBackground)
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

/// A toggleable chip selector for multi-select fields with Liquid Glass styling.
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
                    .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Liquid Glass Button Style

/// A button style that applies iOS 26 Liquid Glass appearance.
struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .glassContainer(cornerRadius: 16)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle { LiquidGlassButtonStyle() }
}

// MARK: - Previews

#Preview("GlassCard") {
    ZStack {
        LiquidGlassBackground()
            .ignoresSafeArea()

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Glass Card Preview")
                    .font(.headline)
                Text("iOS 26 Liquid Glass styling.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview("LiquidGlassBackground") {
    LiquidGlassBackground()
        .ignoresSafeArea()
}

#Preview("FlowLayout") {
    FlowLayout(spacing: 8) {
        ForEach(["Swift", "SwiftUI", "UIKit", "Combine", "Foundation", "Core Data"], id: \.self) { tag in
            Text(tag)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
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
