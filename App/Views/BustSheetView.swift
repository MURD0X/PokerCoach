import SwiftUI
import PokerEngine

// Type-erased button style so the primary/secondary role can swap at runtime.
struct AnyButtonStyle: PrimitiveButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    init<S: PrimitiveButtonStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// Session-over moment: factual and reflective, not theatrical. The sheet
// cannot be swiped away — the only way forward is a fresh table, because
// going broke ends the session (that's the lesson).
struct BustSheetView: View {
    let stats: SessionStats
    let bankrollBalance: Int
    let canBuyBack: Bool
    let onBuyBack: () -> Void
    let onNewTable: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Out of chips")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("That's the session — every player busts sometimes. Take a new seat and apply what you learned.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)

            VStack(spacing: 10) {
                recapRow("clock", "Hands played", "\(stats.handsPlayed)")
                recapRow("dollarsign.circle", "Biggest pot won", "\(stats.biggestPotWon)")
                if let adherence = stats.adherencePercent {
                    recapRow("graduationcap", "Followed the coach", "\(adherence)% of \(stats.decisionsTotal) decisions")
                }
                recapRow("banknote", "Bankroll", "\(bankrollBalance)")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

            VStack(spacing: 8) {
                if canBuyBack {
                    Button(action: onBuyBack) {
                        Label("Buy Back In (−\(BankrollLedger.buyIn))", systemImage: "arrow.counterclockwise")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                }
                Button(action: onNewTable) {
                    Label(canBuyBack ? "Leave — Find a New Table" : "Find a New Table (−\(BankrollLedger.buyIn))", systemImage: "chair")
                        .font(.system(.body, design: .rounded, weight: canBuyBack ? .semibold : .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(canBuyBack ? AnyButtonStyle(.bordered) : AnyButtonStyle(.borderedProminent))
                .tint(canBuyBack ? .secondary : .green)
                .controlSize(.large)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func recapRow(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
    }
}
