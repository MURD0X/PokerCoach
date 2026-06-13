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

struct DecisionRecord: Identifiable {
    let id = UUID()
    let street: Stage
    let board: [Card]
    let toCall: Int
    let pot: Int
    let recommendation: CoachAction
    let action: HeroAction
    let review: DecisionReview
    let topics: [LessonTopic]
}

struct TournamentResult {
    struct Standing: Identifiable { let place: Int; let name: String; let payout: Int; var id: Int { place } }
    let standings: [Standing]
    let heroPlace: Int
    let heroPayout: Int
    var heroWon: Bool { heroPlace == 1 }
    var heroCashed: Bool { heroPayout > 0 }
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
    @Published var isSeated = false
    @Published var showTablePicker = false
    @Published var leaveRecap: (stats: SessionStats, cashedOut: Int, net: Int)?
    @Published var handDecisions: [DecisionRecord] = []
    @Published var tournament: TournamentState?
    @Published var tournamentResult: TournamentResult?
    private var eliminatedOrder: [String] = []
    private var pendingForfeit = false

    var inTournament: Bool { tournament != nil }
    private var sessionBuyInTotal = 0
    private var sessionStartDate = Date()
    private var pendingSeat: (() -> Void)?

    private enum Keys {
        static let balance = "bankrollBalance"
        static let tableSnapshot = "tableSnapshot"
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
        }
        engine.heroActionProvider = { [weak self] in
            await self?.heroTurn() ?? .checkCall
        }

        let d = UserDefaults.standard
        bankroll = BankrollLedger(balance: d.object(forKey: Keys.balance) == nil
            ? BankrollLedger.startingAmount : d.integer(forKey: Keys.balance))

        if let data = d.data(forKey: Keys.tableSnapshot),
           let table = try? JSONDecoder().decode(GameEngine.TableSnapshot.self, from: data) {
            // Same table, same opponents, same stack — the session continues.
            engine.restore(table)
            if let snap = SessionSnapshot.load() {
                sessionStartDate = snap.startDate
                sessionBuyInTotal = snap.buyInTotal
                session = SessionStats(
                    handsPlayed: snap.hands, biggestPotWon: 0,
                    decisionsTotal: snap.decisionsTotal,
                    decisionsFollowed: snap.decisionsFollowed
                )
            }
            d.set(0, forKey: Keys.lastTableStack) // retire the legacy key
            isSeated = true
        } else if d.integer(forKey: Keys.lastTableStack) > 0 {
            // One-time migration from pre-persistence builds: settle the old
            // table money and record the interrupted session.
            let previousStack = d.integer(forKey: Keys.lastTableStack)
            bankroll.cashOut(previousStack)
            d.set(0, forKey: Keys.lastTableStack)
            saveBankroll()
            if let snap = SessionSnapshot.load() {
                SessionHistoryStore.append(SessionRecord(
                    date: snap.startDate, bigBlind: snap.bigBlind,
                    buyInTotal: snap.buyInTotal, cashOut: previousStack,
                    hands: snap.hands, decisionsTotal: snap.decisionsTotal,
                    decisionsFollowed: snap.decisionsFollowed,
                    balanceAfter: bankroll.balance
                ))
                SessionSnapshot.clear()
            }
            isSeated = false
        } else {
            isSeated = false
        }
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

    private func snapshotTable() {
        if let table = engine.snapshot(),
           let data = try? JSONEncoder().encode(table) {
            UserDefaults.standard.set(data, forKey: Keys.tableSnapshot)
        }
    }

    private func clearTableSnapshot() {
        UserDefaults.standard.removeObject(forKey: Keys.tableSnapshot)
    }

    private func beginSession() {
        sessionStartDate = Date()
        sessionBuyInTotal = engine.stakes.buyIn
        bumpSessions()
        snapshotSession()
    }

    private func snapshotSession() {
        SessionSnapshot(
            startDate: sessionStartDate, bigBlind: engine.stakes.bigBlind,
            buyInTotal: sessionBuyInTotal, hands: session.handsPlayed,
            decisionsTotal: session.decisionsTotal,
            decisionsFollowed: session.decisionsFollowed
        ).save()
    }

    // Close the current seat into a history record at the cash-out moment.
    private func closeSession(cashOut: Int) {
        SessionHistoryStore.append(SessionRecord(
            date: sessionStartDate, bigBlind: engine.stakes.bigBlind,
            buyInTotal: sessionBuyInTotal, cashOut: cashOut,
            hands: session.handsPlayed, decisionsTotal: session.decisionsTotal,
            decisionsFollowed: session.decisionsFollowed,
            balanceAfter: bankroll.balance
        ))
        SessionSnapshot.clear()
    }

    // Pays the buy-in, or raises the ruin sheet and parks the intent until
    // the player takes a fresh bankroll. Snapshots the table money right
    // after seating so a launch-and-quit never loses the buy-in.
    private func chargeForSeat(_ amount: Int? = nil, then proceed: @escaping () -> Void) {
        let cost = amount ?? engine.stakes.buyIn
        if bankroll.chargeBuyIn(cost) {
            saveBankroll()
            proceed()
            snapshotTable()
        } else {
            pendingSeat = { [weak self] in
                guard let self else { return }
                self.bankroll.chargeBuyIn(cost)
                self.saveBankroll()
                proceed()
                self.snapshotTable()
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
            guard let self else { return }
            self.sessionBuyInTotal += self.engine.stakes.buyIn
            self.engine.rebuyHero()
            self.snapshotSession()
        }
    }

    func dealHand() {
        guard !isHandRunning else { return }
        if inTournament { tournamentDealHand(); return }
        guard isSeated else {
            showTablePicker = true
            return
        }
        guard !engine.heroBusted else {
            showBustSheet = true
            return
        }
        isHandRunning = true
        equityHistory = []
        handDecisions = []
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

    // MARK: - Tournament

    func startTournament() {
        guard !isHandRunning else { return }
        guard bankroll.canAfford(TournamentState.buyIn) else {
            pendingSeat = { [weak self] in self?.startTournament() }
            showRuinSheet = true
            return
        }
        bankroll.chargeBuyIn(TournamentState.buyIn)
        saveBankroll()
        clearTableSnapshot()                 // tournaments aren't resumed across launches
        let t = TournamentState()
        tournament = t
        tournamentResult = nil
        eliminatedOrder = []
        isSeated = false
        session = SessionStats()
        stats = nil; advice = nil; equityHistory = []; handDecisions = []; lastStatsKey = ""
        engine.beginTournament(startingStack: TournamentState.startingStack,
                               sb: t.blinds.sb, bb: t.blinds.bb)
    }

    private func tournamentDealHand() {
        guard var t = tournament,
              !engine.players[0].eliminated, engine.activePlayerCount > 1 else { return }
        isHandRunning = true
        equityHistory = []; handDecisions = []; stats = nil; advice = nil; lastStatsKey = ""
        engine.setBlindLevel(sb: t.blinds.sb, bb: t.blinds.bb)
        let before = Set(engine.players.filter { $0.eliminated }.map(\.name))
        Task { [weak self] in
            guard let self else { return }
            await self.engine.playHand()
            self.isHandRunning = false
            self.isHeroTurn = false
            for p in self.engine.players where p.eliminated && !before.contains(p.name) {
                self.eliminatedOrder.append(p.name)
            }
            t.handCompleted()
            self.tournament = t
            if self.pendingForfeit {
                self.completeForfeit()           // hero folded out; now leave for good
            } else if self.engine.players[0].eliminated {
                await self.resolveRemaining()
                self.finishTournament()
            } else if self.engine.activePlayerCount == 1 {
                self.finishTournament()
            }
        }
    }

    // Play out the remaining AIs (hero already busted) to settle full standings.
    private func resolveRemaining() async {
        let saved = engine.aiDelay
        engine.aiDelay = .zero
        engine.heroActionProvider = { .checkCall }   // never called; hero is out
        while engine.activePlayerCount > 1 {
            let before = Set(engine.players.filter { $0.eliminated }.map(\.name))
            await engine.playHand()
            for p in engine.players where p.eliminated && !before.contains(p.name) {
                eliminatedOrder.append(p.name)
            }
        }
        engine.aiDelay = saved
    }

    private func finishTournament() {
        let survivor = engine.players.first { !$0.eliminated }?.name
        var order: [String] = []
        if let survivor { order.append(survivor) }
        order.append(contentsOf: eliminatedOrder.reversed())
        let standings = order.enumerated().map {
            TournamentResult.Standing(place: $0.offset + 1, name: $0.element,
                                      payout: TournamentState.payout(place: $0.offset))
        }
        let heroPlace = standings.first { $0.name == "You" }?.place ?? order.count
        let heroPayout = TournamentState.payout(place: heroPlace - 1)
        if heroPayout > 0 { bankroll.cashOut(heroPayout); saveBankroll() }
        tournamentResult = TournamentResult(standings: standings, heroPlace: heroPlace, heroPayout: heroPayout)
        tournament = nil
    }

    /// Leave a tournament in progress: the hero forfeits their stack and is
    /// eliminated, locking their current finishing place (so quitting heads-up
    /// still cashes 2nd). If a hand is live, the hero folds out of it first and
    /// the forfeit completes once the hand settles. The AIs then play out to
    /// fill in the final standings.
    func forfeitTournament() {
        guard inTournament, !pendingForfeit, !engine.players[0].eliminated else { return }
        if isHeroTurn {
            pendingForfeit = true       // fold out of the live hand, then forfeit
            perform(.fold)
            return
        }
        if isHandRunning {
            pendingForfeit = true       // AIs are acting; forfeit when the hand ends
            return
        }
        completeForfeit()
    }

    private func completeForfeit() {
        pendingForfeit = false
        isHandRunning = true
        if !engine.players[0].eliminated {
            engine.forfeitHero()
            eliminatedOrder.append("You")
        }
        Task { [weak self] in
            guard let self else { return }
            await self.resolveRemaining()
            self.isHandRunning = false
            self.finishTournament()
        }
    }

    func dismissTournamentResult() {
        tournamentResult = nil
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
        defer {
            snapshotSession()
            snapshotTable()
        }
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
            handDecisions.append(DecisionRecord(
                street: engine.stage, board: engine.board,
                toCall: engine.heroToCall, pot: engine.totalPot,
                recommendation: advice.action, action: action,
                review: Reviewer.review(
                    recommendation: advice.action, action: action,
                    equity: advice.equity, potOddsNeeded: advice.potOddsNeeded,
                    street: engine.stage
                ),
                topics: advice.topics
            ))
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

    /// Leave the current table: bank the stack, record the session, show
    /// the recap. The player is unseated until they pick a new table.
    func leaveTable() {
        guard isSeated, !isHandRunning else { return }
        let cashOut = engine.hero.stack
        let net = cashOut - sessionBuyInTotal
        bankroll.cashOut(cashOut)
        saveBankroll()
        closeSession(cashOut: cashOut)
        clearTableSnapshot()
        isSeated = false
        showBustSheet = false
        leaveRecap = (session, cashOut, net)
    }

    /// Sit at a table (from the picker). Used both when unseated and when
    /// switching tables mid-visit — switching cashes out the old seat first.
    func sitDown(stakes: TableStakes) {
        guard !isHandRunning else { return }
        if isSeated {
            let cashOut = engine.hero.stack
            bankroll.cashOut(cashOut)
            saveBankroll()
            closeSession(cashOut: cashOut)
        }
        UserDefaults.standard.set(stakes.bigBlind, forKey: GameViewModel.stakesKey)
        showBustSheet = false
        chargeForSeat(stakes.buyIn) { [weak self] in
            guard let self else { return }
            self.engine.newTable(stakes: stakes)
            self.stats = nil
            self.advice = nil
            self.equityHistory = []
            self.lastStatsKey = ""
            self.session = SessionStats()
            self.beginSession()
            self.isSeated = true
        }
    }

    /// Busting keeps you at the same table conceptually; 'find a new table'
    /// from the bust sheet routes through the picker via the UI.
    func newTable(stakes: TableStakes? = nil) {
        sitDown(stakes: stakes ?? engine.stakes)
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
