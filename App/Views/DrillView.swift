import SwiftUI
import PokerEngine

// Flashcard training: ten spots, pick your action, get the coach's verdict
// and reasoning instantly. Pattern recognition without waiting for hands.
struct DrillView: View {
    @Environment(\.dismiss) private var dismiss

    private static let spotsPerDrill = 10

    @State private var spotNumber = 1
    @State private var spot: DrillSpot = DrillGenerator.spot()
    @State private var review: DecisionReview?
    @State private var tally: [ReviewVerdict: Int] = [:]
    @State private var finished = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if finished {
                        recap
                    } else {
                        spotHeader
                        cardArea
                        situation
                        if let review {
                            verdictPanel(review)
                        } else {
                            answerButtons
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(finished ? "Drill complete" : "Spot \(spotNumber) of \(Self.spotsPerDrill)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(review != nil && !finished)
    }

    // MARK: - Spot presentation

    private var spotHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(spot.isPreflop ? "PREFLOP — \(spot.position.rawValue.uppercased())" : streetLabel.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(situationHeadline)
                .font(.system(.headline, design: .rounded, weight: .semibold))
        }
    }

    private var streetLabel: String {
        switch spot.street {
        case .flop: return "On the flop"
        case .turn: return "On the turn"
        default: return "On the river"
        }
    }

    private var situationHeadline: String {
        if spot.toCall == 0 {
            return spot.isPreflop
                ? "Folded to you \(spot.position.rawValue)."
                : "Checked to you. Pot is \(spot.pot)."
        }
        return "Facing \(spot.toCall) into a pot of \(spot.pot)."
    }

    private var cardArea: some View {
        VStack(spacing: 12) {
            if !spot.board.isEmpty {
                HStack(spacing: 6) {
                    ForEach(spot.board) { card in
                        CardView(face: .up(card), width: 44)
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(spot.hole) { card in
                    CardView(face: .up(card), width: 60)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(RadialGradient(
                    colors: [Color(red: 0.16, green: 0.42, blue: 0.31), Color(red: 0.10, green: 0.29, blue: 0.21)],
                    center: .center, startRadius: 30, endRadius: 240
                ))
        )
    }

    private var situation: some View {
        Text("vs \(spot.opponents) opponent\(spot.opponents > 1 ? "s" : "") · what's the move?")
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Answering

    private var answerButtons: some View {
        HStack(spacing: 8) {
            Button { answer(.fold) } label: {
                Text("Fold").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.red)

            Button { answer(.checkCall) } label: {
                Text(spot.toCall == 0 ? "Check" : "Call").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.blue)

            Button { answer(.raise(to: spot.toCall * 3 + spot.pot)) } label: {
                Text(spot.toCall == 0 ? "Bet" : "Raise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.green)
        }
        .controlSize(.large)
    }

    private func answer(_ action: HeroAction) {
        let graded = Reviewer.review(
            recommendation: spot.advice.action, action: action,
            equity: spot.advice.equity, potOddsNeeded: spot.advice.potOddsNeeded,
            street: spot.street
        )
        review = graded
        tally[graded.verdict, default: 0] += 1
    }

    private func verdictPanel(_ review: DecisionReview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon(review.verdict))
                    .foregroundStyle(color(review.verdict))
                Text(title(review.verdict))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            Text(review.line)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("The coach's read:")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(spot.advice.lines, id: \.self) { line in
                Text(line)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                nextSpot()
            } label: {
                Text(spotNumber == Self.spotsPerDrill ? "See Your Score" : "Next Spot")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func nextSpot() {
        if spotNumber == Self.spotsPerDrill {
            finished = true
        } else {
            spotNumber += 1
            spot = DrillGenerator.spot()
            review = nil
        }
    }

    // MARK: - Recap

    private var recap: some View {
        let followed = tally[.followed, default: 0]
        return VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("\(followed) of \(Self.spotsPerDrill)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("decisions matched the coach")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)

            VStack(spacing: 8) {
                recapRow("checkmark.circle.fill", .green, "Matched the coach", tally[.followed, default: 0])
                recapRow("equal.circle.fill", .orange, "Defensible deviations", tally[.acceptable, default: 0])
                recapRow("xmark.circle.fill", .red, "Leaks", tally[.leak, default: 0])
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))

            Button {
                spotNumber = 1
                spot = DrillGenerator.spot()
                review = nil
                tally = [:]
                finished = false
            } label: {
                Label("Drill Again", systemImage: "arrow.counterclockwise")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
        }
    }

    private func recapRow(_ iconName: String, _ tint: Color, _ label: String, _ count: Int) -> some View {
        HStack {
            Label(label, systemImage: iconName)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(tint == .green ? Color.primary : Color.primary)
            Spacer()
            Text("\(count)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    private func icon(_ verdict: ReviewVerdict) -> String {
        switch verdict {
        case .followed: return "checkmark.circle.fill"
        case .acceptable: return "equal.circle.fill"
        case .leak: return "xmark.circle.fill"
        }
    }

    private func color(_ verdict: ReviewVerdict) -> Color {
        switch verdict {
        case .followed: return .green
        case .acceptable: return .orange
        case .leak: return .red
        }
    }

    private func title(_ verdict: ReviewVerdict) -> String {
        switch verdict {
        case .followed: return "Matched the coach"
        case .acceptable: return "Defensible"
        case .leak: return "That's a leak"
        }
    }
}
