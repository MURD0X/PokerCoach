import SwiftUI
import PokerEngine

// Full hand history on demand: lives behind a toolbar button so the main
// screen stays fixed-height. Scrolls, and opens at the latest entry.
struct LogSheetView: View {
    @ObservedObject var model: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        if model.engine.log.isEmpty {
                            Text("Nothing yet — deal a hand to start the history.")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.engine.log) { entry in
                            Text(entry.text)
                                .font(.system(.footnote, design: .rounded, weight: weight(entry.kind)))
                                .foregroundStyle(color(entry.kind))
                                .fixedSize(horizontal: false, vertical: true)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
                .onAppear {
                    if let last = model.engine.log.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .navigationTitle("Hand log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func color(_ kind: LogKind) -> Color {
        switch kind {
        case .header: return .primary
        case .street: return .teal
        case .win: return .orange
        case .info: return .secondary
        case .normal: return .secondary
        }
    }

    private func weight(_ kind: LogKind) -> Font.Weight {
        switch kind {
        case .header, .street, .win: return .semibold
        default: return .regular
        }
    }
}
