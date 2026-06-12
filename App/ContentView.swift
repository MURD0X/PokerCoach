import SwiftUI
import PokerEngine

struct ContentView: View {
    @StateObject private var model = GameViewModel()
    @State private var showLessons = false
    @State private var showWhy = false
    @State private var showResultDetails = false
    @State private var showLog = false
    @State private var showSettings = false
    @State private var showTablePicker = false
    @State private var showHistory = false
    @AppStorage(CoachMode.storageKey) private var coachModeRaw = CoachMode.full.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    TableView(model: model)
                    StatsDashboardView(model: model)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showHistory = true
                    } label: {
                        VStack(spacing: 0) {
                            Text("Poker Coach")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Text("Bankroll \(model.bankroll.balance)")
                                .font(.system(.caption2, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTablePicker = true
                    } label: {
                        Label("New Table", systemImage: "dice.fill")
                    }
                    .disabled(model.isHandRunning)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showLog = true
                    } label: {
                        Label("Hand Log", systemImage: "list.bullet.rectangle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLessons = true
                    } label: {
                        Label("Lessons", systemImage: "book.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
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
            .sheet(isPresented: $showLessons) {
                LessonsView()
            }
            .sheet(isPresented: $showWhy) {
                if let advice = model.advice {
                    CoachWhySheet(advice: advice)
                }
            }
            .sheet(isPresented: $showResultDetails) {
                if let result = model.engine.lastResult {
                    ResultDetailSheet(result: result, equityHistory: model.equityHistory)
                }
            }
            .sheet(isPresented: $showLog) {
                LogSheetView(model: model)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(model: model)
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
                        showTablePicker = true
                    }
                )
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(records: SessionHistoryStore.load(), currentBalance: model.bankroll.balance)
            }
            .sheet(isPresented: $showTablePicker) {
                TablePickerView(
                    bankroll: model.bankroll.balance,
                    currentStakes: model.engine.stakes
                ) { stakes in
                    model.newTable(stakes: stakes)
                }
            }
            .sheet(isPresented: $model.showRuinSheet) {
                RuinSheetView(lifetime: model.lifetime) { model.acceptFreshBankroll() }
            }
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-autodeal") { model.dealHand() }
                if args.contains("-showlog") { showLog = true }
                if args.contains("-showsettings") { showSettings = true }
                if args.contains("-showbust") {
                    model.session = SessionStats(handsPlayed: 23, biggestPotWon: 840, decisionsTotal: 31, decisionsFollowed: 22)
                    model.showBustSheet = true
                }
                if args.contains("-showruin") { model.showRuinSheet = true }
                if args.contains("-showpicker") { showTablePicker = true }
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
            .onChange(of: model.engine.stage) {
                // Debug-only: auto-open the recap sheet for UI verification.
                if model.engine.stage == .done, model.engine.lastResult != nil,
                   ProcessInfo.processInfo.arguments.contains("-autosheets") {
                    showResultDetails = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
