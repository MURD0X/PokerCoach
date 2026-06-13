# App Store screenshots

Captured from the v2.0.0 build on an **iPhone 16 Pro Max** simulator —
**1320 × 2868 px**, the 6.9" display size. A single 6.9" set satisfies App
Store Connect's iPhone requirement; it is reused for the smaller iPhone
sizes automatically, so a separate 6.5"/6.1" set is optional.

Suggested upload order (first two are the most important — they show in
search results). The set **leads with the post-hand review**, the app's
differentiator, to match the listing:

| # | File | What it shows |
|---|------|---------------|
| 1 | `6.9/01-review.png` | **Post-hand review** — every decision graded (matched / defensible / leak) with the costly call called out |
| 2 | `6.9/02-coach.png` | Live coach mid-hand — equity, hand strength, a clear recommendation |
| 3 | `6.9/03-tournament.png` | Sit & Go in play — blinds/level, a pair + flush draw with 20 outs and a BET rec |
| 4 | `6.9/04-standings.png` | Tournament result — Champion, top-two payouts |
| 5 | `6.9/05-lessons.png` | Interactive lesson — the pot-odds "price a call" widget |
| 6 | `6.9/06-drills.png` | Drill mode — a flashcard decision spot |
| 7 | `6.9/07-history.png` | Bankroll over time — the chart, lifetime stats, session ledger |
| 8 | `6.9/08-home.png` | Home — brand header, bankroll, Take a Seat, Sit & Go |

To regenerate: boot an iPhone 16 Pro Max simulator, install the build, and
launch with the debug args (`-tournament`, `-tournamentresult`,
`-lessonTopic potOdds`, `-showdrills`, `-demohistory`, `-autodeal`) listed
in the repo README, screenshotting each with `xcrun simctl io <udid>
screenshot`. For the review shot, launch `-autodeal -autopilot -autosheets`
and wait ~25s for a hand to reach showdown so the recap opens.
