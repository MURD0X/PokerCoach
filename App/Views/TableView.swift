import SwiftUI
import PokerEngine

// Anchor plumbing so chip flights know where seats and the pot live.
struct SeatAnchorKey: PreferenceKey {
    static var defaultValue: [Int: Anchor<CGPoint>] = [:]
    static func reduce(value: inout [Int: Anchor<CGPoint>], nextValue: () -> [Int: Anchor<CGPoint>]) {
        value.merge(nextValue()) { $1 }
    }
}

struct PotAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGPoint>? = nil
    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = nextValue() ?? value
    }
}

// One chip sliding seat→pot or pot→seat.
struct ChipFlightView: View {
    let from: CGPoint
    let to: CGPoint
    @State private var arrived = false

    var body: some View {
        Circle()
            .fill(Color(red: 0.95, green: 0.83, blue: 0.45))
            .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2))
            .frame(width: 16, height: 16)
            .position(arrived ? to : from)
            .opacity(arrived ? 0.2 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: 0.5)) { arrived = true }
            }
            .allowsHitTesting(false)
    }
}

struct TableView: View {
    @ObservedObject var model: GameViewModel

    private var engine: GameEngine { model.engine }

    private var revealAll: Bool {
        engine.stage == .showdown ||
            (engine.stage == .done && engine.players.filter { !$0.folded }.count > 1)
    }

    private var winningCards: Set<Card> {
        guard engine.stage == .done || engine.stage == .showdown else { return [] }
        return engine.lastResult?.winningCards ?? []
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(engine.players.dropFirst()) { player in
                    seatAnchored(player.id) { SeatView(
                        player: player,
                        isDealer: engine.dealerIndex == player.id && engine.stage != .idle,
                        isActing: engine.actingIndex == player.id,
                        showCards: revealAll && !player.folded,
                        cardWidth: 32,
                        winningCards: winningCards,
                        reveal: engine.styleReveal(for: player.id)
                    ) }
                }
            }

            VStack(spacing: 8) {
                if engine.stage != .idle {
                    Text("Pot \(engine.totalPot)")
                        .anchorPreference(key: PotAnchorKey.self, value: .center) { $0 }
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.3)))
                }
                HStack(spacing: 7) {
                    ForEach(0..<5, id: \.self) { i in
                        if i < engine.board.count {
                            CardView(face: .up(engine.board[i]), width: 46,
                                     glow: winningCards.contains(engine.board[i]))
                        } else {
                            CardView(face: .placeholder, width: 46)
                        }
                    }
                }
            }

            seatAnchored(0) { SeatView(
                player: engine.hero,
                isDealer: engine.dealerIndex == 0 && engine.stage != .idle,
                isActing: engine.actingIndex == 0,
                showCards: true,
                cardWidth: 52,
                winningCards: winningCards
            ) }
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
        .overlayPreferenceValue(SeatAnchorKey.self) { seatAnchors in
            self.flightOverlay(seatAnchors: seatAnchors)
        }
    }

    private func seatAnchored<Content: View>(_ id: Int, @ViewBuilder content: () -> Content) -> some View {
        content().anchorPreference(key: SeatAnchorKey.self, value: .center) { [id: $0] }
    }

    @ViewBuilder
    private func flightOverlay(seatAnchors: [Int: Anchor<CGPoint>]) -> some View {
        GeometryReader { geo in
            // The pot anchor lives in a separate preference; resolve it lazily.
            potOverlay(geo: geo, seatAnchors: seatAnchors)
        }
        .allowsHitTesting(false)
    }

    private func potOverlay(geo: GeometryProxy, seatAnchors: [Int: Anchor<CGPoint>]) -> some View {
        // Approximate the pot point when the label isn't rendered (idle).
        let fallbackPot = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.40)
        return ZStack {
            ForEach(model.chipFlights) { flight in
                if let seatAnchor = seatAnchors[flight.seat] {
                    let seatPoint = geo[seatAnchor]
                    ChipFlightView(
                        from: flight.reverse ? fallbackPot : seatPoint,
                        to: flight.reverse ? seatPoint : fallbackPot
                    )
                }
            }
        }
    }
}

struct SeatView: View {
    let player: Player
    let isDealer: Bool
    let isActing: Bool
    let showCards: Bool
    let cardWidth: CGFloat
    var winningCards: Set<Card> = []
    var reveal: StyleReveal? = nil

    private var avatarColor: Color {
        let hue = Double(abs(player.name.hashValue % 360)) / 360
        return Color(hue: hue, saturation: 0.55, brightness: 0.75)
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                if !player.isHero {
                    Text(String(player.name.prefix(1)))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 15, height: 15)
                        .background(Circle().fill(avatarColor))
                }
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

            if let reveal {
                Text(reveal.summary)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(reveal.anythingKnown ? Color(red: 0.62, green: 0.89, blue: 0.75) : .white.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if player.hole.count == 2 {
                HStack(spacing: 4) {
                    ForEach(player.hole) { card in
                        CardView(face: showCards || player.isHero ? .up(card) : .down, width: cardWidth,
                                 glow: showCards && !player.folded && winningCards.contains(card))
                            .transition(.scale(scale: 0.3, anchor: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.4).delay(Double(player.id) * 0.1), value: player.hole)
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
