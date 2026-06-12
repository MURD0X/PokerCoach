import SwiftUI
import PokerEngine

/// How long AI opponents "think" before acting. Persisted across launches.
enum AISpeed: String, CaseIterable, Identifiable {
    case fast, medium, slow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fast: return "Fast"
        case .medium: return "Medium"
        case .slow: return "Slow"
        }
    }

    var delay: Duration {
        switch self {
        case .fast: return .milliseconds(800)
        case .medium: return .milliseconds(1600)
        case .slow: return .milliseconds(2600)
        }
    }

    static let storageKey = "aiSpeed"

    static var current: AISpeed {
        AISpeed(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .fast
    }
}

struct SettingsView: View {
    @ObservedObject var model: GameViewModel
    @AppStorage(AISpeed.storageKey) private var aiSpeedRaw = AISpeed.fast.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Opponent speed", selection: $aiSpeedRaw) {
                        ForEach(AISpeed.allCases) { speed in
                            Text(speed.label).tag(speed.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Opponent speed")
                } footer: {
                    Text("How long the other players think before acting. Slower speeds make it easier to follow the action and the coach's reasoning — takes effect immediately, even mid-hand.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: aiSpeedRaw) { model.applyAISpeed() }
        }
        .presentationDetents([.medium])
    }
}
