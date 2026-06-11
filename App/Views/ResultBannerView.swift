import SwiftUI
import PokerEngine

struct ResultBannerView: View {
    let result: HandResult

    private var heroWon: Bool { result.winnerNames.contains("You") }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(result.headline, systemImage: heroWon ? "trophy.fill" : "flag.checkered")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(heroWon ? Color.green : Color.indigo))

            if let explanation = result.explanation {
                Text(explanation)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
            }

            if !result.showdowns.isEmpty {
                VStack(spacing: 6) {
                    ForEach(result.showdowns) { show in
                        HStack(spacing: 8) {
                            Image(systemName: show.isWinner ? "trophy.fill" : "xmark")
                                .font(.caption)
                                .foregroundStyle(show.isWinner ? .yellow : .secondary)
                                .frame(width: 16)
                            Text(show.name)
                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                .frame(width: 56, alignment: .leading)
                            ForEach(show.hole) { card in
                                CardView(face: .up(card), width: 22)
                            }
                            Text(show.handName)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(show.isWinner ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Spacer(minLength: 0)
                            if show.isWinner {
                                Text("+\(show.amountWon)")
                                    .font(.system(.footnote, design: .rounded, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .opacity(show.isWinner ? 1 : 0.65)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
