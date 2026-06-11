import SwiftUI
import PokerEngine

// Always-fits dashboard: every row has a bounded height, with detail one tap
// away (outs expand inline). The win-%-by-street chart lives in the hand-end
// result view, not here.
struct StatsDashboardView: View {
    @ObservedObject var model: GameViewModel
    @State private var outsExpanded = false

    /// Out chips shown in the collapsed row before "+N more".
    private static let outsPreviewCount = 6

    var body: some View {
        VStack(spacing: 12) {
            if let stats = model.stats {
                gaugesRow(stats)
                if !stats.outs.isEmpty {
                    outsRow(stats)
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
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
        .onChange(of: model.engine.handNumber) { outsExpanded = false }
    }

    private func gaugesRow(_ stats: HandStats) -> some View {
        HStack(spacing: 16) {
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

            VStack(alignment: .leading, spacing: 5) {
                Text(stats.madeHandName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                ProgressView(value: Double(stats.category.rawValue), total: 8)
                    .tint(winColor(Double(stats.category.rawValue) / 8))
                Text("vs \(stats.opponents) opponent\(stats.opponents > 1 ? "s" : "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func outsRow(_ stats: HandStats) -> some View {
        let outs = stats.outs
        let expandable = outs.count > Self.outsPreviewCount
        return Button {
            guard expandable else { return }
            withAnimation(.spring(duration: 0.3)) { outsExpanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("OUTS — \(outs.count) CARD\(outs.count == 1 ? " IMPROVES" : "S IMPROVE") YOUR HAND")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if expandable {
                        Image(systemName: outsExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                if outsExpanded {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 5)], spacing: 5) {
                        ForEach(outs) { out in outChip(out.card) }
                    }
                } else {
                    HStack(spacing: 5) {
                        ForEach(outs.prefix(Self.outsPreviewCount)) { out in outChip(out.card) }
                        if expandable {
                            Text("+\(outs.count - Self.outsPreviewCount) more")
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func outChip(_ card: Card) -> some View {
        Text(card.text)
            .font(.system(.footnote, design: .rounded, weight: .bold))
            .foregroundStyle(card.suit.isRed ? Color(red: 0.82, green: 0.18, blue: 0.18) : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minWidth: 34, minHeight: 26)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(.tertiarySystemGroupedBackground)))
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
