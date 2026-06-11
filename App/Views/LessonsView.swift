import SwiftUI

struct LessonsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("How a hand works") {
                    lesson("1. Blinds", "The two players left of the dealer button post forced bets (10 and 20 here) so there's always something to win.")
                    lesson("2. Preflop", "Everyone gets 2 hidden cards. Betting starts left of the big blind.")
                    lesson("3. Flop, Turn, River", "Community cards arrive: 3, then 1, then 1 — with a betting round after each.")
                    lesson("4. Showdown", "Remaining players reveal their cards. Best 5-card hand from your 2 + the board's 5 wins the pot.")
                    lesson("Your options", "Fold (give up), Check (pass if no bet), Call (match the bet), Raise (bet more), or go All-in.")
                }

                Section("Hand rankings — strongest first") {
                    ranking("Royal Flush", "A♠ K♠ Q♠ J♠ 10♠")
                    ranking("Straight Flush", "9♥ 8♥ 7♥ 6♥ 5♥")
                    ranking("Four of a Kind", "Q Q Q Q 7")
                    ranking("Full House", "J J J 4 4")
                    ranking("Flush", "A♣ J♣ 8♣ 6♣ 2♣")
                    ranking("Straight", "8 7 6 5 4")
                    ranking("Three of a Kind", "7 7 7 K 2")
                    ranking("Two Pair", "A A 9 9 Q")
                    ranking("Pair", "10 10 A 6 3")
                    ranking("High Card", "A J 8 5 2")
                }

                Section("Position") {
                    lesson("Why it matters", "The dealer button (D) decides who acts last. Acting last means you see everyone's decision before making yours — a real advantage.")
                    lesson("Rule of thumb", "The later your position, the more hands you can play. In early position, stick to strong hands.")
                }

                Section("Pot odds & equity") {
                    lesson("Equity", "Your probability of winning the pot. The dashboard estimates it by simulating thousands of random run-outs.")
                    lesson("Pot odds", "Compare the price to the prize: calling 50 into a 200 pot means you need to win 25% of the time to break even.")
                    lesson("The golden rule", "Call when your win % is higher than the pot-odds %. Fold when it's lower. Do this consistently and you profit long-term.")
                    lesson("Rule of 4 and 2", "Multiply your outs by 4 on the flop, or 2 on the turn, to estimate your % chance of improving by the river.")
                }

                Section("Fair dealing in this app") {
                    lesson("Cryptographic shuffle", "Every hand uses a fresh 52-card deck shuffled with Fisher-Yates driven by the system's cryptographic random number generator — every deck order is equally likely.")
                    lesson("No peeking", "The AI opponents decide using only their own cards and the board, exactly like human players. Bad beats here are real poker variance, not a rigged deck.")
                }
            }
            .navigationTitle("Poker Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func lesson(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text(body).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func ranking(_ name: String, _ example: String) -> some View {
        HStack {
            Text(name).font(.system(.subheadline, design: .rounded, weight: .medium))
            Spacer()
            Text(example)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
