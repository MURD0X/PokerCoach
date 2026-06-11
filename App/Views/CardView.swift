import SwiftUI
import PokerEngine

struct CardView: View {
    enum Face {
        case up(Card)
        case down
        case placeholder
    }

    let face: Face
    var width: CGFloat = 44

    private var height: CGFloat { width * 1.42 }
    private var corner: CGFloat { width * 0.18 }

    var body: some View {
        switch face {
        case .up(let card):
            RoundedRectangle(cornerRadius: corner)
                .fill(.white)
                .overlay(
                    VStack(spacing: -width * 0.04) {
                        Text(card.rankText)
                            .font(.system(size: width * 0.42, weight: .bold, design: .rounded))
                        Text(card.suit.symbol)
                            .font(.system(size: width * 0.42))
                    }
                    .foregroundStyle(card.suit.isRed ? Color(red: 0.82, green: 0.18, blue: 0.18) : Color(white: 0.12))
                )
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                .transition(.scale(scale: 0.6).combined(with: .opacity))

        case .down:
            RoundedRectangle(cornerRadius: corner)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.32, green: 0.42, blue: 0.68), Color(red: 0.22, green: 0.30, blue: 0.52)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner * 0.6)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
                        .padding(width * 0.12)
                )
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)

        case .placeholder:
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: width, height: height)
        }
    }
}
