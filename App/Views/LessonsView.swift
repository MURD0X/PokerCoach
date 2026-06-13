import SwiftUI
import PokerEngine

// The lessons hub: a linked table of contents where every topic is its own
// page — and the destination the coach's Learn-more chips land on.
struct LessonsView: View {
    var initialTopic: LessonTopic? = nil
    @State private var path: [LessonTopic] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(LessonContent.sections, id: \.header) { section in
                    Section(section.header) {
                        ForEach(section.topics) { topic in
                            NavigationLink(value: topic) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(topic.title)
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    Text(LessonContent.subtitle(for: topic))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Poker Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LessonTopic.self) { topic in
                LessonDetailView(topic: topic)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if let initialTopic { path = [initialTopic] }
        }
    }
}

struct LessonDetailView: View {
    let topic: LessonTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if topic == .handRankings {
                    rankingsTable
                }
                ForEach(LessonContent.blocks(for: topic)) { block in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(block.title)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text(block.body)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rankingsTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(rankings.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(row.0)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                    Spacer()
                    Text(row.1)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 7)
                if index < rankings.count - 1 { Divider() }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var rankings: [(String, String)] {
        [
            ("Royal Flush", "A♠ K♠ Q♠ J♠ 10♠"),
            ("Straight Flush", "9♥ 8♥ 7♥ 6♥ 5♥"),
            ("Four of a Kind", "Q Q Q Q 7"),
            ("Full House", "J J J 4 4"),
            ("Flush", "A♣ J♣ 8♣ 6♣ 2♣"),
            ("Straight", "8 7 6 5 4"),
            ("Three of a Kind", "7 7 7 K 2"),
            ("Two Pair", "A A 9 9 Q"),
            ("Pair", "10 10 A 6 3"),
            ("High Card", "A J 8 5 2"),
        ]
    }
}
