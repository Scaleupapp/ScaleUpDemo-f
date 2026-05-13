import SwiftUI

/// V2 Learn Tab — pull-based content discovery.
///
/// Phase 1 stub: reuses the v1 DiscoverView under a v2 chrome. The deeper v2
/// Learn redesign (search-first, no Hero on Learn, plan-aware single carousel)
/// can be layered in incrementally without breaking testers.
struct V2LearnView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Search
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

                    Text("Continue watching")
                        .font(V2Theme.h3)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .padding(.top, 6)

                    placeholderRow(title: "Estimation frameworks", meta: "12 min left · by Lewis Lin", progress: 0.8)
                    placeholderRow(title: "Time complexity basics", meta: "7 min left · by Abdul Bari", progress: 0.45)

                    sectionHeader("Recommended for you")
                    contentCarousel(items: ["Trees & BST mastery", "System Design basics", "OS concepts podcast"])

                    sectionHeader("Trending in SDE placement")
                    contentCarousel(items: ["Google interview decoded", "Graph traversal", "DBMS for placement"])

                    Divider()
                        .background(V2Theme.cardBorder)
                        .padding(.vertical, 6)

                    browseLink(icon: "📚", label: "Browse by topic")
                    browseLink(icon: "🎬", label: "Browse by content type")
                    browseLink(icon: "👥", label: "Browse by creator")

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, V2Theme.pad)
                .padding(.top, 16)
            }
            .background(ColorTokens.background.ignoresSafeArea())
            .navigationTitle("Learn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
        }
    }

    private func placeholderRow(title: String, meta: String, progress: Double) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTokens.surfaceElevated)
                .frame(width: 70, height: 50)
                .overlay(Image(systemName: "play.fill").foregroundStyle(ColorTokens.gold))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(V2Theme.bodyMedium).foregroundStyle(ColorTokens.textPrimary)
                Text(meta).font(.system(size: 11)).foregroundStyle(ColorTokens.textTertiary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(ColorTokens.surfaceElevated).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2).fill(ColorTokens.gold).frame(width: geo.size.width * progress, height: 3)
                    }
                }.frame(height: 3)
            }
            Spacer()
        }
        .padding(14)
        .v2Card(padding: 14)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title).font(V2Theme.h3).foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Text("See all").font(.system(size: 12)).foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.top, 8)
    }

    private func contentCarousel(items: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.self) { item in
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(LinearGradient(colors: [ColorTokens.surfaceElevated, ColorTokens.surface], startPoint: .top, endPoint: .bottom))
                            .frame(width: 140, height: 84)
                            .overlay(Image(systemName: "play.fill").foregroundStyle(ColorTokens.gold))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item).font(.system(size: 12, weight: .semibold)).foregroundStyle(ColorTokens.textPrimary).lineLimit(2)
                            Text("20 min · Hard").font(.system(size: 10)).foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(10)
                    }
                    .frame(width: 140)
                    .background(ColorTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(V2Theme.cardBorder, lineWidth: 1))
                }
            }
        }
    }

    private func browseLink(icon: String, label: String) -> some View {
        HStack {
            Text(icon)
            Text(label).font(V2Theme.bodyMedium).foregroundStyle(ColorTokens.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(V2Theme.cardBorder).frame(height: 1)
        }
    }
}

#Preview { V2LearnView().preferredColorScheme(.dark) }
