import SwiftUI
import PokerEngine

struct TableView: View {
    @ObservedObject var model: GameViewModel

    private var engine: GameEngine { model.engine }

    private var revealAll: Bool {
        engine.stage == .showdown ||
            (engine.stage == .done && engine.players.filter { !$0.folded }.count > 1)
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(engine.players.dropFirst()) { player in
                    SeatView(
                        player: player,
                        isDealer: engine.dealerIndex == player.id && engine.stage != .idle,
                        isActing: engine.actingIndex == player.id,
                        showCards: revealAll && !player.folded,
                        cardWidth: 32
                    )
                }
            }

            VStack(spacing: 8) {
                if engine.stage != .idle {
                    Text("Pot \(engine.totalPot)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.3)))
                }
                HStack(spacing: 7) {
                    ForEach(0..<5, id: \.self) { i in
                        if i < engine.board.count {
                            CardView(face: .up(engine.board[i]), width: 46)
                        } else {
                            CardView(face: .placeholder, width: 46)
                        }
                    }
                }
            }

            SeatView(
                player: engine.hero,
                isDealer: engine.dealerIndex == 0 && engine.stage != .idle,
                isActing: engine.actingIndex == 0,
                showCards: true,
                cardWidth: 52
            )
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.16, green: 0.42, blue: 0.31), Color(red: 0.10, green: 0.29, blue: 0.21)],
                        center: .center, startRadius: 40, endRadius: 360
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .strokeBorder(Color(red: 0.30, green: 0.22, blue: 0.15), lineWidth: 5)
        )
        .animation(.spring(duration: 0.45), value: engine.board.count)
        .animation(.easeInOut(duration: 0.25), value: engine.actingIndex)
    }
}

struct SeatView: View {
    let player: Player
    let isDealer: Bool
    let isActing: Bool
    let showCards: Bool
    let cardWidth: CGFloat

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Text(player.name)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                if isDealer {
                    Text("D")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color(red: 0.95, green: 0.83, blue: 0.45)))
                }
            }
            Text("\(player.stack)")
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))

            if player.hole.count == 2 {
                HStack(spacing: 4) {
                    ForEach(player.hole) { card in
                        CardView(face: showCards || player.isHero ? .up(card) : .down, width: cardWidth)
                    }
                }
            }

            Text(player.lastAction.isEmpty ? " " : player.lastAction)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.83, blue: 0.45))
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(isActing ? 0.45 : 0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isActing ? Color(red: 0.95, green: 0.83, blue: 0.45) : .clear, lineWidth: 2)
        )
        .opacity(player.folded ? 0.4 : 1)
    }
}
