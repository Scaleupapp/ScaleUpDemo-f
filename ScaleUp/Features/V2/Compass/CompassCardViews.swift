import SwiftUI

// Dispatcher — renders the right card view for a decoded payload.
struct CompassCardView: View {
    let card: CompassCard
    var body: some View {
        switch card.payload {
        case .readiness(let p):          CompassReadinessCard(payload: p)
        case .activityResult(let p):     CompassActivityResultCard(payload: p)
        case .topicDetail(let p):        CompassTopicDetailCard(payload: p)
        case .weakTopics(let topics):    CompassWeakTopicsCard(topics: topics)
        case .recentActivity(let items): CompassRecentActivityCard(items: items)
        case .tutoringResult(let p):     CompassTutoringResultCard(payload: p)
        case .unknown:                   EmptyView()
        }
    }
}

private struct CardShell<Content: View>: View {
    let title: String; let systemImage: String; @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.caption.weight(.semibold)).foregroundStyle(ColorTokens.gold)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(ColorTokens.gold)
            }
            content()
        }
        .padding(12)
        .background(ColorTokens.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ColorTokens.gold.opacity(0.2), lineWidth: 1))
    }
}

private func scoreText(_ v: Double?) -> String { v == nil ? "—" : String(Int(v!.rounded())) }

struct CompassReadinessCard: View {
    let payload: CompassReadinessPayload
    var body: some View {
        CardShell(title: "Readiness", systemImage: "scope") {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(scoreText(payload.value))%").font(.title2.weight(.bold)).foregroundStyle(ColorTokens.textPrimary)
                if let t = payload.target { Text("/ target \(scoreText(t))%").font(.caption).foregroundStyle(ColorTokens.textSecondary) }
            }
            ForEach(payload.topDraggers) { d in
                HStack { Text(d.name).font(.subheadline).foregroundStyle(ColorTokens.textPrimary); Spacer(); Text("\(scoreText(d.score))%").font(.subheadline).foregroundStyle(ColorTokens.textSecondary) }
            }
            if !payload.note.isEmpty { Text(payload.note).font(.caption).foregroundStyle(ColorTokens.textSecondary) }
        }
    }
}

struct CompassActivityResultCard: View {
    let payload: CompassActivityResultPayload
    var body: some View {
        CardShell(title: payload.title, systemImage: "checkmark.seal") {
            Text(payload.scoreLabel).font(.title3.weight(.bold)).foregroundStyle(ColorTokens.textPrimary)
            ForEach(payload.dimensions) { dim in
                HStack { Text(dim.name.capitalized).font(.subheadline).foregroundStyle(ColorTokens.textPrimary); Spacer(); Text(scoreText(dim.score)).font(.subheadline).foregroundStyle(ColorTokens.textSecondary) }
            }
            if let imp = payload.highlights.improvements.first { Text("Improve: \(imp)").font(.caption).foregroundStyle(ColorTokens.textSecondary) }
        }
    }
}

struct CompassTopicDetailCard: View {
    let payload: CompassTopicDetailPayload
    var body: some View {
        CardShell(title: payload.topic.capitalized, systemImage: "chart.line.uptrend.xyaxis") {
            HStack(spacing: 8) {
                Text("\(scoreText(payload.score))%").font(.title3.weight(.bold)).foregroundStyle(ColorTokens.textPrimary)
                if let level = payload.level { Text(level.capitalized).font(.caption).foregroundStyle(ColorTokens.textSecondary) }
                if let trend = payload.trend { Text(trend).font(.caption).foregroundStyle(ColorTokens.textSecondary) }
            }
            ForEach(payload.misconceptions) { m in Text("• \(m.explanation)").font(.caption).foregroundStyle(ColorTokens.textSecondary) }
        }
    }
}

struct CompassWeakTopicsCard: View {
    let topics: [CompassWeakTopic]
    var body: some View {
        CardShell(title: "Weakest topics", systemImage: "exclamationmark.triangle") {
            ForEach(topics) { t in
                HStack { Text(t.topic.capitalized).font(.subheadline).foregroundStyle(ColorTokens.textPrimary); Spacer(); Text("\(scoreText(t.score))%").font(.subheadline).foregroundStyle(ColorTokens.textSecondary) }
            }
        }
    }
}

struct CompassRecentActivityCard: View {
    let items: [CompassActivityItem]
    var body: some View {
        CardShell(title: "Recent activity", systemImage: "clock.arrow.circlepath") {
            ForEach(items) { it in
                HStack { Text("\(it.type.capitalized): \(it.title)").font(.subheadline).foregroundStyle(ColorTokens.textPrimary).lineLimit(1); Spacer(); if let s = it.score { Text("\(scoreText(s))").font(.subheadline).foregroundStyle(ColorTokens.textSecondary) } }
            }
        }
    }
}

struct CompassTutoringResultCard: View {
    let payload: CompassTutoringResultPayload
    var body: some View {
        CardShell(title: "Tutoring check \u{00B7} \(payload.topic.capitalized)", systemImage: "graduationcap.fill") {
            if let s = payload.checkScore {
                Text("You scored \(Int(s.rounded()))%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            HStack(spacing: 6) {
                Text("\(payload.topic.capitalized) mastery:")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                if let b = payload.beforeScore {
                    Text("\(Int(b.rounded()))%")
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)
                if let a = payload.afterScore {
                    Text("\(Int(a.rounded()))%")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                if let d = payload.delta, d != 0 {
                    Text(d > 0 ? "\u{2191}\(Int(d.rounded()))" : "\u{2193}\(Int(abs(d).rounded()))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(d > 0 ? .green : .red)
                }
            }
        }
    }
}
