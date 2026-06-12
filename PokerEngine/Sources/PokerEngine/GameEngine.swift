import Foundation

public enum Stage: String, Sendable {
    case idle, preflop, flop, turn, river, showdown, done
}

public enum LogKind: Sendable {
    case normal, header, street, win, info
}

public struct LogEntry: Identifiable, Sendable {
    public let id: Int
    public let text: String
    public let kind: LogKind
}

public enum HeroAction: Sendable {
    case fold
    case checkCall
    case raise(to: Int)
}

public struct Player: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let isHero: Bool
    public var stack: Int
    public var personality: Personality? = nil
    public var hole: [Card] = []
    public var folded = false
    public var allIn = false
    public var betThisRound = 0
    public var totalBet = 0
    public var hasActed = false
    public var lastAction = ""
    // Observation counters that drive the gradual style reveal.
    public var handsSeen = 0
    public var observedActions = 0
    public var showdownsShown = 0
}

/// What the player has learned about an opponent so far. Traits stay hidden
/// (nil) until enough evidence accumulates, like building a read at a real
/// table.
public struct StyleReveal: Sendable {
    public let tightness: String?
    public let aggression: String?
    public let skill: String?

    public var summary: String {
        [tightness, aggression, skill].map { $0 ?? "?" }.joined(separator: " · ")
    }
    public var anythingKnown: Bool {
        tightness != nil || aggression != nil || skill != nil
    }
}

/// Four-handed no-limit Texas Hold'em. UI-agnostic: publishes changes via
/// `onChange`, requests the hero's decision via `heroActionProvider`.
@MainActor
public final class GameEngine {
    public nonisolated static let smallBlind = 10
    public nonisolated static let bigBlind = 20
    public nonisolated static let startingStack = 1000

    public private(set) var players: [Player]
    public private(set) var board: [Card] = []
    public private(set) var stage: Stage = .idle
    public private(set) var currentBet = 0
    public private(set) var minRaise = GameEngine.bigBlind
    public private(set) var dealerIndex: Int
    public private(set) var handNumber = 0
    public private(set) var log: [LogEntry] = []
    public private(set) var actingIndex: Int?
    public private(set) var lastResult: HandResult?

    /// Set by the UI layer; suspends the engine until the hero decides.
    public var heroActionProvider: (() async -> HeroAction)?
    public var onChange: (() -> Void)?
    /// AI "thinking" delay; set to zero in tests.
    public var aiDelay: Duration = .milliseconds(800)

    private var deck: [Card] = []
    private var logCounter = 0

    public init(opponents: [(name: String, personality: Personality)] = OpponentFactory.randomLineup(count: 3)) {
        players = GameEngine.lineup(opponents: opponents)
        dealerIndex = Int.random(in: 0..<players.count)
    }

    private nonisolated static func lineup(opponents: [(name: String, personality: Personality)]) -> [Player] {
        var all = [Player(id: 0, name: "You", isHero: true, stack: GameEngine.startingStack)]
        for (i, opp) in opponents.enumerated() {
            var p = Player(id: i + 1, name: opp.name, isHero: false, stack: GameEngine.startingStack)
            p.personality = opp.personality
            all.append(p)
        }
        return all
    }

    /// Replace the opposition with fresh random players and reset the table.
    /// Random re-rolls never repeat a current opponent's name, so the new
    /// table is visibly different. No-op while a hand is in progress.
    public func newTable(opponents: [(name: String, personality: Personality)]? = nil) {
        guard stage == .idle || stage == .done else { return }
        let currentNames = Set(players.dropFirst().map(\.name))
        let next = opponents ?? OpponentFactory.randomLineup(count: 3, excluding: currentNames)
        players = GameEngine.lineup(opponents: next)
        dealerIndex = Int.random(in: 0..<players.count)
        board = []
        stage = .idle
        currentBet = 0
        minRaise = GameEngine.bigBlind
        handNumber = 0
        log = []
        logCounter = 0
        actingIndex = nil
        lastResult = nil
        emit("A new table — three unfamiliar opponents sit down. Watch how they play.", .info)
        notify()
    }

    /// Style traits revealed so far for an opponent, based on hands observed
    /// (tight/loose), decisions seen (passive/aggressive), and showdowns
    /// where their cards were exposed (skill).
    public func styleReveal(for id: Int) -> StyleReveal {
        guard id != 0, let p = players.first(where: { $0.id == id }), let pers = p.personality else {
            return StyleReveal(tightness: nil, aggression: nil, skill: nil)
        }
        return StyleReveal(
            tightness: p.handsSeen >= 8 ? pers.tightnessLabel : nil,
            aggression: p.observedActions >= 10 ? pers.aggressionLabel : nil,
            skill: p.showdownsShown >= 3 ? pers.skillLabel : nil
        )
    }

    public var hero: Player { players[0] }

    public var totalPot: Int { players.reduce(0) { $0 + $1.totalBet } }

    public var heroToCall: Int {
        max(0, min(currentBet - players[0].betThisRound, players[0].stack))
    }

    public var activeOpponentCount: Int {
        players.dropFirst().filter { !$0.folded }.count
    }

    private func emit(_ text: String, _ kind: LogKind = .normal) {
        logCounter += 1
        log.append(LogEntry(id: logCounter, text: text, kind: kind))
        if log.count > 200 { log.removeFirst(log.count - 200) }
        onChange?()
    }

    private func notify() { onChange?() }

    /// Test hook: force a stack value to exercise bust paths quickly.
    func setStackForTesting(_ amount: Int, seat: Int) {
        players[seat].stack = amount
    }

    /// True when the hero has no chips left — the session is over and the
    /// engine will refuse to deal until a new table is seated or the hero
    /// buys back in.
    public var heroBusted: Bool { players[0].stack == 0 }

    /// Hero buys back in at the same table: same opponents, reads intact.
    /// Only valid between hands while busted; the app layer charges the
    /// bankroll before calling.
    public func rebuyHero() {
        guard heroBusted, stage == .idle || stage == .done else { return }
        players[0].stack = GameEngine.startingStack
        emit("You buy back in for \(GameEngine.startingStack) chips.", .info)
        notify()
    }

    public func playHand() async {
        guard !heroBusted else { return }
        handNumber += 1
        board = []
        deck = Deck.shuffled()
        currentBet = 0
        minRaise = GameEngine.bigBlind
        lastResult = nil

        for i in players.indices {
            if players[i].stack == 0 { // busted opponents leave; someone new sits down
                let departing = players[i].name
                let exclude = Set(players.map(\.name))
                let arrival = OpponentFactory.randomLineup(count: 1, excluding: exclude)[0]
                var seat = Player(id: players[i].id, name: arrival.name, isHero: false, stack: GameEngine.startingStack)
                seat.personality = arrival.personality
                players[i] = seat
                emit("\(departing) busts and leaves the table. \(arrival.name) takes the seat.", .info)
            }
            players[i].hole = [deck.removeLast(), deck.removeLast()]
            players[i].folded = false
            players[i].allIn = false
            players[i].betThisRound = 0
            players[i].totalBet = 0
            players[i].hasActed = false
            players[i].lastAction = ""
            players[i].handsSeen += 1
        }

        dealerIndex = (dealerIndex + 1) % players.count
        let sb = (dealerIndex + 1) % players.count
        let bb = (dealerIndex + 2) % players.count

        emit("— Hand #\(handNumber) — \(players[dealerIndex].name) has the dealer button.", .header)
        pay(sb, GameEngine.smallBlind)
        players[sb].lastAction = "SB \(GameEngine.smallBlind)"
        pay(bb, GameEngine.bigBlind)
        players[bb].lastAction = "BB \(GameEngine.bigBlind)"
        currentBet = GameEngine.bigBlind
        emit("\(players[sb].name) posts small blind \(GameEngine.smallBlind), \(players[bb].name) posts big blind \(GameEngine.bigBlind).")

        let streets: [(Stage, Int, Int)] = [
            (.preflop, 0, (bb + 1) % players.count),
            (.flop, 3, sb),
            (.turn, 1, sb),
            (.river, 1, sb),
        ]

        for (street, dealCount, startIndex) in streets {
            stage = street
            if dealCount > 0 {
                deck.removeLast() // burn card, as in a live game
                for _ in 0..<dealCount { board.append(deck.removeLast()) }
                emit("\(street.rawValue.capitalized): \(board.map(\.text).joined(separator: " "))", .street)
                currentBet = 0
                minRaise = GameEngine.bigBlind
                for i in players.indices {
                    players[i].betThisRound = 0
                    players[i].hasActed = false
                    if !players[i].folded && !players[i].allIn { players[i].lastAction = "" }
                }
            }
            notify()
            if await bettingRound(startIndex: startIndex) == false {
                // Everyone else folded.
                let winnerIdx = players.firstIndex { !$0.folded }!
                let pot = totalPot
                players[winnerIdx].stack += pot
                for i in players.indices { players[i].totalBet = 0 }
                let winner = players[winnerIdx].name
                lastResult = HandResult(
                    potTotal: pot, showdowns: [], winnerNames: [winner],
                    headline: "\(winner) win\(winnerIdx == 0 ? "" : "s") \(pot) — everyone else folded",
                    explanation: nil, winningCards: []
                )
                emit("\(winner) wins \(pot) — everyone else folded.", .win)
                stage = .done
                actingIndex = nil
                notify()
                return
            }
        }

        showdown()
        stage = .done
        actingIndex = nil
        notify()
    }

    @discardableResult
    private func pay(_ index: Int, _ amount: Int) -> Int {
        let paid = min(amount, players[index].stack)
        players[index].stack -= paid
        players[index].betThisRound += paid
        players[index].totalBet += paid
        if players[index].stack == 0 { players[index].allIn = true }
        return paid
    }

    /// Returns false if the hand ended because all but one player folded.
    private func bettingRound(startIndex: Int) async -> Bool {
        var index = startIndex
        while true {
            if players.filter({ !$0.folded }).count == 1 { return false }
            let canAct = players.filter { !$0.folded && !$0.allIn }
            if canAct.isEmpty { break }
            if canAct.allSatisfy({ $0.hasActed && $0.betThisRound == currentBet }) { break }
            if canAct.count == 1, canAct[0].hasActed, canAct[0].betThisRound >= currentBet { break }

            if !players[index].folded && !players[index].allIn {
                actingIndex = index
                notify()
                if players[index].isHero {
                    let action = await heroActionProvider?() ?? .checkCall
                    apply(action, to: index)
                } else {
                    if aiDelay > .zero { try? await Task.sleep(for: aiDelay) }
                    apply(aiDecision(for: index), to: index)
                }
                actingIndex = nil
                notify()
            }
            index = (index + 1) % players.count
        }
        return true
    }

    func aiDecision(for index: Int) -> HeroAction {
        let p = players[index]
        let pers = p.personality ?? .balanced
        let toCall = currentBet - p.betThisRound
        let opponents = players.filter { $0.id != p.id && !$0.folded }.count
        let pot = totalPot
        func chance(_ rate: Double) -> Bool { Double.random(in: 0..<1) < rate }
        // Raise sizing scales with aggression: half-pot for the meekest, ~1.3x pot for maniacs.
        func raiseSized() -> HeroAction {
            let size = max(minRaise, Int(Double(pot) * (0.5 + pers.aggression * 0.8)))
            return .raise(to: min(currentBet + size, p.betThisRound + p.stack))
        }

        if stage == .preflop {
            let score = Double(Chen.score(p.hole))
            if score >= pers.preflopRaiseThreshold {
                if toCall > p.stack / 3 && score < 12 { return .checkCall }
                return chance(pers.raiseWithStrengthRate) || toCall == 0 ? raiseSized() : .checkCall
            }
            if score >= pers.preflopCallThreshold && toCall <= 3 * GameEngine.bigBlind {
                return .checkCall
            }
            if chance(pers.speculativeCallRate) && toCall <= 2 * GameEngine.bigBlind { return .checkCall }
            return toCall == 0 ? .checkCall : .fold
        }

        // Skill shapes how accurately they judge their own hand.
        var equity = Equity.estimate(hole: p.hole, board: board, opponents: opponents, trials: pers.equityTrials).decisionEquity
        equity = min(1, max(0, equity + Double.random(in: -1...1) * pers.equityNoise))

        if toCall == 0 {
            if equity > pers.valueBetThreshold || chance(pers.bluffRate) { return raiseSized() }
            return .checkCall
        }
        let potOdds = Double(toCall) / Double(pot + toCall)
        if equity > potOdds + 0.25 && equity > 0.55 {
            return chance(pers.raiseWithStrengthRate) ? raiseSized() : .checkCall
        }
        // Unskilled players discount the price they're being asked to pay.
        if equity > potOdds * pers.potOddsDiscipline { return .checkCall }
        if chance(pers.bluffRate) && toCall < p.stack / 8 { return .checkCall }
        return .fold
    }

    private func apply(_ action: HeroAction, to index: Int) {
        let toCall = currentBet - players[index].betThisRound
        players[index].hasActed = true
        if !players[index].isHero { players[index].observedActions += 1 }
        let name = players[index].name

        switch action {
        case .fold:
            // Folding when checking is free is never right; treat as a check.
            if toCall == 0 {
                players[index].lastAction = "Check"
                emit("\(name) checks.")
                return
            }
            players[index].folded = true
            players[index].lastAction = "Fold"
            emit("\(name) folds.")

        case .checkCall:
            if toCall <= 0 {
                players[index].lastAction = "Check"
                emit("\(name) checks.")
                return
            }
            let paid = pay(index, toCall)
            let allIn = players[index].allIn
            players[index].lastAction = allIn ? "All-in \(players[index].betThisRound)" : "Call \(paid)"
            emit("\(name) calls \(paid)\(allIn ? " and is all-in" : "").")

        case .raise(var to):
            to = min(to, players[index].betThisRound + players[index].stack)
            let minTo = currentBet + minRaise
            if to < minTo && players[index].betThisRound + players[index].stack >= minTo { to = minTo }
            let isBet = currentBet == 0
            pay(index, to - players[index].betThisRound)
            if players[index].betThisRound > currentBet {
                let fullRaise = players[index].betThisRound - currentBet >= minRaise
                if fullRaise {
                    minRaise = players[index].betThisRound - currentBet
                    for i in players.indices where i != index && !players[i].folded && !players[i].allIn {
                        players[i].hasActed = false
                    }
                }
                currentBet = players[index].betThisRound
            }
            let allIn = players[index].allIn
            let total = players[index].betThisRound
            players[index].lastAction = allIn ? "All-in \(total)" : "\(isBet ? "Bet" : "Raise to") \(total)"
            emit("\(name) \(isBet ? "bets" : "raises to") \(total)\(allIn ? " (all-in)" : "").")
        }
    }

    // Side pots: layer contributions so all-in players only contest chips
    // they matched. Static and pure for testability.
    nonisolated static func buildPots(contributions: [(amount: Int, folded: Bool, id: Int)]) -> [(amount: Int, eligible: [Int])] {
        var pots: [(amount: Int, eligible: [Int])] = []
        var remaining = contributions
        while remaining.contains(where: { $0.amount > 0 && !$0.folded }) {
            let level = remaining.filter { $0.amount > 0 && !$0.folded }.map(\.amount).min()!
            var amount = 0
            var eligible: [Int] = []
            for i in remaining.indices {
                let take = min(remaining[i].amount, level)
                amount += take
                remaining[i].amount -= take
                if !remaining[i].folded && take == level { eligible.append(remaining[i].id) }
            }
            pots.append((amount, eligible))
        }
        let leftover = remaining.reduce(0) { $0 + $1.amount }
        if leftover > 0 && !pots.isEmpty { pots[pots.count - 1].amount += leftover }
        return pots
    }

    private func showdown() {
        stage = .showdown
        emit("Showdown!", .street)
        for i in players.indices where !players[i].folded {
            let score = HandEvaluator.bestScore(players[i].hole + board)
            emit("\(players[i].name) shows \(players[i].hole.map(\.text).joined(separator: " ")) — \(HandEvaluator.name(of: score)).")
            if !players[i].isHero { players[i].showdownsShown += 1 }
        }
        let potTotal = totalPot
        let pots = GameEngine.buildPots(contributions: players.map { ($0.totalBet, $0.folded, $0.id) })
        for i in players.indices { players[i].totalBet = 0 }

        var amountWon: [Int: Int] = [:]
        for (potIndex, pot) in pots.enumerated() {
            var bestScore = -1
            for id in pot.eligible {
                let s = HandEvaluator.bestScore(players[id].hole + board)
                if s > bestScore { bestScore = s }
            }
            let winners = pot.eligible.filter { HandEvaluator.bestScore(players[$0].hole + board) == bestScore }
            let share = pot.amount / winners.count
            var remainder = pot.amount - share * winners.count
            for id in winners {
                let extra = remainder > 0 ? 1 : 0
                remainder -= extra
                players[id].stack += share + extra
                amountWon[id, default: 0] += share + extra
            }
            let label = pots.count > 1 ? (potIndex == 0 ? "main pot" : "side pot \(potIndex)") : "the pot"
            let names = winners.map { players[$0].name }.joined(separator: " and ")
            emit("\(names) win\(winners.count == 1 ? "s" : "") \(label) of \(pot.amount) with \(HandEvaluator.name(of: bestScore)).", .win)
        }

        lastResult = composeShowdownResult(potTotal: potTotal, amountWon: amountWon)
        notify()
    }

    private func composeShowdownResult(potTotal: Int, amountWon: [Int: Int]) -> HandResult {
        var showdowns: [HandResult.PlayerShowdown] = []
        for p in players where !p.folded {
            let (score, bestFive) = HandEvaluator.best(p.hole + board)
            showdowns.append(HandResult.PlayerShowdown(
                playerID: p.id, name: p.name, hole: p.hole,
                handName: HandEvaluator.name(of: score), score: score,
                bestFive: bestFive, amountWon: amountWon[p.id] ?? 0
            ))
        }
        showdowns.sort { $0.amountWon != $1.amountWon ? $0.amountWon > $1.amountWon : $0.score > $1.score }

        let winners = showdowns.filter(\.isWinner)
        let losers = showdowns.filter { !$0.isWinner }
        let winnerNames = winners.map(\.name)
        let top = winners[0]

        let headline: String
        if winners.count > 1 && winners.allSatisfy({ $0.score == top.score }) {
            headline = "\(winnerNames.joined(separator: " and ")) split the pot of \(potTotal) with \(top.handName)"
        } else if winners.count > 1 {
            // Different winners across side pots.
            headline = "\(top.name) win\(top.playerID == 0 ? "" : "s") \(top.amountWon) with \(top.handName)"
        } else {
            headline = "\(top.name) win\(top.playerID == 0 ? "" : "s") \(top.amountWon) with \(top.handName)"
        }

        var explanation: String?
        if let bestLoser = losers.max(by: { $0.score < $1.score }), bestLoser.score < top.score {
            explanation = HandResult.comparisonLine(winnerScore: top.score, loserScore: bestLoser.score)
        }

        return HandResult(
            potTotal: potTotal, showdowns: showdowns, winnerNames: winnerNames,
            headline: headline, explanation: explanation,
            winningCards: Set(winners.flatMap(\.bestFive))
        )
    }
}
