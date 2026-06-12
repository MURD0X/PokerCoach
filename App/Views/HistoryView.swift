import SwiftUI
import Charts
import PokerEngine

// The long-term progress view: bankroll over time, lifetime numbers, and
// the recent session ledger. Reached by tapping the bankroll in the header.
struct HistoryView: View {
    let records: [SessionRecord]
    let currentBalance: Int
    @Environment(\.dismiss) private var dismiss

    private var lifetimeNet: Int { records.reduce(0) { $0 + $1.net } }
    private var totalHands: Int { records.reduce(0) { $0 + $1.hands } }
    private var winningSessions: Int { records.filter { $0.net > 0 }.count }

    private var averageAdherence: Int? {
        let graded = records.filter { $0.decisionsTotal > 0 }
        guard !graded.isEmpty else { return nil }
        let followed = graded.reduce(0) { $0 + $1.decisionsFollowed }
        let total = graded.reduce(0) { $0 + $1.decisionsTotal }
        return Int((Double(followed) / Double(total) * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if records.isEmpty {
                        ContentUnavailableView(
                            "No sessions yet",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Finish a table session — by leaving or busting — and your bankroll history starts here.")
                        )
                    } else {
                        chartSection
                        lifetimeSection
                        sessionsSection
                    }
                }
                .padding(20)
            }
            .navigationTitle("Bankroll history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BANKROLL AFTER EACH SESSION")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    LineMark(
                        x: .value("Session", index + 1),
                        y: .value("Bankroll", record.balanceAfter)
                    )
                    .foregroundStyle(.green.gradient)
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Session", index + 1),
                        y: .value("Bankroll", record.balanceAfter)
                    )
                    .foregroundStyle(record.net >= 0 ? Color.green : Color.red)
                    .symbolSize(30)
                }
                RuleMark(y: .value("Start", BankrollLedger.startingAmount))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .frame(height: 160)
        }
    }

    private var lifetimeSection: some View {
        VStack(spacing: 8) {
            statRow("banknote", "Current bankroll", "\(currentBalance)")
            statRow("plusminus.circle", "Lifetime net",
                    lifetimeNet >= 0 ? "+\(lifetimeNet)" : "\(lifetimeNet)",
                    color: lifetimeNet >= 0 ? .green : .red)
            statRow("trophy", "Winning sessions", "\(winningSessions) of \(records.count)")
            statRow("clock", "Hands played", "\(totalHands)")
            if let adherence = averageAdherence {
                statRow("graduationcap", "Coach adherence", "\(adherence)%")
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT SESSIONS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(records.suffix(12).reversed()) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Blinds \(record.stakesName)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text("\(record.date.formatted(date: .abbreviated, time: .shortened)) · \(record.hands) hand\(record.hands == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(record.net >= 0 ? "+\(record.net)" : "\(record.net)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(record.net >= 0 ? .green : .red)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private func statRow(_ icon: String, _ title: String, _ value: String, color: Color = .primary) -> some View {
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
