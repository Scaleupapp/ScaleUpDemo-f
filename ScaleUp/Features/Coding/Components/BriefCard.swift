import SwiftUI

/// The single source of truth for showing a drill's brief inside an input view.
/// Same typography, padding, and shape across all 3 drill subtypes — only the
/// header label, icon, and expand/collapse behavior vary.
struct BriefCard: View {
    enum Style {
        /// Header with a disclosure chevron; tapping toggles open/closed.
        /// `defaultExpanded` decides the initial state.
        case collapsible(defaultExpanded: Bool)
        /// Header is static text; content is always visible. Use when the
        /// brief IS the primary input context the learner needs to see constantly.
        case alwaysVisible
    }

    let label: String
    let systemImage: String
    let brief: String
    let style: Style

    @State private var isExpanded: Bool

    init(label: String, systemImage: String, brief: String, style: Style) {
        self.label = label
        self.systemImage = systemImage
        self.brief = brief
        self.style = style
        switch style {
        case .collapsible(let defaultExpanded):
            self._isExpanded = State(initialValue: defaultExpanded)
        case .alwaysVisible:
            self._isExpanded = State(initialValue: true)
        }
    }

    // Parsed content
    private var prose: String { CodeBlock.stripCodeBlocks(from: brief) }
    private var codeBlocks: [CodeBlock] { CodeBlock.parse(from: brief) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded {
                content
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        switch style {
        case .collapsible:
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    headerLabel
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .alwaysVisible:
            HStack(spacing: 8) {
                headerLabel
                Spacer()
            }
        }
    }

    private var headerLabel: some View {
        Label {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !prose.isEmpty {
                Text(prose)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            if !codeBlocks.isEmpty {
                CodeViewer(blocks: codeBlocks)
            } else if prose.isEmpty {
                // Defensive: brief has neither prose nor code (shouldn't normally happen);
                // render the raw text so something is visible.
                Text(brief)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
