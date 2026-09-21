import SwiftUI

struct HowToPlayView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                step("1", String(localized: "A color appears. Point the rear camera at something that matches it."))
                step("2", String(localized: "Keep the color inside the scan frame until the bar fills."))
                step("3", String(localized: "A find scores 100 plus 10 for each second left. Three misses end the run."))
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.07, green: 0.06, blue: 0.10).ignoresSafeArea())
        .navigationTitle(String(localized: "How to Play"))
        .navigationBarTitleDisplayMode(.inline)
        .huntMenuBar()
    }

    private func step(_ index: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(index)
                .font(.title2.weight(.bold))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
            Text(text)
                .font(.title3)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
