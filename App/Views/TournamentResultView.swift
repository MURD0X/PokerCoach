import SwiftUI
import PokerEngine

// End-of-tournament standings and payout — the sit-n-go's finishing line.
struct TournamentResultView: View {
    let result: TournamentResult
    let onPlayAgain: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(systemName: result.heroWon ? "trophy.fill" : (result.heroCashed ? "medal.fill" : "flag.checkered"))
                    .font(.system(size: 40))
                    .foregroundStyle(result.heroCashed ? Theme.gold : .secondary)
                Text(headline)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 8) {
                ForEach(result.standings) { s in
                    HStack {
                        Text(place(s.place))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .frame(width: 34, alignment: .leading)
                            .foregroundStyle(s.place <= 2 ? Theme.gold : .secondary)
                        Text(s.name)
                            .font(.system(.subheadline, design: .rounded, weight: s.name == "You" ? .bold : .regular))
                        Spacer()
                        if s.payout > 0 {
                            Text("+\(s.payout)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 2)
                    .opacity(s.name == "You" ? 1 : 0.8)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

            VStack(spacing: 8) {
                Button(action: onPlayAgain) {
                    Label("Play Again (−\(TournamentState.buyIn))", systemImage: "arrow.counterclockwise")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.green).controlSize(.large)
                Button("Done", action: onDone)
                    .buttonStyle(.bordered).controlSize(.large)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }

    private var headline: String {
        if result.heroWon { return "Champion" }
        if result.heroCashed { return "In the money" }
        return "Out in \(ordinal(result.heroPlace))"
    }
    private var subtitle: String {
        if result.heroWon { return "You won the sit-n-go and the \(TournamentState.payout(place: 0)) top prize." }
        if result.heroCashed { return "You finished \(ordinal(result.heroPlace)) and cashed for \(result.heroPayout)." }
        return "Top two paid. Tighten up as the blinds climb and the short stacks shove."
    }
    private func place(_ p: Int) -> String { ordinal(p) }
    private func ordinal(_ n: Int) -> String {
        switch n { case 1: return "1st"; case 2: return "2nd"; case 3: return "3rd"; default: return "\(n)th" }
    }
}
