import SwiftUI
import PokerEngine

// Total ruin: the bankroll can't cover a seat. The big-picture ending —
// lifetime stats, then a clean slate. Same tone as the bust sheet: factual,
// no theatrics.
struct RuinSheetView: View {
    let lifetime: LifetimeStats
    let onFreshBankroll: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Bankroll gone")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Ten buy-ins, all in the other players' stacks. Every pro has been here — bankroll management is the lesson that sticks. Start fresh and play within it.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)

            VStack(spacing: 10) {
                recapRow("chair", "Tables played", "\(lifetime.sessions)")
                recapRow("clock", "Hands all-time", "\(lifetime.hands)")
                recapRow("chart.line.uptrend.xyaxis", "Peak bankroll", "\(lifetime.peakBankroll)")
                if lifetime.ruins > 0 {
                    recapRow("arrow.counterclockwise", "Fresh starts", "\(lifetime.ruins)")
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

            Button(action: onFreshBankroll) {
                Label("Start a Fresh Bankroll (\(BankrollLedger.startingAmount))", systemImage: "banknote")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)

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
