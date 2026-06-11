import SwiftUI
import Charts
import PokerEngine

// Hand results follow the same always-fits pattern as the coach: a bounded
// one-line strip in the bottom bar, with the full recap (every shown hand,
// the beats-comparison, and the equity chart) in a scrollable sheet.
struct ResultStripView: View {
    let result: HandResult
    let onDetails: () -> Void

    private var heroWon: Bool { result.winnerNames.contains("You") }

    var body: some View {
        Button(action: onDetails) {
            HStack(spacing: 10) {
                Image(systemName: heroWon ? "trophy.fill" : "flag.checkered")
                    .font(.footnote)
                    .foregroundStyle(heroWon ? .yellow : .secondary)
                Text(result.headline)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                Label("Details", systemImage: "chevron.up.circle.fill")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(.tint)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

struct ResultDetailSheet: View {
    let result: HandResult
    var equityHistory: [StreetEquity] = []
    @Environment(\.dismiss) private var dismiss

    private var heroWon: Bool { result.winnerNames.contains("You") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Label(result.headline, systemImage: heroWon ? "trophy.fill" : "flag.checkered")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(heroWon ? Color.green : Color.indigo))

                    if let explanation = result.explanation {
                        Text(explanation)
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !result.showdowns.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(result.showdowns) { show in
                                HStack(spacing: 8) {
                                    Image(systemName: show.isWinner ? "trophy.fill" : "xmark")
                                        .font(.caption)
                                        .foregroundStyle(show.isWinner ? .yellow : .secondary)
                                        .frame(width: 16)
                                    Text(show.name)
                                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                                        .frame(width: 56, alignment: .leading)
                                    ForEach(show.hole) { card in
                                        CardView(face: .up(card), width: 24)
                                    }
                                    Text(show.handName)
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(show.isWinner ? .primary : .secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                    Spacer(minLength: 0)
                                    if show.isWinner {
                                        Text("+\(show.amountWon)")
                                            .font(.system(.footnote, design: .rounded, weight: .bold))
                                            .foregroundStyle(.green)
                                    }
                                }
                                .opacity(show.isWinner ? 1 : 0.65)
                            }
                        }
                    } else {
                        Text("Everyone else folded, so no cards were shown — the pot went uncontested.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if equityHistory.count >= 2 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YOUR WIN % BY STREET")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Chart(equityHistory) { entry in
                                BarMark(
                                    x: .value("Street", entry.street),
                                    y: .value("Win %", entry.value * 100)
                                )
                                .foregroundStyle(barColor(entry.value).gradient)
                                .cornerRadius(4)
                                .annotation(position: .overlay) {
                                    Text("\(Int((entry.value * 100).rounded()))")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                            .chartXScale(domain: ["Pre", "Flop", "Turn", "River"])
                            .chartYScale(domain: 0...100)
                            .chartYAxis { AxisMarks(values: [0, 50, 100]) }
                            .frame(height: 100)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Hand result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func barColor(_ value: Double) -> Color {
        if value >= 0.6 { return .green }
        if value >= 0.4 { return .orange }
        return .red
    }
}
