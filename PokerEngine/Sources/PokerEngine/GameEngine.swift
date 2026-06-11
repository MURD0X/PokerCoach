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
    public var hole: [Card] = []
    public var folded = false
    public var allIn = false
    public var betThisRound = 0
    public var totalBet = 0
    public var hasActed = false
    public var lastAction = ""
}

/// Four-handed no-limit Texas Hold'em. UI-agnostic: publishes changes via
/// `onChange`, requests the hero's decision via `heroActionProvider`.
@MainActor
public final class GameEngine {
    public static let smallBlind = 10
    public static let bigBlind = 20
    public static let startingStack = 1000

    public private(set) var players: [Player]
    public private(set) var board: [Card] = []
    public private(set) var stage: Stage = .idle
    public private(set) var currentBet = 0
    public private(set) var minRaise = GameEngine.bigBlind
    public private(set) var dealerIndex: Int
    public private(set) var handNumber = 0
    public private(set) var log: [LogEntry] = []
    public private(set) var actingIndex: Int?

    /// Set by the UI layer; suspends the engine until the hero decides.
    public var heroActionProvider: (() async -> HeroAction)?
    public var onChange: (() -> Void)?
    /// AI "thinking" delay; set to zero in tests.
    public var aiDelay: Duration = .milliseconds(800)

    private var deck: [Card] = []
    private var logCounter = 0

    public init(opponentNames: [String] = ["Maya", "Dmitri", "Rosa"]) {
        var all = [Player(id: 0, name: "You", isHero: true, stack: GameEngine.startingStack)]
        for (i, name) in opponentNames.enumerated() {
            all.append(Player(id: i + 1, name: name, isHero: false, stack: GameEngine.startingStack))
        }
        players = all
        dealerIndex = Int.random(in: 0..<all.count)
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

    public func playHand() async {
        handNumber += 1
        board = []
        deck = Deck.shuffled()
        currentBet = 0
        minRaise = GameEngine.bigBlind

        for i in players.indices {
            if players[i].stack == 0 { // rebuy so the lesson continues
                players[i].stack = GameEngine.startingStack
                emit("\(players[i].name) rebuys for \(GameEngine.startingStack) chips.", .info)
            }
            players[i].hole = [deck.removeLast(), deck.removeLast()]
            players[i].folded = false
            players[i].allIn = false
            players[i].betThisRound = 0
            players[i].totalBet = 0
            players[i].hasActed = false
            players[i].lastAction = ""
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
                emit("\(players[winnerIdx].name) wins \(pot) — everyone else folded.", .win)
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

    private func aiDecision(for index: Int) -> HeroAction {
        let p = players[index]
        let toCall = currentBet - p.betThisRound
        let opponents = players.filter { $0.id != p.id && !$0.folded }.count
        let pot = totalPot

        if stage == .preflop {
            let score = Chen.score(p.hole)
            let loose = Int.random(in: 0..<100) < 12 // occasional speculative play
            if score >= 10 || (score >= 8 && toCall <= GameEngine.bigBlind) {
                if toCall > p.stack / 3 && score < 12 { return .checkCall }
                return .raise(to: min(currentBet + max(minRaise, pot), p.betThisRound + p.stack))
            }
            if score >= 6 && toCall <= 3 * GameEngine.bigBlind { return .checkCall }
            if loose && toCall <= 2 * GameEngine.bigBlind { return .checkCall }
            return toCall == 0 ? .checkCall : .fold
        }

        let equity = Equity.estimate(hole: p.hole, board: board, opponents: opponents, trials: 150).decisionEquity
        let potOdds = toCall > 0 ? Double(toCall) / Double(pot + toCall) : 0
        let bluff = Int.random(in: 0..<100) < 8
        if toCall == 0 {
            if equity > 0.62 || bluff {
                return .raise(to: max(minRaise, pot / 2))
            }
            return .checkCall
        }
        if equity > potOdds + 0.25 && equity > 0.55 {
            return .raise(to: min(currentBet + max(minRaise, pot), p.betThisRound + p.stack))
        }
        if equity > potOdds || (bluff && toCall < p.stack / 8) { return .checkCall }
        return .fold
    }

    private func apply(_ action: HeroAction, to index: Int) {
        let toCall = currentBet - players[index].betThisRound
        players[index].hasActed = true
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
        for p in players where !p.folded {
            let score = HandEvaluator.bestScore(p.hole + board)
            emit("\(p.name) shows \(p.hole.map(\.text).joined(separator: " ")) — \(HandEvaluator.name(of: score)).")
        }
        let pots = GameEngine.buildPots(contributions: players.map { ($0.totalBet, $0.folded, $0.id) })
        for i in players.indices { players[i].totalBet = 0 }

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
            }
            let label = pots.count > 1 ? (potIndex == 0 ? "main pot" : "side pot \(potIndex)") : "the pot"
            let names = winners.map { players[$0].name }.joined(separator: " and ")
            emit("\(names) win\(winners.count == 1 ? "s" : "") \(label) of \(pot.amount) with \(HandEvaluator.name(of: bestScore)).", .win)
        }
        notify()
    }
}
