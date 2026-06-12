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

/// How much the coach says. The learner's progression: full advice →
/// numbers only (you make the call) → off. Adherence tracks silently in
/// every mode, so the bust recap stays honest about how you played.
enum CoachMode: String, CaseIterable, Identifiable {
    case full, numbers, off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .full: return "Full"
        case .numbers: return "Numbers"
        case .off: return "Off"
        }
    }

    static let storageKey = "coachMode"

    static var current: CoachMode {
        CoachMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .full
    }
}

struct SettingsView: View {
    @ObservedObject var model: GameViewModel
    @AppStorage(AISpeed.storageKey) private var aiSpeedRaw = AISpeed.fast.rawValue
    @AppStorage(CoachMode.storageKey) private var coachModeRaw = CoachMode.full.rawValue
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

                Section {
                    Picker("Coach", selection: $coachModeRaw) {
                        ForEach(CoachMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Coach")
                } footer: {
                    Text("Full: recommendation with written reasoning. Numbers: your win % and pot odds only — you make the call. Off: pure play. Your decisions are graded against the coach quietly in every mode, so the session recap stays honest.")
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
