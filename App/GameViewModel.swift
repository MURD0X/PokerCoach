import SwiftUI
import PokerEngine

struct StreetEquity: Identifiable {
    let order: Int
    let street: String
    let value: Double
    var id: Int { order }
}

struct SessionStats {
    var handsPlayed = 0
    var biggestPotWon = 0
    var decisionsTotal = 0
    var decisionsFollowed = 0

    var adherencePercent: Int? {
        guard decisionsTotal > 0 else { return nil }
        return Int((Double(decisionsFollowed) / Double(decisionsTotal) * 100).rounded())
    }
}

struct HandStats {
    var equity: EquityResult
    var outs: [OutInfo]
    var madeHandName: String
    var category: HandCategory
    var opponents: Int
}

@MainActor
final class GameViewModel: ObservableObject {
    let engine = GameEngine()

    @Published var isHeroTurn = false
    @Published var advice: CoachAdvice?
    @Published var stats: HandStats?
    @Published var equityHistory: [StreetEquity] = []
    @Published var isHandRunning = false
    @Published var session = SessionStats()
    @Published var showBustSheet = false

    private var pendingAction: CheckedContinuation<HeroAction, Never>?
    private var statsTask: Task<Void, Never>?
    private var lastStatsKey = ""

    static let streetOrder: [Stage: (Int, String)] = [
        .preflop: (0, "Pre"), .flop: (1, "Flop"), .turn: (2, "Turn"), .river: (3, "River"),
    ]

    init() {
        applyAISpeed()
        engine.onChange = { [weak self] in
            self?.objectWillChange.send()
            self?.refreshStatsIfNeeded()
        }
        engine.heroActionProvider = { [weak self] in
            await self?.heroTurn() ?? .checkCall
        }
    }

    func dealHand() {
        guard !isHandRunning else { return }
        guard !engine.heroBusted else {
            showBustSheet = true
            return
        }
        isHandRunning = true
        equityHistory = []
        stats = nil
        advice = nil
        lastStatsKey = ""
        Task {
            await engine.playHand()
            isHandRunning = false
            isHeroTurn = false
            recordHandOutcome()
            if engine.heroBusted { showBustSheet = true }
        }
    }

    private func recordHandOutcome() {
        session.handsPlayed = engine.handNumber
        guard let result = engine.lastResult else { return }
        let heroWinnings: Int
        if result.wonByFolds {
            heroWinnings = result.winnerNames.contains("You") ? result.potTotal : 0
        } else {
            heroWinnings = result.showdowns.first { $0.playerID == 0 }?.amountWon ?? 0
        }
        session.biggestPotWon = max(session.biggestPotWon, heroWinnings)
    }

    // The recommendation is "followed" when the hero's action falls in the
    // same family as the coach's: check/call ↔ checkCall, bet/raise ↔ raise.
    private func actionMatchesAdvice(_ action: HeroAction, _ recommendation: CoachAction) -> Bool {
        switch (recommendation, action) {
        case (.fold, .fold): return true
        case (.check, .checkCall), (.call, .checkCall): return true
        case (.bet, .raise(_)), (.raise, .raise(_)): return true
        default: return false
        }
    }

    private func heroTurn() async -> HeroAction {
        isHeroTurn = true
        computeAdvice()
        if ProcessInfo.processInfo.arguments.contains("-autopilot") {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.perform(.checkCall)
            }
        }
        return await withCheckedContinuation { pendingAction = $0 }
    }

    func perform(_ action: HeroAction) {
        guard let continuation = pendingAction else { return }
        if let advice {
            session.decisionsTotal += 1
            if actionMatchesAdvice(action, advice.action) { session.decisionsFollowed += 1 }
        }
        pendingAction = nil
        isHeroTurn = false
        advice = nil
        continuation.resume(returning: action)
    }

    // MARK: - Live stats

    private func refreshStatsIfNeeded() {
        guard let (order, street) = Self.streetOrder[engine.stage],
              engine.hero.hole.count == 2, !engine.hero.folded,
              engine.activeOpponentCount > 0
        else { return }

        let key = "\(engine.handNumber)-\(engine.board.count)-\(engine.activeOpponentCount)"
        guard key != lastStatsKey else { return }
        lastStatsKey = key

        let hole = engine.hero.hole
        let board = engine.board
        let opponents = engine.activeOpponentCount

        statsTask?.cancel()
        statsTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                let equity = Equity.estimate(hole: hole, board: board, opponents: opponents, trials: 2500)
                let outs = Outs.compute(hole: hole, board: board)
                let score = board.isEmpty ? 0 : HandEvaluator.bestScore(hole + board)
                return (equity, outs, score)
            }.value
            guard !Task.isCancelled, let self else { return }

            let madeName = board.isEmpty ? Chen.describe(hole) : HandEvaluator.name(of: result.2)
            let category: HandCategory = board.isEmpty ? .highCard : HandEvaluator.category(of: result.2)
            self.stats = HandStats(
                equity: result.0, outs: board.isEmpty ? [] : result.1,
                madeHandName: madeName, category: category, opponents: opponents
            )
            let entry = StreetEquity(order: order, street: street, value: result.0.decisionEquity)
            if let idx = self.equityHistory.firstIndex(where: { $0.order == order }) {
                self.equityHistory[idx] = entry
            } else {
                self.equityHistory.append(entry)
                self.equityHistory.sort { $0.order < $1.order }
            }
        }
    }

    private func computeAdvice() {
        let hole = engine.hero.hole
        let board = engine.board
        let toCall = engine.heroToCall
        let pot = engine.totalPot
        let opponents = engine.activeOpponentCount

        if board.isEmpty {
            advice = Coach.preflopAdvice(hole: hole, toCall: toCall, bigBlind: GameEngine.bigBlind)
            return
        }
        Task { [weak self] in
            // Reuse the dashboard's equity if it's for this exact spot.
            let equity: EquityResult
            let outs: [OutInfo]
            if let stats = self?.stats, stats.opponents == opponents, self?.engine.board.count == board.count {
                equity = stats.equity
                outs = stats.outs
            } else {
                (equity, outs) = await Task.detached(priority: .userInitiated) {
                    (Equity.estimate(hole: hole, board: board, opponents: opponents, trials: 1500),
                     Outs.compute(hole: hole, board: board))
                }.value
            }
            guard let self, self.isHeroTurn else { return }
            self.advice = Coach.postflopAdvice(
                hole: hole, board: board, equity: equity,
                toCall: toCall, pot: pot, opponents: opponents, outs: outs
            )
        }
    }

    func applyAISpeed() {
        engine.aiDelay = AISpeed.current.delay
    }

    func newTable() {
        guard !isHandRunning else { return }
        engine.newTable()
        stats = nil
        advice = nil
        equityHistory = []
        lastStatsKey = ""
        session = SessionStats()
        showBustSheet = false
    }

    // MARK: - Bet sizing for the controls

    var heroToCall: Int { engine.heroToCall }

    struct RaiseOption: Identifiable {
        let label: String
        let to: Int
        var id: String { label }
    }

    var raiseOptions: [RaiseOption] {
        let hero = engine.hero
        let pot = engine.totalPot
        let minTo = engine.currentBet + engine.minRaise
        let maxTo = hero.betThisRound + hero.stack
        guard maxTo > engine.currentBet else { return [] }
        let verb = engine.currentBet == 0 ? "Bet" : "Raise"

        var options: [RaiseOption] = []
        let halfTo = min(max(minTo, engine.currentBet + pot / 2), maxTo)
        let potTo = min(max(minTo, engine.currentBet + pot), maxTo)
        if halfTo < maxTo { options.append(RaiseOption(label: "\(verb) \(halfTo) · ½ pot", to: halfTo)) }
        if potTo < maxTo && potTo > halfTo { options.append(RaiseOption(label: "\(verb) \(potTo) · pot", to: potTo)) }
        options.append(RaiseOption(label: "All-in \(maxTo)", to: maxTo))
        return options
    }
}
