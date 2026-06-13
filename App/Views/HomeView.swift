import SwiftUI
import PokerEngine

// The front door: brand, bankroll, the way back to your table, and the
// doors to every mode. Designed to match the launch screen so opening the
// app feels like one continuous moment.
struct HomeView: View {
    @ObservedObject var model: GameViewModel
    let onContinue: () -> Void
    let onNewTable: () -> Void
    let onDrills: () -> Void
    let onLessons: () -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                bankrollCard
                if model.isSeated {
                    continueCard
                } else {
                    newTableCard
                }
                doors
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header (matches the launch screen)

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: -18) {
                CardView(face: .up(Card(13, .hearts)), width: 54)
                    .rotationEffect(.degrees(-10))
                CardView(face: .up(Card(14, .spades)), width: 54)
                    .rotationEffect(.degrees(8))
                    .offset(y: -3)
            }
            .padding(.top, 26)
            Text("Poker Coach")
                .font(.custom("Copperplate", size: 34))
                .foregroundStyle(Theme.goldLight)
            Text("LEARN TEXAS HOLD'EM AT A FAIR TABLE")
                .font(.custom("Copperplate-Light", size: 12))
                .kerning(1.2)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
.fill(Theme.brandGradient(radius: 320))
        )
        .padding(.top, 8)
    }

    // MARK: - Cards

    private var bankrollCard: some View {
        Button(action: onHistory) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BANKROLL")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(model.bankroll.balance)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                }
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Theme.gold)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }

    private var continueCard: some View {
        Button(action: onContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Continue Session", systemImage: "play.fill")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Blinds \(model.engine.stakes.name) · your stack \(model.engine.hero.stack) · vs \(opponentNames)")
                        .font(.system(.caption, design: .rounded))
                        .opacity(0.85)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(Color(red: 0.16, green: 0.11, blue: 0.02))
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.goldGradient))
        }
        .buttonStyle(.plain)
    }

    private var newTableCard: some View {
        Button(action: onNewTable) {
            HStack {
                Label("Take a Seat", systemImage: "chair")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(Color(red: 0.16, green: 0.11, blue: 0.02))
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.goldGradient))
        }
        .buttonStyle(.plain)
    }

    private var opponentNames: String {
        model.engine.players.dropFirst().map(\.name).joined(separator: ", ")
    }

    // MARK: - Doors

    private var doors: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            door("target", "Drills", "10-spot decision training", onDrills)
            door("book.fill", "Lessons", "Rules, odds, reading players", onLessons)
            door("clock.arrow.circlepath", "History", "Sessions and your trend", onHistory)
            door("gearshape.fill", "Settings", "Speed, coach, sound", onSettings)
        }
    }

    private func door(_ icon: String, _ title: String, _ subtitle: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text(subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }
}
