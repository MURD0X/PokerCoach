# Contributing

## Workflow

`main` is the release branch and is never pushed to directly. All changes —
features, fixes, docs — land through a pull request.

1. Branch from `main` using a typed prefix:
   - `feat/<slug>` — new functionality
   - `fix/<slug>` — bug fixes
   - `chore/<slug>` — tooling, docs, refactors
2. Keep PRs focused: one logical change per PR.
3. Fill in the PR template completely — **including the Test Results
   section**. A PR without test evidence is not reviewable.
4. CI must be green (engine tests + app build) before merge.
5. Squash-merge with a descriptive commit message.

## Commit messages

Use imperative mood with a scoped summary line, e.g.
`engine: fix side-pot eligibility for folded overhang`. Body explains *why*
when it isn't obvious.

## Testing requirements

- Engine changes (`PokerEngine/`) **must** ship with unit tests in the same
  PR. Run locally with:
  ```sh
  cd PokerEngine && swift test
  ```
- Poker-rules changes need a test asserting the rule itself (not just "code
  runs"): e.g. a side-pot change needs a pot-distribution assertion.
- UI changes should include simulator verification — paste a screenshot or
  describe the manual check in the PR. The `-autodeal -autopilot` launch
  arguments automate a full hand for visual verification.
- Statistical code (equity, shuffle) is tested against known probabilities
  with tolerances (e.g. AA heads-up ≈ 85% ± 5). Never tighten tolerances to
  the point of flakiness; never loosen them to the point of meaninglessness.

## Code style

- Swift API Design Guidelines; SwiftUI views stay small and composed.
- The dependency rule is absolute: `PokerEngine` never imports UI frameworks;
  `App/` never duplicates game rules.
- Comments explain constraints the code can't express (e.g. why ties count as
  half a win), not what the next line does.

## Project generation

`PokerCoach.xcodeproj` is generated — don't hand-edit it. Change
`project.yml` and run `xcodegen generate`, then commit both.
