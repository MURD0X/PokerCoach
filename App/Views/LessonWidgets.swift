import SwiftUI
import PokerEngine

// Interactive lesson widgets: the lessons stop describing concepts and
// start demonstrating them, powered by the same tested engine that runs
// the game.

// MARK: - Chen calculator

struct ChenCalculatorView: View {
    @State private var rank1 = 14
    @State private var suit1 = Suit.spades
    @State private var rank2 = 13
    @State private var suit2 = Suit.spades

    private var hole: [Card] { [Card(rank1, suit1), Card(rank2, suit2)] }
    private var duplicate: Bool { rank1 == rank2 && suit1 == suit2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader("TRY IT — SCORE ANY HAND")

            HStack(spacing: 14) {
                cardPicker(rank: $rank1, suit: $suit1)
                cardPicker(rank: $rank2, suit: $suit2)
                Spacer()
                Button {
                    var deck = Deck.shuffled()
                    let a = deck.removeLast(), b = deck.removeLast()
                    (rank1, suit1, rank2, suit2) = (a.rank, a.suit, b.rank, b.suit)
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }

            if duplicate {
                Text("That's the same card twice — pick another.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.orange)
            } else {
                VStack(spacing: 6) {
                    ForEach(Chen.breakdown(hole)) { step in
                        HStack {
                            Text(step.label)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(step.points >= 0 ? "+\(trim(step.points))" : trim(step.points))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(step.points >= 0 ? .green : .red)
                        }
                    }
                    Divider()
                    HStack {
                        Text("Chen score")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Spacer()
                        Text("\(Chen.score(hole))")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text(tier)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemGroupedBackground)))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var tier: String {
        switch Chen.score(hole) {
        case 10...: return "premium"
        case 8...: return "strong"
        case 6...: return "playable"
        default: return "weak"
        }
    }

    private func trim(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func cardPicker(rank: Binding<Int>, suit: Binding<Suit>) -> some View {
        VStack(spacing: 6) {
            CardView(face: .up(Card(rank.wrappedValue, suit.wrappedValue)), width: 48)
            HStack(spacing: 4) {
                Menu {
                    Picker("Rank", selection: rank) {
                        ForEach((2...14).reversed(), id: \.self) { r in
                            Text(Card(r, .spades).rankText).tag(r)
                        }
                    }
                } label: {
                    Text(Card(rank.wrappedValue, .spades).rankText)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .frame(minWidth: 26)
                }
                .buttonStyle(.bordered)
                Menu {
                    Picker("Suit", selection: suit) {
                        ForEach(Suit.allCases, id: \.self) { s in
                            Text(s.symbol).tag(s)
                        }
                    }
                } label: {
                    Text(suit.wrappedValue.symbol)
                        .font(.system(.caption, weight: .bold))
                        .frame(minWidth: 20)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Pot odds playground

struct PotOddsPlaygroundView: View {
    @State private var pot: Double = 100
    @State private var bet: Double = 50
    @State private var outs = 9
    @State private var onFlop = true

    private var needed: Double { bet / (pot + 2 * bet) }
    private var estimate: Int { min(95, outs * (onFlop ? 4 : 2)) }
    private var profitable: Bool { Double(estimate) / 100 > needed }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader("TRY IT — PRICE A CALL")

            VStack(spacing: 8) {
                HStack {
                    Text("Pot before the bet")
                        .font(.system(.caption, design: .rounded))
                    Spacer()
                    Text("\(Int(pot))")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                Slider(value: $pot, in: 20...500, step: 10)
                HStack {
                    Text("Their bet (you must call)")
                        .font(.system(.caption, design: .rounded))
                    Spacer()
                    Text("\(Int(bet))")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                Slider(value: $bet, in: 10...300, step: 10)
                Stepper("Your outs: \(outs)", value: $outs, in: 0...15)
                    .font(.system(.caption, design: .rounded))
                Picker("Street", selection: $onFlop) {
                    Text("On the flop (×4)").tag(true)
                    Text("On the turn (×2)").tag(false)
                }
                .pickerStyle(.segmented)
            }

            VStack(spacing: 5) {
                HStack {
                    Text("Price: call \(Int(bet)) to win \(Int(pot + 2 * bet))")
                        .font(.system(.caption, design: .rounded))
                    Spacer()
                    Text("need \(Int((needed * 100).rounded()))%")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                HStack {
                    Text("Rule of \(onFlop ? "4" : "2"): \(outs) outs")
                        .font(.system(.caption, design: .rounded))
                    Spacer()
                    Text("≈\(estimate)% to improve")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                Divider()
                Text(profitable ? "Profitable call — your chances beat the price." : "Fold — the price is higher than your chances.")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(profitable ? .green : .red)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemGroupedBackground)))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - Which hand wins?

struct WhichHandWinsView: View {
    @State private var board: [Card] = []
    @State private var handA: [Card] = []
    @State private var handB: [Card] = []
    @State private var verdict: String?
    @State private var wasRight: Bool?
    @State private var streak = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader("TRY IT — WHICH HAND WINS?")

            VStack(spacing: 10) {
                HStack(spacing: 5) {
                    ForEach(board) { CardView(face: .up($0), width: 38) }
                }
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) { ForEach(handA) { CardView(face: .up($0), width: 40) } }
                        Text("Hand A").font(.system(.caption2, design: .rounded, weight: .semibold))
                    }
                    VStack(spacing: 4) {
                        HStack(spacing: 4) { ForEach(handB) { CardView(face: .up($0), width: 40) } }
                        Text("Hand B").font(.system(.caption2, design: .rounded, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if let verdict {
                VStack(spacing: 6) {
                    if let wasRight {
                        Text(wasRight ? "Correct! Streak: \(streak)" : "Not quite — streak reset.")
                            .font(.system(.footnote, design: .rounded, weight: .bold))
                            .foregroundStyle(wasRight ? .green : .red)
                    }
                    Text(verdict)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Next Hand") { deal() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 8) {
                    Button("Hand A") { answer(.a) }.buttonStyle(.bordered)
                    Button("Tie") { answer(.tie) }.buttonStyle(.bordered)
                    Button("Hand B") { answer(.b) }.buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        .onAppear { if board.isEmpty { deal() } }
    }

    private enum Answer { case a, tie, b }

    private func deal() {
        var deck = Deck.shuffled()
        board = (0..<5).map { _ in deck.removeLast() }
        handA = (0..<2).map { _ in deck.removeLast() }
        handB = (0..<2).map { _ in deck.removeLast() }
        verdict = nil
        wasRight = nil
    }

    private func answer(_ pick: Answer) {
        let scoreA = HandEvaluator.bestScore(handA + board)
        let scoreB = HandEvaluator.bestScore(handB + board)
        let truth: Answer = scoreA > scoreB ? .a : (scoreB > scoreA ? .b : .tie)
        wasRight = pick == truth
        streak = (wasRight == true) ? streak + 1 : 0
        let nameA = HandEvaluator.name(of: scoreA)
        let nameB = HandEvaluator.name(of: scoreB)
        switch truth {
        case .a: verdict = "Hand A wins: \(nameA) beats \(nameB)."
        case .b: verdict = "Hand B wins: \(nameB) beats \(nameA)."
        case .tie: verdict = "It's a tie — both play \(nameA)."
        }
    }
}

// MARK: - Position explorer

struct PositionExplorerView: View {
    @State private var hole: [Card] = [Card(13, .spades), Card(11, .diamonds)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader("TRY IT — SAME HAND, EVERY SEAT")

            HStack {
                HStack(spacing: 5) {
                    ForEach(hole) { CardView(face: .up($0), width: 44) }
                }
                Text("facing a raise to 60\nblinds 10/20")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    var deck = Deck.shuffled()
                    hole = [deck.removeLast(), deck.removeLast()]
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
            }

            VStack(spacing: 6) {
                ForEach(Position.allCases, id: \.self) { position in
                    let advice = Coach.preflopAdvice(hole: hole, toCall: 60, bigBlind: 20, position: position)
                    HStack {
                        Text(positionLabel(position))
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                        Spacer()
                        Text(advice.action.rawValue)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(color(advice.action)))
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemGroupedBackground)))

            Text("Watch marginal hands flip from fold to play as your seat improves.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func positionLabel(_ position: Position) -> String {
        switch position {
        case .early: return "Under the gun"
        case .smallBlind: return "Small blind"
        case .bigBlind: return "Big blind"
        case .button: return "Button"
        }
    }

    private func color(_ action: CoachAction) -> Color {
        switch action {
        case .fold: return .red
        case .check, .call: return .blue
        case .bet, .raise: return .green
        }
    }
}

// MARK: - Shared

private func widgetHeader(_ text: String) -> some View {
    Label(text, systemImage: "hand.tap")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.green)
}
