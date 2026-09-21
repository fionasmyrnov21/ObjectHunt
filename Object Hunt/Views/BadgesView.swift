import SwiftUI

struct BadgesView: View {
    @ObservedObject var store: ProgressStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.badges) { badge in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(badge.title)
                            .font(.headline)
                            .foregroundColor(badge.isUnlocked ? .black : .white)
                        Text(badge.detail)
                            .font(.footnote)
                            .foregroundColor(badge.isUnlocked ? .black.opacity(0.7) : .white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(badge.progress)/\(badge.target)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(badge.isUnlocked ? .black.opacity(0.55) : .white.opacity(0.5))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                    .background(badge.isUnlocked ? Color.white : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(badge.title)
                    .accessibilityValue(badge.isUnlocked ? String(localized: "Unlocked") : String(localized: "Locked"))
                }
            }
            .padding(20)
        }
        .background(Color(red: 0.07, green: 0.06, blue: 0.10).ignoresSafeArea())
        .navigationTitle(String(localized: "Badges"))
        .navigationBarTitleDisplayMode(.inline)
        .huntMenuBar()
    }
}
