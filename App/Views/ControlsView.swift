import SwiftUI
import PokerEngine

struct ControlsView: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        VStack(spacing: 8) {
            if model.isHeroTurn {
                HStack(spacing: 8) {
                    Button(role: .destructive) {
                        model.perform(.fold)
                    } label: {
                        Text("Fold").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button {
                        model.perform(.checkCall)
                    } label: {
                        Text(model.heroToCall == 0 ? "Check" : "Call \(model.heroToCall)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                HStack(spacing: 8) {
                    ForEach(model.raiseOptions) { option in
                        Button {
                            model.perform(.raise(to: option.to))
                        } label: {
                            Text(option.label)
                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(option.label.hasPrefix("All-in") ? .orange : .green)
                    }
                }
            } else if !model.isHandRunning {
                Button {
                    model.dealHand()
                } label: {
                    Label("Deal Hand", systemImage: "suit.spade.fill")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for other players…")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .animation(.easeInOut(duration: 0.2), value: model.isHeroTurn)
    }
}
