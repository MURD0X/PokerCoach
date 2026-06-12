import SwiftUI
import PokerEngine

struct ContentView: View {
    @StateObject private var model = GameViewModel()
    @State private var showLessons = false
    @State private var showWhy = false
    @State private var showResultDetails = false
    @State private var showLog = false
    @State private var showSettings = false
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
                    VStack(spacing: 0) {
                        Text("Poker Coach")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text("Bankroll \(model.bankroll.balance)")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.newTable()
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
                    canBuyBack: model.bankroll.canAffordBuyIn,
                    onBuyBack: { model.buyBackIn() },
                    onNewTable: { model.newTable() }
                )
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
