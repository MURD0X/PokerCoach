import SwiftUI
import PokerEngine

struct LogView: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("HAND LOG")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(model.engine.log.suffix(9)) { entry in
                Text(entry.text)
                    .font(.system(.caption, design: .rounded, weight: weight(entry.kind)))
                    .foregroundStyle(color(entry.kind))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
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
