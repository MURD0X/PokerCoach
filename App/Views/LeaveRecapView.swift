import SwiftUI
import PokerEngine

// The walking-away moment — the winner's mirror of the bust sheet. Banking
// a profit (or cutting a loss) on purpose is a poker skill; give it a beat.
struct LeaveRecapView: View {
    let stats: SessionStats
    let cashedOut: Int
    let net: Int
    let bankrollBalance: Int
    let onFindTable: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(net >= 0 ? "Cashing out ahead" : "Cashing out")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(net >= 0
                     ? "You leave with \(cashedOut) chips — up \(net) this session. Banking a win is a skill too."
                     : "You leave with \(cashedOut) chips — down \(-net) this session. Walking away beats chasing it.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)

            VStack(spacing: 10) {
                recapRow("plusminus.circle", "Session result", net >= 0 ? "+\(net)" : "\(net)",
                         color: net >= 0 ? .green : .red)
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
                Button(action: onFindTable) {
                    Label("Find a New Table", systemImage: "chair")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)

                Button(action: onDone) {
                    Text("Done for Now")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.medium])
    }

    private func recapRow(_ icon: String, _ title: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}
