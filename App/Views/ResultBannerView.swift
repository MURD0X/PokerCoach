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
    var decisions: [DecisionRecord] = []
    @Environment(\.dismiss) private var dismiss
    @State private var lessonTopic: LessonTopic?

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

                    if !decisions.isEmpty {
                        reviewSection
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
        .sheet(item: $lessonTopic) { topic in
            LessonsView(initialTopic: topic)
        }
    }

    private func barColor(_ value: Double) -> Color {
        if value >= 0.6 { return .green }
        if value >= 0.4 { return .orange }
        return .red
    }

    // MARK: - Decision review

    private var worstLeak: DecisionRecord? {
        decisions.filter { $0.review.verdict == .leak }
            .max { $0.review.severity < $1.review.severity }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR DECISIONS, REVIEWED")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(decisions) { decision in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon(for: decision.review.verdict))
                        .font(.footnote)
                        .foregroundStyle(color(for: decision.review.verdict))
                        .frame(width: 18)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(streetName(decision.street)) — you \(describe(decision.action))\(decision.toCall > 0 ? " facing \(decision.toCall)" : "")")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                        Text(decision.review.line)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            LearnMoreChips(topics: Array(Set(decisions.flatMap(\.topics))).sorted { $0.rawValue < $1.rawValue }) {
                lessonTopic = $0
            }

            if let lesson = worstLeak {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.footnote)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The lesson of this hand")
                            .font(.system(.footnote, design: .rounded, weight: .bold))
                        Text("\(streetName(lesson.street)): \(lesson.review.line)")
                            .font(.system(.caption, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.12)))
            }
        }
    }

    private func streetName(_ stage: Stage) -> String {
        switch stage {
        case .preflop: return "Preflop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        default: return stage.rawValue.capitalized
        }
    }

    private func describe(_ action: HeroAction) -> String {
        switch action {
        case .fold: return "folded"
        case .checkCall: return "checked/called"
        case .raise(let to): return "raised to \(to)"
        }
    }

    private func icon(for verdict: ReviewVerdict) -> String {
        switch verdict {
        case .followed: return "checkmark.circle.fill"
        case .acceptable: return "equal.circle.fill"
        case .leak: return "xmark.circle.fill"
        }
    }

    private func color(for verdict: ReviewVerdict) -> Color {
        switch verdict {
        case .followed: return .green
        case .acceptable: return .orange
        case .leak: return .red
        }
    }
}
