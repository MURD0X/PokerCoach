import SwiftUI
import PokerEngine

// Always-fits coaching: a single-line bar pinned above the action buttons
// with the recommendation and the key numbers; the full written reasoning
// lives in a scrollable sheet behind the "Why?" button.
struct CoachBarView: View {
    @ObservedObject var model: GameViewModel
    let advice: CoachAdvice
    @Binding var showWhy: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(advice.action.rawValue)
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(badgeColor))

            Text(summary)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            Button {
                showWhy = true
            } label: {
                Label("Why?", systemImage: "questionmark.circle.fill")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // One line of the numbers that drive the decision, e.g.
    // "Pair of Kings · 80% win · need 25%".
    private var summary: String {
        var parts: [String] = []
        if let stats = model.stats {
            parts.append(stats.madeHandName)
            parts.append("\(Int((stats.equity.decisionEquity * 100).rounded()))% win")
            let toCall = model.heroToCall
            if toCall > 0 {
                let pot = model.engine.totalPot
                let needed = Int((Double(toCall) / Double(pot + toCall) * 100).rounded())
                parts.append("need \(needed)%")
            }
        } else if let first = advice.lines.first {
            return first
        }
        return parts.joined(separator: " · ")
    }

    private var badgeColor: Color {
        switch advice.action {
        case .fold: return .red
        case .check, .call: return .blue
        case .bet, .raise: return .green
        }
    }
}

// Full reasoning, scrollable by construction.
struct CoachWhySheet: View {
    let advice: CoachAdvice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Coach says: \(advice.action.rawValue)", systemImage: "graduationcap.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(badgeColor))
                    ForEach(advice.lines, id: \.self) { line in
                        Text(line)
                            .font(.system(.subheadline, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle("Coach's reasoning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var badgeColor: Color {
        switch advice.action {
        case .fold: return .red
        case .check, .call: return .blue
        case .bet, .raise: return .green
        }
    }
}
