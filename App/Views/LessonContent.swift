import SwiftUI
import PokerEngine

// The curriculum, organized by topic. Each topic is its own destination so
// the table of contents links and the coach's Learn-more chips can land on
// exactly the right page.
struct LessonBlock: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

enum LessonContent {
    static let sections: [(header: String, topics: [LessonTopic])] = [
        ("The basics", [.gameFlow, .handRankings]),
        ("The math", [.chen, .potOdds, .outs]),
        ("Strategy", [.position, .readingPlayers, .bankroll]),
        ("Trust", [.fairness]),
    ]

    static func subtitle(for topic: LessonTopic) -> String {
        switch topic {
        case .gameFlow: return "Blinds, streets, and your options"
        case .handRankings: return "What beats what, and why"
        case .chen: return "Scoring your starting hand"
        case .potOdds: return "The price of a call vs. your chances"
        case .outs: return "Counting the cards that save you"
        case .position: return "Why acting last wins money"
        case .readingPlayers: return "The three dials behind every opponent"
        case .bankroll: return "The money behind the table money"
        case .fairness: return "How this app deals cards"
        }
    }

    static func blocks(for topic: LessonTopic) -> [LessonBlock] {
        switch topic {
        case .gameFlow: return [
            LessonBlock(title: "The goal", body: "Make the best possible 5-card hand using any combination of your 2 hidden hole cards and the 5 shared community cards — or bet until everyone else folds."),
            LessonBlock(title: "1. Blinds", body: "The two players left of the dealer button post forced bets so there's always something to win."),
            LessonBlock(title: "2. Preflop", body: "Everyone gets 2 hidden cards. Betting starts left of the big blind."),
            LessonBlock(title: "3. Flop, Turn, River", body: "Community cards arrive: 3, then 1, then 1 — with a betting round after each."),
            LessonBlock(title: "4. Showdown", body: "Remaining players reveal their cards. Best 5-card hand wins the pot."),
            LessonBlock(title: "Your options", body: "Fold (give up), Check (pass if no bet), Call (match the bet), Raise (bet more), or go All-in. Side pots make sure you can only win what you could match."),
        ]
        case .handRankings: return [
            LessonBlock(title: "Ties within a category", body: "Two players with the same category compare card ranks — a pair of Kings beats a pair of Nines, and an Ace-high flush beats a King-high flush."),
            LessonBlock(title: "The Ace plays both ways", body: "An Ace can be high (10-J-Q-K-A) or low (A-2-3-4-5, the \"wheel\"), but straights can't wrap around — Q-K-A-2-3 is nothing."),
        ]
        case .chen: return [
            LessonBlock(title: "What it is", body: "A point system by professional player Bill Chen for judging your two hole cards before the flop. The coach quotes it on every preflop decision."),
            LessonBlock(title: "How to score a hand", body: "Highest card: Ace = 10, King = 8, Queen = 7, Jack = 6; lower cards count half their number. A pair doubles its card's points (minimum 5). Same suit: +2. Gaps cost points: one gap −1, two −2, three −4, wider −5. Connected low cards (gap 0–1, below a Queen) earn +1 for straight potential. Round halves up."),
            LessonBlock(title: "How the coach uses it", body: "10+ points: premium — raise. 8–9: strong. 6–7: playable — see a cheap flop. Below 6: fold to any bet. Your position shifts these thresholds — see the Position lesson."),
        ]
        case .potOdds: return [
            LessonBlock(title: "Equity", body: "Your share of the pot if the hand ran out many times — your probability of winning. The app estimates it by simulating thousands of run-outs against what your opponents' actions say they hold."),
            LessonBlock(title: "Pot odds", body: "Compare the price to the prize. Calling 50 into a pot that will total 200 means you need to win at least 25% of the time to break even."),
            LessonBlock(title: "The golden rule", body: "Call when your win % is higher than the pot-odds %; fold when it's lower. Make this comparison consistently and you profit long-term, even when individual hands lose."),
        ]
        case .outs: return [
            LessonBlock(title: "What's an out?", body: "A card that improves you to (likely) the best hand. A flush draw has 9 outs; an open-ended straight draw has 8; a gutshot has 4."),
            LessonBlock(title: "The rule of 4 and 2", body: "Multiply your outs by 4 on the flop (two cards to come) or 2 on the turn (one card to come) for a quick estimate of your chance to improve by the river."),
            LessonBlock(title: "Outs that count", body: "The app only counts a card as an out when it improves your hand using your hole cards — a card that merely pairs the board helps everyone equally, so it doesn't count."),
        ]
        case .position: return [
            LessonBlock(title: "Why it matters", body: "The dealer button decides who acts last. Acting last means you see everyone's decision before making yours — a real, measurable advantage."),
            LessonBlock(title: "The coach plays position", body: "Preflop thresholds tighten under the gun and loosen on the button. The same hand can be a raise on the button and a fold up front — and the coach will tell you exactly when that's the case."),
            LessonBlock(title: "Rule of thumb", body: "The later your position, the more hands you can play. In early position, stick to strength."),
        ]
        case .readingPlayers: return [
            LessonBlock(title: "Every opponent is different", body: "Each player is rolled on three hidden dials: how picky they are about starting hands (Tight ↔ Loose), how hard they push chips (Passive ↔ Aggressive), and how well they play the math (Rookie / Solid / Expert). The dials genuinely drive every decision they make."),
            LessonBlock(title: "Earning the read", body: "Styles start hidden — the ? · ? · ? under each name. Traits reveal with evidence: hand selection after ~8 hands, betting style after ~10 decisions, skill after 3 showdowns."),
            LessonBlock(title: "Exploiting tight or loose", body: "Against Tight: steal blinds freely, but believe their raises. Against Loose: value-bet more and bluff less — they call too often for bluffs to pay."),
            LessonBlock(title: "Exploiting passive or aggressive", body: "Against Passive: bet whenever they check; respect it when they do bet. Against Aggressive: let them bluff into your strong hands and call down lighter."),
            LessonBlock(title: "Exploiting skill", body: "Against a Rookie: never bluff, value-bet relentlessly. Against an Expert: tighten up and pick your spots."),
            LessonBlock(title: "Reads reset", body: "When a player busts, someone new takes the seat with fresh hidden dials. Knocking out the player you'd figured out has a real cost."),
        ]
        case .bankroll: return [
            LessonBlock(title: "Two kinds of money", body: "Your table stack is what you're risking today; your bankroll is everything behind it. Pros think in bankroll terms — \"down two buy-ins\" — not hand terms."),
            LessonBlock(title: "The 10% guideline", body: "Keep any table's buy-in under about 10% of your bankroll. Then a bad session stings but can't hurt you, and no single table decides your fate. The table picker color-codes this for you."),
            LessonBlock(title: "Walking away", body: "Banking a win — or cutting a loss — is a skill. Busting your stack ends the session; busting your bankroll is the lesson that teaches bankroll management better than any paragraph."),
        ]
        case .fairness: return [
            LessonBlock(title: "Cryptographic shuffle", body: "Every hand uses a fresh 52-card deck shuffled with Fisher–Yates driven by the system's cryptographic random number generator. Every one of the 52! deck orders is equally likely."),
            LessonBlock(title: "No peeking", body: "The AI opponents decide using only their own cards and the public board — exactly like human players. Even the coach's equity numbers use only what you could know."),
            LessonBlock(title: "Bad beats are real", body: "Nothing is rigged for or against you. Losing with the best hand is real poker variance — learning to handle it is part of the game."),
        ]
        }
    }
}

/// "Learn more" chips that deep-link into the lessons.
struct LearnMoreChips: View {
    let topics: [LessonTopic]
    let onOpen: (LessonTopic) -> Void

    var body: some View {
        if !topics.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("LEARN MORE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowChips(topics: topics, onOpen: onOpen)
            }
        }
    }
}

private struct FlowChips: View {
    let topics: [LessonTopic]
    let onOpen: (LessonTopic) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(topics) { topic in
                Button {
                    onOpen(topic)
                } label: {
                    Label(topic.title, systemImage: "book")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.green.opacity(0.14)))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}
