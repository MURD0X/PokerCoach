import SwiftUI
import PokerEngine

// Choosing a table is now a bankroll-management decision: each row shows
// what the seat costs and how much of your roll it consumes, with the
// classic ≤10% guideline color-coded.
struct TablePickerView: View {
    let bankroll: Int
    let currentStakes: TableStakes?
    var canLeave = false
    var onLeave: () -> Void = {}
    let onPick: (TableStakes) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TableStakes.all) { stakes in
                        Button {
                            dismiss()
                            onPick(stakes)
                        } label: {
                            row(stakes)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Buy-in is 50 big blinds. The classic bankroll guideline: keep a table's buy-in under 10% of your bankroll, so a bad session can't hurt you.")
                }

                if canLeave {
                    Section {
                        Button(role: .destructive) {
                            dismiss()
                            onLeave()
                        } label: {
                            Label("Cash Out & Leave the Table", systemImage: "figure.walk")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                    } footer: {
                        Text("Banks your current stack into the bankroll and records the session.")
                    }
                }
            }
            .navigationTitle("Choose a table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func row(_ stakes: TableStakes) -> some View {
        let fraction = stakes.bankrollFraction(of: bankroll)
        let percent = Int((fraction * 100).rounded())
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Blinds \(stakes.name)")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    if stakes == currentStakes {
                        Text("CURRENT")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(.tertiarySystemGroupedBackground)))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Buy-in \(stakes.buyIn)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(percent)% of bankroll")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(riskColor(fraction))
                Text(riskLabel(fraction))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(bankroll >= stakes.buyIn ? 1 : 0.45)
    }

    private func riskColor(_ fraction: Double) -> Color {
        if fraction <= 0.10 { return .green }
        if fraction <= 0.20 { return .orange }
        return .red
    }

    private func riskLabel(_ fraction: Double) -> String {
        if fraction <= 0.10 { return "Within the guideline" }
        if fraction <= 0.20 { return "Playing a little high" }
        return "Over your bankroll"
    }
}
