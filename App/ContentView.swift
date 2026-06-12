import SwiftUI
import PokerEngine

struct ContentView: View {
    @StateObject private var model = GameViewModel()
    @State private var showLessons = false
    @State private var showWhy = false
    @State private var showResultDetails = false
    @State private var showLog = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showDrills = false
    @AppStorage(CoachMode.storageKey) private var coachModeRaw = CoachMode.full.rawValue

    private var statusStrip: some View {
        HStack(spacing: 10) {
            Button {
                showHistory = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "banknote")
                        .font(.footnote)
                        .foregroundStyle(.green)
                    Text("\(model.bankroll.balance)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text("Bankroll")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if model.isSeated {
                Text("Blinds \(model.engine.stakes.name)")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }

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
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    statusStrip
                    TableView(model: model)
                    StatsDashboardView(model: model)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Poker Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.showTablePicker = true
                    } label: {
                        Label("New Table", systemImage: "dice.fill")
                    }
                    .disabled(model.isHandRunning)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDrills = true
                    } label: {
                        Label("Drills", systemImage: "target")
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
            .sheet(isPresented: $showDrills) {
                DrillView()
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
                        model.showTablePicker = true
                    }
                )
            }
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
                }
            }
            .sheet(isPresented: Binding(
                get: { model.leaveRecap != nil },
                set: { if !$0 { model.leaveRecap = nil } }
            )) {
                if let recap = model.leaveRecap {
                    LeaveRecapView(
                        stats: recap.stats, cashedOut: recap.cashedOut, net: recap.net,
                        bankrollBalance: model.bankroll.balance,
                        onFindTable: {
                            model.leaveRecap = nil
                            model.showTablePicker = true
                        },
                        onDone: { model.leaveRecap = nil }
                    )
                }
            }
            .sheet(isPresented: $model.showRuinSheet) {
                RuinSheetView(lifetime: model.lifetime) { model.acceptFreshBankroll() }
            }
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-autodeal") {
                    if !model.isSeated { model.sitDown(stakes: .standard) }
                    model.dealHand()
                }
                if args.contains("-demoleave"), model.isSeated { model.leaveTable() }
                if args.contains("-showlog") { showLog = true }
                if args.contains("-showsettings") { showSettings = true }
                if args.contains("-showbust") {
                    model.session = SessionStats(handsPlayed: 23, biggestPotWon: 840, decisionsTotal: 31, decisionsFollowed: 22)
                    model.showBustSheet = true
                }
                if args.contains("-showruin") { model.showRuinSheet = true }
                if args.contains("-showpicker") { model.showTablePicker = true }
                if args.contains("-showdrills") { showDrills = true }
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
