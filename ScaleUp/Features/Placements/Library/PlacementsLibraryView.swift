import SwiftUI

/// Library tab — curated placement-prep content for the cohort.
///
/// Shell for this slice: the curated, cohort-scoped content shelves land in a
/// later pass. Reuses `PlacementsPlaceholderCard` from the Campus tab.
struct PlacementsLibraryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library").v2Eyebrow()
                    Text("Placement prep")
                        .font(V2Theme.h1)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                .padding(.top, 8)

                PlacementsPlaceholderCard(
                    icon: "books.vertical.fill",
                    title: "Curated shelves",
                    message: "Aptitude, DSA, system design, and HR-interview prep curated for your cohort will live here."
                )
                PlacementsPlaceholderCard(
                    icon: "sparkles",
                    title: "Ask Compass",
                    message: "Until shelves are ready, tap the Compass button any time for explanations, practice, and guidance."
                )
            }
            .padding(.horizontal, V2Theme.pad)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.background.ignoresSafeArea())
    }
}
