import SwiftUI
import PokerEngine

// Root: the front page (HomeView) with the table as a pushed screen.
// Mode sheets (drills/lessons/history/settings) and all bankroll-flow
// sheets (picker/bust/ruin/leave) live here so they work from anywhere.
struct ContentView: View {
    @StateObject private var model = GameViewModel()
    @State private var path: [String] = []
    @State private var showLessons = false
    @State private var showDrills = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var debugLessonTopic: LessonTopic?

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                model: model,
                onContinue: { path = ["table"] },
                onNewTable: { model.showTablePicker = true },
                onDrills: { showDrills = true },
                onLessons: { showLessons = true },
                onHistory: { showHistory = true },
                onSettings: { showSettings = true },
                onTournament: {
                    if !model.inTournament { model.startTournament() }
                    path = ["table"]
                }
            )
            .navigationDestination(for: String.self) { _ in
                TableScreen(model: model)
            }
        }
        .sheet(isPresented: $showLessons) { LessonsView() }
        .sheet(item: $debugLessonTopic) { topic in
            LessonsView(initialTopic: topic)
        }
        .sheet(isPresented: $showDrills) { DrillView() }
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        .sheet(isPresented: $showHistory) {
            HistoryView(records: SessionHistoryStore.load(), currentBalance: model.bankroll.balance)
        }
        .sheet(isPresented: $model.showTablePicker) {
            TablePickerView(
                bankroll: model.bankroll.balance,
                currentStakes: model.isSeated ? model.engine.stakes : nil,
                canLeave: model.isSeated && !model.isHandRunning,
                onLeave: { model.leaveTable() }
            ) { stakes in
                model.sitDown(stakes: stakes)
                if path.isEmpty { path = ["table"] }
            }
        }
        .sheet(isPresented: $model.showBustSheet) {
            BustSheetView(
                stats: model.session,
                bankrollBalance: model.bankroll.balance,
                buyIn: model.engine.stakes.buyIn,
                canBuyBack: model.bankroll.canAfford(model.engine.stakes.buyIn),
                onBuyBack: { model.buyBackIn() },
                onNewTable: {
                    model.showBustSheet = false
                    model.showTablePicker = true
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { model.leaveRecap != nil },
            set: { if !$0 { model.leaveRecap = nil; path = [] } }
        )) {
            if let recap = model.leaveRecap {
                LeaveRecapView(
                    stats: recap.stats, cashedOut: recap.cashedOut, net: recap.net,
                    bankrollBalance: model.bankroll.balance,
                    onFindTable: {
                        model.leaveRecap = nil
                        model.showTablePicker = true
                    },
                    onDone: {
                        model.leaveRecap = nil
                        path = []
                    }
                )
            }
        }
        .sheet(isPresented: $model.showRuinSheet) {
            RuinSheetView(lifetime: model.lifetime) { model.acceptFreshBankroll() }
        }
        .sheet(isPresented: Binding(
            get: { model.tournamentResult != nil },
            set: { if !$0 { model.dismissTournamentResult() } }
        )) {
            if let r = model.tournamentResult {
                TournamentResultView(
                    result: r,
                    onPlayAgain: { model.dismissTournamentResult(); model.startTournament() },
                    onDone: { model.dismissTournamentResult(); path = [] }
                )
            }
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-autodeal") {
                if !model.isSeated { model.sitDown(stakes: .standard) }
                path = ["table"]
                model.dealHand()
            }
            if args.contains("-demoleave"), model.isSeated { model.leaveTable() }
            if args.contains("-showlog") { path = ["table"] }
            if args.contains("-showsettings") { showSettings = true }
            if args.contains("-showdrills") { showDrills = true }
            if args.contains("-tournament") {
                if !model.inTournament { model.startTournament() }
                path = ["table"]
                model.dealHand()
            }
            if args.contains("-tournamentresult") {
                model.tournamentResult = TournamentResult(
                    standings: [
                        .init(place: 1, name: "You", payout: 2600),
                        .init(place: 2, name: "Priya", payout: 1400),
                        .init(place: 3, name: "Stefan", payout: 0),
                        .init(place: 4, name: "Omar", payout: 0)
                    ],
                    heroPlace: 1, heroPayout: 2600)
            }
            if let raw = UserDefaults.standard.string(forKey: "lessonTopic"),
               let topic = LessonTopic(rawValue: raw) {
                debugLessonTopic = topic
            }
            if args.contains("-showbust") {
                model.session = SessionStats(handsPlayed: 23, biggestPotWon: 840, decisionsTotal: 31, decisionsFollowed: 22)
                model.showBustSheet = true
            }
            if args.contains("-showruin") { model.showRuinSheet = true }
            if args.contains("-showpicker") { model.showTablePicker = true }
            if args.contains("-demohistory") {
                if SessionHistoryStore.load().isEmpty {
                    var balance = 10_000
                    for i in 0..<9 {
                        let net = [600, -1000, 250, -500, 1400, -1000, 800, -250, 950][i]
                        let buyIn = [500, 1000, 1000, 500, 1000, 2500, 1000, 500, 1000][i]
                        balance += net
                        SessionHistoryStore.append(SessionRecord(
                            date: Date().addingTimeInterval(Double(i - 9) * 86_400),
                            bigBlind: [10, 20, 20, 10, 20, 50, 20, 10, 20][i],
                            buyInTotal: buyIn,
                            cashOut: buyIn + net, hands: 12 + i * 3,
                            decisionsTotal: 20 + i * 4, decisionsFollowed: 14 + i * 3,
                            balanceAfter: balance
                        ))
                    }
                }
                showHistory = true
            }
        }
    }
}

// The in-session screen: table, dashboard, and the live coaching bars.
struct TableScreen: View {
    @ObservedObject var model: GameViewModel
    @AppStorage(CoachMode.storageKey) private var coachModeRaw = CoachMode.full.rawValue
    @State private var showWhy = false
    @State private var showResultDetails = false
    @State private var showLog = false
    @State private var showLeaveTournament = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                statusStrip
                TableView(model: model)
                StatsDashboardView(model: model)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(model.inTournament
                         ? "Sit & Go · Level \(model.tournament?.level ?? 1)"
                         : "Blinds \(model.engine.stakes.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.inTournament {
                    Button(role: .destructive) {
                        showLeaveTournament = true
                    } label: {
                        Label("Leave Tournament", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    Button {
                        model.showTablePicker = true
                    } label: {
                        Label("Switch Table", systemImage: "dice.fill")
                    }
                    .disabled(model.isHandRunning)
                }
            }
        }
        .confirmationDialog("Leave the tournament?",
                            isPresented: $showLeaveTournament, titleVisibility: .visible) {
            Button("Leave Tournament", role: .destructive) { model.forfeitTournament() }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("You'll forfeit your stack and finish in \(model.engine.activePlayerCount)\(Self.ordinalSuffix(model.engine.activePlayerCount)) place. You only keep winnings if you finish in the top two.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let advice = model.advice, model.isHeroTurn, coachModeRaw != CoachMode.off.rawValue {
                    CoachBarView(model: model, advice: advice, showWhy: $showWhy)
                } else if model.engine.stage == .done, let result = model.engine.lastResult {
                    ResultStripView(result: result) { showResultDetails = true }
                }
                ControlsView(model: model)
            }
            .background(.bar)
        }
        .sheet(isPresented: $showWhy) {
            if let advice = model.advice {
                CoachWhySheet(advice: advice)
            }
        }
        .sheet(isPresented: $showResultDetails) {
            if let result = model.engine.lastResult {
                ResultDetailSheet(result: result, equityHistory: model.equityHistory,
                                  decisions: model.handDecisions)
            }
        }
        .sheet(isPresented: $showLog) {
            LogSheetView(model: model)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-showlog") { showLog = true }
        }
        .onChange(of: model.engine.stage) {
            // Debug-only: auto-open the recap sheet for UI verification.
            if model.engine.stage == .done, model.engine.lastResult != nil,
               ProcessInfo.processInfo.arguments.contains("-autosheets") {
                showResultDetails = true
            }
        }
    }

    static func ordinalSuffix(_ n: Int) -> String {
        switch n % 10 {
        case 1 where n % 100 != 11: return "st"
        case 2 where n % 100 != 12: return "nd"
        case 3 where n % 100 != 13: return "rd"
        default: return "th"
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            if model.inTournament {
                Image(systemName: "trophy.fill").font(.footnote).foregroundStyle(Theme.gold)
                Text("Blinds \(model.tournament?.blinds.sb ?? 10)/\(model.tournament?.blinds.bb ?? 20)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text("· \(model.engine.activePlayerCount) left")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "banknote")
                    .font(.footnote)
                    .foregroundStyle(.green)
                Text("\(model.bankroll.balance)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text("Bankroll")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showLog = true
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }
}

#Preview {
    ContentView()
}
