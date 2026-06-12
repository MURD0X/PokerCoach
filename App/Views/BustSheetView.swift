import SwiftUI

// Session-over moment: factual and reflective, not theatrical. The sheet
// cannot be swiped away — the only way forward is a fresh table, because
// going broke ends the session (that's the lesson).
struct BustSheetView: View {
    let stats: SessionStats
    let onNewSeat: () -> Void

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
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

            Button(action: onNewSeat) {
                Label("Take a New Seat", systemImage: "chair")
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
