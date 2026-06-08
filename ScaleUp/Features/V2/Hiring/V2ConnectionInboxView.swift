import SwiftUI
import UIKit

/// "Interested employers" — the candidate connection inbox for Hire from ScaleUp.
///
/// Ports the mockup's inbox phone frame into the native dark V2 theme:
///   • pending  → masked "A verified employer" + role context + message +
///                Approve / Decline buttons,
///   • approved → "Connected" + revealed { companyName, name, email },
///   • declined → greyed out,
///   • a three-gate reassurance line at the bottom.
///
/// Employer identity is only ever revealed by the backend after the candidate
/// approves — until then every card shows the masked label.
struct V2ConnectionInboxView: View {
    @State private var vm: V2HiringViewModel
    @Environment(AppState.self) private var appState
    @State private var didLoad = false
    @State private var share: ShareItem?
    @State private var copiedId: String?

    /// Accepts the shared view model from the Open-to-work screen so the inbox
    /// badge / pending count stay consistent across the flow.
    init(viewModel: V2HiringViewModel = V2HiringViewModel()) {
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            ScrollView {
                if vm.loading && vm.connections.isEmpty {
                    loadingState
                } else if vm.connections.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(vm.connections) { conn in
                            card(for: conn)
                        }
                        reassuranceLine
                            .padding(.top, 8)
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, V2Theme.pad)
                    .padding(.top, 18)
                }
            }
        }
        .navigationTitle("Interested employers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !didLoad {
                didLoad = true
                await vm.loadConnections()
            }
        }
        .refreshable { await vm.loadConnections() }
        .sheet(item: $share) { item in
            ActivityView(items: [item.text])
        }
    }

    // MARK: - Card router

    @ViewBuilder
    private func card(for conn: CandidateConn) -> some View {
        if conn.isApproved {
            approvedCard(conn)
        } else if conn.isDeclined {
            declinedCard(conn)
        } else {
            pendingCard(conn)
        }
    }

    // MARK: - Pending

    private func pendingCard(_ conn: CandidateConn) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            employerHeader(conn, monogramTint: ColorTokens.gold)
            if let message = conn.message, !message.isEmpty {
                quote(message)
            }
            HStack(spacing: 10) {
                Button {
                    Haptics.success()
                    Task { await vm.approve(conn.connectionId) }
                } label: {
                    actionLabel("Approve & connect")
                        .foregroundStyle(.white)
                        .background(ColorTokens.success)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .disabled(vm.loading)

                Button {
                    Haptics.light()
                    Task { await vm.decline(conn.connectionId) }
                } label: {
                    actionLabel("Decline")
                        .foregroundStyle(ColorTokens.textSecondary)
                        .background(ColorTokens.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .disabled(vm.loading)
            }
            .padding(.top, 12)

            Text("Shares your name + contact with this employer only.")
                .font(.system(size: 10.5))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
        }
        .cardChrome()
    }

    // MARK: - Approved

    private func approvedCard(_ conn: CandidateConn) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            employerHeader(conn, monogramTint: ColorTokens.success, revealCompany: true)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.success)
                Text("Connected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.success)
            }
            .padding(.top, 12)

            if let reveal = conn.reveal {
                VStack(alignment: .leading, spacing: 8) {
                    if let name = reveal.name, !name.isEmpty {
                        revealRow(icon: "person.fill", text: name)
                    }
                    if let email = reveal.email, !email.isEmpty {
                        revealRow(icon: "envelope.fill", text: email)
                    }
                }
                .padding(.top, 12)
            }

            reachOutBlock(conn)
        }
        .cardChrome()
    }

    // MARK: - Declined (greyed)

    private func declinedCard(_ conn: CandidateConn) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            employerHeader(conn, monogramTint: ColorTokens.textTertiary)
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textTertiary)
                Text("Declined")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.top, 12)
        }
        .cardChrome()
        .opacity(0.55)
    }

    // MARK: - Shared pieces

    private func employerHeader(_ conn: CandidateConn, monogramTint: Color, revealCompany: Bool = false) -> some View {
        let title = revealCompany
            ? (conn.reveal?.companyName ?? conn.employer ?? "A verified employer")
            : (conn.employer ?? "A verified employer")
        let monogram = String((title.first ?? "?")).uppercased()
        return HStack(spacing: 11) {
            Text(monogram)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(monogramTint)
                .frame(width: 40, height: 40)
                .background(monogramTint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                if let role = conn.roleContext, !role.isEmpty {
                    Text(role)
                        .font(.system(size: 11.5))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func quote(_ message: String) -> some View {
        Text("“\(message)”")
            .font(.system(size: 13))
            .foregroundStyle(ColorTokens.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 11).fill(ColorTokens.surfaceElevated))
            .padding(.top, 13)
    }

    private func actionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13.5, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
    }

    private func revealRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.gold)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textPrimary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Reach out (post-approval)

    @ViewBuilder private func reachOutBlock(_ conn: CandidateConn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(V2Theme.cardBorder).frame(height: 1).padding(.top, 14)
            Text("REACH OUT")
                .font(.system(size: 10, weight: .bold)).tracking(1.2)
                .foregroundStyle(ColorTokens.gold)
            if let email = conn.reveal?.email, !email.isEmpty {
                Button {
                    UIPasteboard.general.string = email
                    Haptics.success()
                    copiedId = conn.connectionId
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: copiedId == conn.connectionId ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                        Text(copiedId == conn.connectionId ? "Email copied" : "Copy email")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(ColorTokens.gold)
                    .padding(.vertical, 10).padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.gold.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            Text(introMessage(for: conn))
                .font(.system(size: 12.5))
                .foregroundStyle(ColorTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 11).fill(ColorTokens.surfaceElevated))
            Button {
                Haptics.light()
                share = ShareItem(text: introMessage(for: conn))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 13, weight: .semibold))
                    Text("Share intro").font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(ColorTokens.surfaceElevated))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private func introMessage(for conn: CandidateConn) -> String {
        let hi = (conn.reveal?.name).map { "Hi \($0)," } ?? "Hi,"
        let roleBit = (conn.roleContext).map { " about the \($0) role" } ?? ""
        let companyBit = (conn.reveal?.companyName).map { " at \($0)" } ?? ""
        return "\(hi)\n\nThanks for connecting on ScaleUp! I'd love to chat\(roleBit)\(companyBit). My verified readiness, skills and evidence are on my ScaleUp profile — happy to share more whenever works for you."
    }

    private var reassuranceLine: some View {
        VStack(spacing: 4) {
            Text("Three gates protect you")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
            Text("you opt in · employers are vetted · you approve each connection")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading your inbox…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 30))
                .foregroundStyle(ColorTokens.textTertiary)
            Text("No employer interest yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
            Text("When a vetted employer expresses interest, it'll show up here for you to approve or decline.")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
            reassuranceLine
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 70)
    }
}

// MARK: - Card chrome

private extension View {
    /// Standard inbox-card chrome (surface fill + border + rounded corners).
    func cardChrome() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ColorTokens.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(V2Theme.cardBorder, lineWidth: 1))
    }
}

/// Identifiable wrapper so a shareable intro string can drive `.sheet(item:)`.
private struct ShareItem: Identifiable {
    let id = UUID()
    let text: String
}

#Preview { NavigationStack { V2ConnectionInboxView() }.preferredColorScheme(.dark) }
