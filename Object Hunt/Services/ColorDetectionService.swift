import CoreImage

final class ColorDetectionService {
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let sampleSize: CGFloat = 48
    private let centerInset: CGFloat = 0.25

    func matchRatio(in image: CIImage, color: GameColor) -> Double {
        let scaled = downscale(image)
        let cropped = centerRegion(of: scaled)
        guard cropped.extent.width > 1, cropped.extent.height > 1 else { return 0 }
        guard let cgImage = context.createCGImage(cropped, from: cropped.extent) else { return 0 }
        return sample(cgImage, color: color)
    }

    private func downscale(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        guard longest > sampleSize else { return image }
        let factor = sampleSize / longest
        return image.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
    }

    private func centerRegion(of image: CIImage) -> CIImage {
        let extent = image.extent
        let insetX = extent.width * centerInset
        let insetY = extent.height * centerInset
        let crop = extent.insetBy(dx: insetX, dy: insetY)
        return image.cropped(to: crop)
    }

    private func sample(_ image: CGImage, color: GameColor) -> Double {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return 0
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var matches = 0
        let total = width * height
        guard total > 0 else { return 0 }
        let range = color.range

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Float(pixels[offset]) / 255
                let g = Float(pixels[offset + 1]) / 255
                let b = Float(pixels[offset + 2]) / 255
                let hsv = Self.hsv(r: r, g: g, b: b)
                if range.contains(hue: hsv.h, saturation: hsv.s, brightness: hsv.v) {
                    matches += 1
                }
            }
        }
        return Double(matches) / Double(total)
    }

    static func hsv(r: Float, g: Float, b: Float) -> (h: Float, s: Float, v: Float) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        var hue: Float = 0
        if delta > 0.0001 {
            if maxC == r {
                hue = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxC == g {
                hue = (b - r) / delta + 2
            } else {
                hue = (r - g) / delta + 4
            }
            hue /= 6
        }
        let saturation = maxC == 0 ? 0 : delta / maxC
        return (hue, saturation, maxC)
    }
}
