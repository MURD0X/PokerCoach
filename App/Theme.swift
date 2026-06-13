import SwiftUI

/// The dark-premium visual identity: navy surfaces, gold brand accents.
/// Semantic action colors (fold/call/raise) and verdict colors live in
/// their own views — they're information, not brand, and stay vivid.
enum Theme {
    // Felt / primary surface — a deep navy that reads as a high-end table.
    // Lifted from the original near-black so the centre-lit spotlight reads
    // as a brighter felt, not a murky void.
    static let feltTop = Color(red: 0.20, green: 0.29, blue: 0.48)
    static let feltBottom = Color(red: 0.09, green: 0.14, blue: 0.27)
    static let feltRadius: ClosedRange<CGFloat> = 40...360

    // Brand ground for launch / home header (slightly richer than felt).
    static let brandTop = Color(red: 0.15, green: 0.22, blue: 0.42)
    static let brandBottom = Color(red: 0.04, green: 0.08, blue: 0.16)

    // Gold — the single brand accent (wordmark, chip, dealer button, rims).
    static let goldLight = Color(red: 0.95, green: 0.87, blue: 0.55)
    static let gold = Color(red: 0.80, green: 0.63, blue: 0.23)
    static let goldDeep = Color(red: 0.49, green: 0.34, blue: 0.11)
    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, goldDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // The table border — a thin brushed-gold rail instead of brown wood.
    static let railTop = Color(red: 0.42, green: 0.33, blue: 0.16)
    static let railBottom = Color(red: 0.22, green: 0.16, blue: 0.07)

    // On-felt text and muted chrome.
    static let onFelt = Color(red: 0.93, green: 0.90, blue: 0.82)
    static let onFeltMuted = Color.white.opacity(0.55)

    static func feltGradient(radius: CGFloat = 320) -> RadialGradient {
        RadialGradient(colors: [feltTop, feltBottom], center: .center,
                       startRadius: 40, endRadius: radius)
    }

    static func brandGradient(radius: CGFloat = 320) -> RadialGradient {
        RadialGradient(colors: [brandTop, brandBottom], center: .center,
                       startRadius: 40, endRadius: radius)
    }
}
