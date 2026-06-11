import SwiftUI
import PokerEngine

struct ContentView: View {
    @StateObject private var model = GameViewModel()
    @State private var showLessons = false
    @State private var showWhy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    TableView(model: model)
                    if model.engine.stage == .done, let result = model.engine.lastResult {
                        ResultBannerView(result: result, equityHistory: model.equityHistory)
                    }
                    StatsDashboardView(model: model)
                    if !model.engine.log.isEmpty {
                        LogView(model: model)
                    }
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
                        model.newTable()
                    } label: {
                        Label("New Table", systemImage: "dice.fill")
                    }
                    .disabled(model.isHandRunning)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLessons = true
                    } label: {
                        Label("Lessons", systemImage: "book.fill")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let advice = model.advice, model.isHeroTurn {
                        CoachBarView(model: model, advice: advice, showWhy: $showWhy)
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
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-autodeal") {
                    model.dealHand()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
