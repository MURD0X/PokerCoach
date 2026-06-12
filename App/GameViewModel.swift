import SwiftUI
import PokerEngine

struct StreetEquity: Identifiable {
    let order: Int
    let street: String
    let value: Double
    var id: Int { order }
}

struct LifetimeStats {
    var sessions = 0
    var hands = 0
    var peakBankroll = BankrollLedger.startingAmount
    var ruins = 0
}

struct ChipFlight: Identifiable, Equatable {
    let id = UUID()
    let seat: Int
    /// false: seat → pot (a bet). true: pot → seat (a win).
    let reverse: Bool
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
    let engine: GameEngine

    static let stakesKey = "tableBigBlind"

    static func persistedStakes() -> TableStakes {
        let bb = UserDefaults.standard.integer(forKey: stakesKey)
        return TableStakes.all.first { $0.bigBlind == bb } ?? .standard
    }

    @Published var isHeroTurn = false
    @Published var advice: CoachAdvice?
    @Published var stats: HandStats?
    @Published var equityHistory: [StreetEquity] = []
    @Published var isHandRunning = false
    @Published var session = SessionStats()
    @Published var chipFlights: [ChipFlight] = []
    @Published var showBustSheet = false
    @Published var bankroll = BankrollLedger()
    @Published var showRuinSheet = false
    private var pendingSeat: (() -> Void)?

    private enum Keys {
        static let balance = "bankrollBalance"
        static let lastTableStack = "lastTableStack"
        static let sessions = "lifetimeSessions"
        static let hands = "lifetimeHands"
        static let peak = "lifetimePeakBankroll"
        static let ruins = "lifetimeRuins"
    }

    var lifetime: LifetimeStats {
        let d = UserDefaults.standard
        return LifetimeStats(
            sessions: d.integer(forKey: Keys.sessions),
            hands: d.integer(forKey: Keys.hands),
            peakBankroll: max(d.integer(forKey: Keys.peak), BankrollLedger.startingAmount),
            ruins: d.integer(forKey: Keys.ruins)
        )
    }

    private var pendingAction: CheckedContinuation<HeroAction, Never>?
    private var statsTask: Task<Void, Never>?
    private var lastStatsKey = ""

    static let streetOrder: [Stage: (Int, String)] = [
        .preflop: (0, "Pre"), .flop: (1, "Flop"), .turn: (2, "Turn"), .river: (3, "River"),
    ]

    init() {
        engine = GameEngine(stakes: GameViewModel.persistedStakes())
        applyAISpeed()
        engine.onChange = { [weak self] in
            guard let self else { return }
            self.playTransitionSounds()
            self.objectWillChange.send()
            self.refreshStatsIfNeeded()
            // Continuous snapshot of table money so a killed app settles up
            // correctly on next launch (stack + chips committed to the pot).
            UserDefaults.standard.set(
                self.engine.hero.stack + self.engine.hero.totalBet,
                forKey: Keys.lastTableStack
            )
        }
        engine.heroActionProvider = { [weak self] in
            await self?.heroTurn() ?? .checkCall
        }

        // Settle the previous launch's table, then pay for today's seat.
        let d = UserDefaults.standard
        var ledger = BankrollLedger(balance: d.object(forKey: Keys.balance) == nil
            ? BankrollLedger.startingAmount : d.integer(forKey: Keys.balance))
        ledger.cashOut(d.integer(forKey: Keys.lastTableStack))
        d.set(0, forKey: Keys.lastTableStack)
        bankroll = ledger
        chargeForSeat { [weak self] in self?.bumpSessions() }
    }

    private func saveBankroll() {
        let d = UserDefaults.standard
        d.set(bankroll.balance, forKey: Keys.balance)
        if bankroll.balance > d.integer(forKey: Keys.peak) {
            d.set(bankroll.balance, forKey: Keys.peak)
        }
    }

    private func bumpSessions() {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: Keys.sessions) + 1, forKey: Keys.sessions)
    }

    private func snapshotTableStack() {
        UserDefaults.standard.set(
            engine.hero.stack + engine.hero.totalBet,
            forKey: Keys.lastTableStack
        )
    }

    // Pays the buy-in, or raises the ruin sheet and parks the intent until
    // the player takes a fresh bankroll. Snapshots the table money right
    // after seating so a launch-and-quit never loses the buy-in.
    private func chargeForSeat(_ amount: Int? = nil, then proceed: @escaping () -> Void) {
        let cost = amount ?? engine.stakes.buyIn
        if bankroll.chargeBuyIn(cost) {
            saveBankroll()
            proceed()
            snapshotTableStack()
        } else {
            pendingSeat = { [weak self] in
                guard let self else { return }
                self.bankroll.chargeBuyIn(cost)
                self.saveBankroll()
                proceed()
                self.snapshotTableStack()
            }
            showRuinSheet = true
        }
    }

    func acceptFreshBankroll() {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: Keys.ruins) + 1, forKey: Keys.ruins)
        bankroll.resetAfterRuin()
        saveBankroll()
        showRuinSheet = false
        pendingSeat?()
        pendingSeat = nil
    }

    func buyBackIn() {
        showBustSheet = false
        chargeForSeat { [weak self] in
            self?.engine.rebuyHero()
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

    private var lastBoardCount = 0
    private var lastPot = 0
    private var lastHandNumber = 0
    private var lastSeatBets: [Int] = []

    private func launchChipFlight(seat: Int, reverse: Bool) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let flight = ChipFlight(seat: seat, reverse: reverse)
        chipFlights.append(flight)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            self?.chipFlights.removeAll { $0.id == flight.id }
        }
    }

    private func playTransitionSounds() {
        // Chip flights: any seat whose round-bet grew just put chips in.
        let bets = engine.players.map(\.betThisRound)
        if lastSeatBets.count == bets.count, lastHandNumber == engine.handNumber {
            for (seat, bet) in bets.enumerated() where bet > lastSeatBets[seat] {
                launchChipFlight(seat: seat, reverse: false)
            }
        }
        lastSeatBets = bets
        if engine.stage == .done, let result = engine.lastResult, lastPot != 0 {
            for name in result.winnerNames {
                if let seat = engine.players.firstIndex(where: { $0.name == name }) {
                    launchChipFlight(seat: seat, reverse: true)
                }
            }
        }
        if engine.board.count > lastBoardCount || engine.handNumber != lastHandNumber {
            if engine.handNumber != lastHandNumber || engine.board.count > lastBoardCount {
                SoundManager.shared.play(.cardDeal)
            }
        }
        let pot = engine.totalPot
        if pot > lastPot, lastHandNumber == engine.handNumber {
            SoundManager.shared.play(.chipClink)
        }
        if engine.stage == .done, let result = engine.lastResult,
           result.winnerNames.contains("You"), lastPot != 0 {
            SoundManager.shared.play(.winChime)
            SoundManager.shared.winHaptic()
        }
        lastBoardCount = engine.board.count
        lastPot = engine.stage == .done ? 0 : pot
        lastHandNumber = engine.handNumber
    }

    private func recordHandOutcome() {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: Keys.hands) + 1, forKey: Keys.hands)
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
        SoundManager.shared.heroTurnHaptic()
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

        let constraints = engine.observedConstraints()
        let constraintKey = constraints.map { "\($0.minChen ?? -1)" }.joined(separator: ",")
        let key = "\(engine.handNumber)-\(engine.board.count)-\(engine.activeOpponentCount)-\(constraintKey)"
        guard key != lastStatsKey else { return }
        lastStatsKey = key

        let hole = engine.hero.hole
        let board = engine.board
        let opponents = engine.activeOpponentCount

        statsTask?.cancel()
        statsTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                let equity = Equity.estimate(hole: hole, board: board, opponents: opponents, trials: 2500, constraints: constraints)
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
            advice = Coach.preflopAdvice(hole: hole, toCall: toCall, bigBlind: GameEngine.bigBlind, position: engine.heroPosition)
            return
        }
        let constraints = engine.observedConstraints()
        Task { [weak self] in
            // Always fresh at the decision moment: the opponents' actions
            // (and therefore their ranges) may have changed since the
            // dashboard stats were computed.
            let (equity, outs) = await Task.detached(priority: .userInitiated) {
                (Equity.estimate(hole: hole, board: board, opponents: opponents, trials: 1500, constraints: constraints),
                 Outs.compute(hole: hole, board: board))
            }.value
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

    func newTable(stakes: TableStakes? = nil) {
        guard !isHandRunning else { return }
        let target = stakes ?? engine.stakes
        UserDefaults.standard.set(target.bigBlind, forKey: GameViewModel.stakesKey)
        // Cash out the current seat, then pay for the next one.
        bankroll.cashOut(engine.hero.stack)
        saveBankroll()
        showBustSheet = false
        chargeForSeat(target.buyIn) { [weak self] in
            guard let self else { return }
            self.engine.newTable(stakes: target)
            self.stats = nil
            self.advice = nil
            self.equityHistory = []
            self.lastStatsKey = ""
            self.session = SessionStats()
            self.bumpSessions()
        }
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
