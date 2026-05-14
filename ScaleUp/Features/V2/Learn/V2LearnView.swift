import SwiftUI

/// V2 Learn Tab — pull-based content discovery, wired to v1 recommendations.
struct V2LearnView: View {
    @State private var vm = V2LearnViewModel()
    @State private var showDiscover = false
    @Environment(V2TaskRouter.self) private var taskRouter

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Search — opens v1 Discover (full search + browse).
                    Button { showDiscover = true } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(ColorTokens.textTertiary)
                            Text("Search topics, creators, videos…")
                                .font(V2Theme.body)
                                .foregroundStyle(ColorTokens.textTertiary)
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ColorTokens.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(V2Theme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if vm.isLoading && vm.recommendations.isEmpty && vm.continueWatching.isEmpty {
                        loadingState
                    } else if vm.continueWatching.isEmpty && vm.recommendations.isEmpty && vm.trending.isEmpty {
                        emptyState
                    } else {
                        loadedSections
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 16)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Learn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .refreshable { await vm.load() }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showDiscover) {
            NavigationStack {
                DiscoverView()
                    .navigationTitle("Discover")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showDiscover = false }
                        }
                    }
            }
        }
    }

    // MARK: - Thumbnail

    /// Real content thumbnail with a graceful play-glyph placeholder.
    @ViewBuilder
    private func thumbnail(_ item: Content, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let urlStr = item.thumbnailURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        LinearGradient(
                            colors: [ColorTokens.surfaceElevated, ColorTokens.surface],
                            startPoint: .top, endPoint: .bottom
                        )
                        .overlay(Image(systemName: "play.fill").foregroundStyle(ColorTokens.gold))
                    }
                }
            } else {
                LinearGradient(
                    colors: [ColorTokens.surfaceElevated, ColorTokens.surface],
                    startPoint: .top, endPoint: .bottom
                )
                .overlay(Image(systemName: "play.fill").foregroundStyle(ColorTokens.gold))
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    @ViewBuilder
    private var loadedSections: some View {
        if !vm.continueWatching.isEmpty {
            sectionHeader("Continue watching")
            ForEach(vm.continueWatching, id: \.id) { item in
                contentRow(item)
            }
        }

        if !vm.recommendations.isEmpty {
            sectionHeader("Recommended for you")
            contentCarousel(items: vm.recommendations)
        }

        if !vm.trending.isEmpty {
            sectionHeader("Trending in your domain")
            contentCarousel(items: vm.trending)
        }

        Divider()
            .background(V2Theme.cardBorder)
            .padding(.vertical, 6)

        browseLink(icon: "square.grid.2x2", label: "Browse by topic")
        browseLink(icon: "play.rectangle", label: "Browse by content type")
        browseLink(icon: "person.2", label: "Browse by creator")
    }

    private func contentRow(_ item: Content) -> some View {
        Button {
            taskRouter.open(
                taskType: "watch",
                payload: V2HomeData.Payload(contentId: item.id, quizId: nil, interviewId: nil, url: nil),
                title: item.title
            )
        } label: {
            HStack(spacing: 12) {
                thumbnail(item, width: 70, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(V2Theme.bodyMedium)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(2)
                    Text("\(item.contentType.rawValue) · \(durationString(item))")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(14)
            .v2Card(padding: 0)
        }
        .buttonStyle(.plain)
    }

    private func contentCarousel(items: [Content]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.id) { item in
                    Button {
                        taskRouter.open(
                            taskType: "watch",
                            payload: V2HomeData.Payload(contentId: item.id, quizId: nil, interviewId: nil, url: nil),
                            title: item.title
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            thumbnail(item, width: 140, height: 84)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(ColorTokens.textPrimary)
                                    .lineLimit(2)
                                Text(durationString(item))
                                    .font(.system(size: 10))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            .padding(10)
                        }
                        .frame(width: 140)
                        .background(ColorTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func durationString(_ c: Content) -> String {
        if let mins = c.duration.map({ Int(ceil(Double($0) / 60)) }), mins > 0 {
            return "\(mins) min"
        }
        return "—"
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Button { showDiscover = true } label: {
                Text("See all")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.gold)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private func browseLink(icon: String, label: String) -> some View {
        Button { showDiscover = true } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.gold)
                    .frame(width: 28, height: 28)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(label)
                    .font(V2Theme.bodyMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(ColorTokens.gold)
            Text("Loading recommendations…")
                .font(V2Theme.body)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📚").font(.system(size: 32))
            Text("Nothing here yet")
                .font(V2Theme.h3)
                .foregroundStyle(ColorTokens.textPrimary)
            Text("Once you set an objective, we'll surface content tailored for it.")
                .font(V2Theme.small)
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}

#Preview { V2LearnView().preferredColorScheme(.dark) }
