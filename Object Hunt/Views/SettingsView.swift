import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ProgressStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Toggle(isOn: Binding(
                    get: { store.settings.soundEnabled },
                    set: { store.setSound($0) }
                )) {
                    Text(String(localized: "Sound"))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .tint(.white)
                Toggle(isOn: Binding(
                    get: { store.settings.hapticsEnabled },
                    set: { store.setHaptics($0) }
                )) {
                    Text(String(localized: "Haptics"))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .tint(.white)
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "Scan feel"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(String(localized: "Calm asks for less of the color. Sharp asks for more."))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                    HStack(spacing: 8) {
                        ForEach(ScanFeel.allCases) { feel in
                            Button {
                                store.setScanFeel(feel)
                            } label: {
                                Text(feel.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(store.settings.scanFeel == feel ? .black : .white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(store.settings.scanFeel == feel ? Color.white : Color.white.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.07, green: 0.06, blue: 0.10).ignoresSafeArea())
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .huntMenuBar()
    }
}
