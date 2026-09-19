import Foundation

/// Color history policy and copy-format identity, compiling the shipped Model sources.
@main
@MainActor
struct ColorTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ label: String) {
        if !condition {
            print("FAIL: \(label)")
            failures += 1
        }
    }

    static func main() {
        let red = ColorValue(red: 1, green: 0, blue: 0)
        let blue = ColorValue(red: 0, green: 0, blue: 1)
        let now = Date(timeIntervalSince1970: 1_000)
        let first = ColorHistoryPolicy.applying(
            red, to: [], id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, now: now)
        expect(first.count == 1, "the first colour is kept")
        expect(first[0].color == red, "the stored colour is the one that was applied")

        let bumped = ColorHistoryPolicy.applying(
            red, to: first, id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            now: now.addingTimeInterval(10))
        expect(bumped.count == 1, "the same colour is bumped rather than stacked")
        expect(bumped[0].id != first[0].id, "a bump is a new record at the front")

        let two = ColorHistoryPolicy.applying(
            blue, to: bumped, id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            now: now.addingTimeInterval(20))
        expect(two.count == 2, "a new colour is prepended")
        expect(two[0].color == blue, "the newest colour leads")
        expect(two[1].color == red, "the previous colour stays")

        var many: [ColorHistoryEntry] = []
        for index in 0..<ColorHistoryPolicy.cap + 5 {
            let color = ColorValue(red: Double(index) / 1000, green: 0.2, blue: 0.3)
            many = ColorHistoryPolicy.applying(
                color, to: many, id: UUID(), now: now.addingTimeInterval(Double(index)))
        }
        expect(many.count == ColorHistoryPolicy.cap, "the file is capped")

        expect(
            ColorFormat.primary(for: red) == .hex,
            "an opaque pick copies as hex, matching the launcher card")
        expect(
            ColorFormat.hex.string(for: red) == "#FF0000", "hex is the eyedropper HUD spelling")

        print(failures == 0 ? "ok" : "\(failures) failed")
        if failures > 0 { exit(1) }
    }
}
