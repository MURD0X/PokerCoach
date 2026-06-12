# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Bankroll: a persistent 10,000-chip bankroll behind your table money.
  Sitting at a table costs a 1,000 buy-in; leaving returns your stack;
  busting returns nothing — and you can now buy back in at the same table
  (same opponents, your reads intact). If the bankroll can't cover a seat,
  that's total ruin: a "Bankroll gone" moment with lifetime stats and a
  fresh start.
- Going broke now ends the session with an "Out of chips" recap — hands
  played, biggest pot won, and how often you followed the coach's advice —
  and a Take a New Seat button that seats you at a fresh table. Coach
  adherence is tracked per decision throughout the session.

### Changed
- Busting now matters: opponents who lose their stack leave the table and a
  new random player takes the seat (with a fresh hidden personality — your
  read on the old player goes with them). The engine refuses to deal while
  you have no chips; going broke ends the session.

## [1.3.0] - 2026-06-11

### Added
- Settings (gear icon in the toolbar): opponent speed — Fast (current
  pace), Medium, or Slow — persisted across launches and applied
  immediately, even mid-hand. Slower speeds make the action easier to
  follow while learning.
- Lessons: a "Chen scale" section explaining the preflop point system the
  coach quotes — scoring rules, worked examples (AA=20, AKs=12, 72o=−1),
  and the thresholds behind the coach's preflop advice.

## [1.2.2] - 2026-06-11

### Fixed
- Hand results and the hand log can no longer overflow the screen. The result
  is a one-line tappable strip above the Deal button (full recap — every
  shown hand, the beats-comparison, and the win-%-by-street chart — opens in
  a scrollable Details sheet). The hand log moved to a toolbar button that
  opens the full scrollable history. The main screen is now entirely
  fixed-height in every game state.

## [1.2.1] - 2026-06-11

### Fixed
- Coach advice no longer overflows: the recommendation is now a one-line bar
  pinned above the action buttons (badge + made hand + win % + required %),
  always fully visible at decision time. The full written reasoning opens in
  a scrollable "Why?" sheet. The whole decision view — table, stats, coach,
  controls — now fits a single screen.

## [1.2.0] - 2026-06-11

### Added
- App icon: fanned A♠/K♥ on felt green, with layered source files in
  `design/icon/` for Icon Composer (Liquid Glass) workflows. This was the
  last asset blocking TestFlight uploads.

## [1.1.2] - 2026-06-11

### Fixed
- Stats dashboard no longer overflows: outs collapse to a single row with
  "+N more" (tap to expand inline), and the win-%-by-street chart moved to
  the hand-end result card where it reads as a post-mortem. Every dashboard
  row now has a bounded height.

## [1.1.1] - 2026-06-11

### Changed
- Opponent name pool tripled to 60 names, and re-rolled tables never repeat
  a current opponent's name — every new table is visibly new players.

## [1.1.0] - 2026-06-11

### Added
- Opponent personalities: every opponent is rolled on three axes — Tight/Loose
  (starting-hand selection), Passive/Aggressive (betting pressure), and
  Rookie/Solid/Expert (pot-odds discipline and judgment) — and plays
  accordingly, including aggression-scaled bet sizing and skill-scaled
  misjudgments.
- Hidden style reveal: traits show as "? · ? · ?" and unlock with evidence —
  tightness after 8 hands observed, aggression after 10 decisions, skill
  after 3 showdowns — teaching real opponent profiling.
- Random tables: each session seats 3 random opponents (from a pool of 20
  names) with fresh personality rolls; a New Table button re-rolls the
  opposition at any time between hands.
- Hand results are now explicit: a result banner shows who won, how much,
  and with what hand; the five winning cards glow on the table; and a
  per-player recap explains why the winner beats the best losing hand
  (e.g. "Ace-high Flush beats Two Pair, Kings and Nines").

## [1.0.0] - 2026-06-10

### Added
- Engineering standards: CI (engine tests + app build on every PR), PR
  template requiring test results, issue templates, CODEOWNERS, contribution
  guide, architecture and release documentation.
- 4-handed no-limit Texas Hold'em against three AI opponents with blinds,
  burn cards, min-raise enforcement, all-ins, side pots, and split pots.
- Cryptographically fair dealing: Fisher–Yates shuffle backed by the OS
  CSPRNG (`SystemRandomNumberGenerator`); AI opponents have no access to
  hidden information.
- Live stats dashboard: per-street win % and tie % (Monte Carlo, 2,500
  trials), made-hand strength meter, out-card detection, pot odds vs. equity
  comparison, and a win-%-by-street chart.
- Coach: FOLD/CHECK/CALL/BET/RAISE recommendations with written reasoning —
  Chen formula preflop, equity vs. pot odds postflop, rule of 4 and 2 for
  draws.
- Lessons reference: hand rankings, game flow, position, pot odds & equity,
  and fairness explanation.
- `PokerEngine` Swift package with a 14-test suite: hand evaluation for all
  categories, tiebreakers, the wheel, 7-card selection, Chen scores, equity
  against known probabilities, outs correctness, side-pot construction, and
  25 end-to-end hands asserting chip conservation.
- Debug launch arguments `-autodeal` and `-autopilot` for automated UI
  verification.

[Unreleased]: https://github.com/MURD0X/PokerCoach/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/MURD0X/PokerCoach/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/MURD0X/PokerCoach/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/MURD0X/PokerCoach/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/MURD0X/PokerCoach/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/MURD0X/PokerCoach/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/MURD0X/PokerCoach/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/MURD0X/PokerCoach/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/MURD0X/PokerCoach/releases/tag/v1.0.0
