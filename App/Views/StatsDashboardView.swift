import SwiftUI
import Charts
import PokerEngine

struct StatsDashboardView: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        VStack(spacing: 14) {
            if let stats = model.stats {
                gaugesRow(stats)
                if !model.equityHistory.isEmpty {
                    equityChart
                }
                if !stats.outs.isEmpty {
                    outsSection(stats)
                }
                potOddsRow(stats)
            } else {
                ContentUnavailableView(
                    "Stats appear here",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Deal a hand to see your live win probability, outs, and pot odds.")
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func gaugesRow(_ stats: HandStats) -> some View {
        HStack(spacing: 18) {
            VStack(spacing: 2) {
                Gauge(value: stats.equity.win) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int((stats.equity.win * 100).rounded()))%")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(winColor(stats.equity.win))
                Text("Win")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                Gauge(value: min(stats.equity.tie * 4, 1)) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(Int((stats.equity.tie * 100).rounded()))%")
                        .font(.system(.callout, design: .rounded, weight: .bold))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.gray)
                Text("Tie")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(stats.madeHandName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(2)
                ProgressView(value: Double(stats.category.rawValue), total: 8)
                    .tint(winColor(Double(stats.category.rawValue) / 8))
                Text("vs \(stats.opponents) opponent\(stats.opponents > 1 ? "s" : "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var equityChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WIN % BY STREET")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(model.equityHistory) { entry in
                BarMark(
                    x: .value("Street", entry.street),
                    y: .value("Win %", entry.value * 100)
                )
                .foregroundStyle(winColor(entry.value).gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text("\(Int((entry.value * 100).rounded()))")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .chartXScale(domain: ["Pre", "Flop", "Turn", "River"])
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100])
            }
            .frame(height: 110)
        }
    }

    private func outsSection(_ stats: HandStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OUTS — \(stats.outs.count) CARDS IMPROVE YOUR HAND")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 30), spacing: 5)], spacing: 5) {
                ForEach(stats.outs) { out in
                    VStack(spacing: 1) {
                        Text(out.card.text)
                            .font(.system(.footnote, design: .rounded, weight: .bold))
                            .foregroundStyle(out.card.suit.isRed ? Color(red: 0.82, green: 0.18, blue: 0.18) : .primary)
                    }
                    .frame(minWidth: 30, minHeight: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(.tertiarySystemGroupedBackground)))
                }
            }
        }
    }

    @ViewBuilder
    private func potOddsRow(_ stats: HandStats) -> some View {
        let toCall = model.heroToCall
        if model.isHeroTurn && toCall > 0 {
            let pot = model.engine.totalPot
            let needed = Double(toCall) / Double(pot + toCall)
            let have = stats.equity.decisionEquity
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("POT ODDS").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Call \(toCall) to win \(pot + toCall)")
                        .font(.system(.footnote, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Need \(Int((needed * 100).rounded()))% · have \(Int((have * 100).rounded()))%")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(have > needed ? .green : .red)
                    Text(have > needed ? "Profitable call" : "Unprofitable call")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemGroupedBackground)))
        }
    }

    private func winColor(_ value: Double) -> Color {
        if value >= 0.6 { return .green }
        if value >= 0.4 { return .orange }
        return .red
    }
}

struct AdviceCardView: View {
    let advice: CoachAdvice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Coach says: \(advice.action.rawValue)", systemImage: "graduationcap.fill")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(badgeColor))
            ForEach(advice.lines, id: \.self) { line in
                Text(line)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var badgeColor: Color {
        switch advice.action {
        case .fold: return .red
        case .check, .call: return .blue
        case .bet, .raise: return .green
        }
    }
}
