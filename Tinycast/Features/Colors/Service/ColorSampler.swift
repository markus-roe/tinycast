import AppKit

/// The system magnifier, returning the sRGB colour the rest of the feature already speaks.
enum ColorSampler {
    @MainActor
    static func pick() async -> ColorValue? {
        await withCheckedContinuation { continuation in
            NSColorSampler().show { color in
                continuation.resume(returning: color.flatMap(Self.value(from:)))
            }
        }
    }

    /// Display P3 and calibrated spaces both flatten through sRGB, matching `ColorValue`.
    private static func value(from color: NSColor) -> ColorValue? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        return ColorValue(
            red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent,
            alpha: rgb.alphaComponent)
    }
}
