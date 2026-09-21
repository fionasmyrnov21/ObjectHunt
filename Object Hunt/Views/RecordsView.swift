import SwiftUI

struct RecordsView: View {
    @ObservedObject var store: ProgressStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                row(String(localized: "Best Score"), "\(store.stats.bestScore)")
                row(String(localized: "Games Played"), "\(store.stats.gamesPlayed)")
                row(String(localized: "Finds"), "\(store.stats.finds)")
                row(String(localized: "Best Streak"), "\(store.stats.bestStreak)")
                row(String(localized: "Total Score"), "\(store.stats.totalScore)")
                Text(String(localized: "Colors Found"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 8)
                if store.foundColors().isEmpty {
                    Text(String(localized: "None yet"))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                        ForEach(store.foundColors()) { color in
                            HStack(spacing: 6) {
                                Circle().fill(color.swatch).frame(width: 12, height: 12)
                                Text(color.displayName)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.07, green: 0.06, blue: 0.10).ignoresSafeArea())
        .navigationTitle(String(localized: "Records"))
        .navigationBarTitleDisplayMode(.inline)
        .huntMenuBar()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.72))
            Spacer()
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(.white)
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
