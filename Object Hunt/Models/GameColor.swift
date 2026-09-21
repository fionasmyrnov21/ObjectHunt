import SwiftUI

struct ColorRange {
    let minimumHue: Float
    let maximumHue: Float
    let minimumSaturation: Float
    let maximumSaturation: Float
    let minimumBrightness: Float
    let maximumBrightness: Float

    func contains(hue: Float, saturation: Float, brightness: Float) -> Bool {
        let hueMatch: Bool
        if minimumHue <= maximumHue {
            hueMatch = hue >= minimumHue && hue <= maximumHue
        } else {
            hueMatch = hue >= minimumHue || hue <= maximumHue
        }
        return hueMatch
            && saturation >= minimumSaturation
            && saturation <= maximumSaturation
            && brightness >= minimumBrightness
            && brightness <= maximumBrightness
    }
}

enum GameColor: String, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink
    case white
    case black

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .red: return String(localized: "Red")
        case .orange: return String(localized: "Orange")
        case .yellow: return String(localized: "Yellow")
        case .green: return String(localized: "Green")
        case .blue: return String(localized: "Blue")
        case .purple: return String(localized: "Purple")
        case .pink: return String(localized: "Pink")
        case .white: return String(localized: "White")
        case .black: return String(localized: "Black")
        }
    }

    var swatch: Color {
        switch self {
        case .red: return Color(red: 0.92, green: 0.18, blue: 0.22)
        case .orange: return Color(red: 0.96, green: 0.52, blue: 0.10)
        case .yellow: return Color(red: 0.96, green: 0.84, blue: 0.12)
        case .green: return Color(red: 0.18, green: 0.72, blue: 0.32)
        case .blue: return Color(red: 0.16, green: 0.42, blue: 0.96)
        case .purple: return Color(red: 0.56, green: 0.24, blue: 0.86)
        case .pink: return Color(red: 0.94, green: 0.36, blue: 0.62)
        case .white: return Color.white
        case .black: return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }

    var range: ColorRange {
        switch self {
        case .red:
            return ColorRange(minimumHue: 0.96, maximumHue: 0.04, minimumSaturation: 0.45, maximumSaturation: 1, minimumBrightness: 0.18, maximumBrightness: 1)
        case .orange:
            return ColorRange(minimumHue: 0.04, maximumHue: 0.10, minimumSaturation: 0.45, maximumSaturation: 1, minimumBrightness: 0.25, maximumBrightness: 1)
        case .yellow:
            return ColorRange(minimumHue: 0.10, maximumHue: 0.18, minimumSaturation: 0.40, maximumSaturation: 1, minimumBrightness: 0.35, maximumBrightness: 1)
        case .green:
            return ColorRange(minimumHue: 0.25, maximumHue: 0.46, minimumSaturation: 0.30, maximumSaturation: 1, minimumBrightness: 0.18, maximumBrightness: 1)
        case .blue:
            return ColorRange(minimumHue: 0.52, maximumHue: 0.72, minimumSaturation: 0.30, maximumSaturation: 1, minimumBrightness: 0.18, maximumBrightness: 1)
        case .purple:
            return ColorRange(minimumHue: 0.72, maximumHue: 0.84, minimumSaturation: 0.28, maximumSaturation: 1, minimumBrightness: 0.18, maximumBrightness: 1)
        case .pink:
            return ColorRange(minimumHue: 0.84, maximumHue: 0.96, minimumSaturation: 0.28, maximumSaturation: 1, minimumBrightness: 0.28, maximumBrightness: 1)
        case .white:
            return ColorRange(minimumHue: 0, maximumHue: 1, minimumSaturation: 0, maximumSaturation: 0.18, minimumBrightness: 0.78, maximumBrightness: 1)
        case .black:
            return ColorRange(minimumHue: 0, maximumHue: 1, minimumSaturation: 0, maximumSaturation: 1, minimumBrightness: 0, maximumBrightness: 0.16)
        }
    }
}
