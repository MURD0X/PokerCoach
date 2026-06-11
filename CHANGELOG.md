# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Engineering standards: CI (engine tests + app build on every PR), PR
  template requiring test results, issue templates, CODEOWNERS, contribution
  guide, architecture and release documentation.

## [1.0.0] - 2026-06-10

### Added
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

[Unreleased]: https://github.com/MURD0X/PokerCoach/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/MURD0X/PokerCoach/releases/tag/v1.0.0
