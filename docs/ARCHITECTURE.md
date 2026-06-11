# Architecture

## Overview

PokerCoach is split into two layers with a strict dependency rule: the
**PokerEngine** Swift package contains all game logic and knows nothing about
UI; the **App** target contains all SwiftUI code and never reimplements game
rules. The engine compiles and tests on macOS, which keeps the test cycle
fast and CI cheap — no simulator needed to verify poker correctness.

```
┌─────────────────────────────────────────────┐
│ App (SwiftUI, iOS 17+)                      │
│  ContentView ── TableView / Dashboard / …   │
│        │                                    │
│  GameViewModel  ◄── @Published UI state     │
│   │    │    │                               │
└───┼────┼────┼───────────────────────────────┘
    │    │    └── heroActionProvider (async)
    │    └────── onChange callback
    ▼
┌─────────────────────────────────────────────┐
│ PokerEngine (pure Swift package)            │
│  GameEngine ── betting rounds, AI, pots     │
│  HandEvaluator / Equity / Outs / Chen       │
│  Coach ── advice text generation            │
│  Card / Deck ── CSPRNG shuffle              │
└─────────────────────────────────────────────┘
```

## The engine ↔ UI contract

`GameEngine` is `@MainActor` and exposes three integration points:

1. **`onChange: (() -> Void)?`** — fired after every state mutation (a bet, a
   dealt card, a log line). The view model forwards this to
   `objectWillChange` and uses it to trigger stat recomputation.
2. **`heroActionProvider: (() async -> HeroAction)?`** — when it's the
   human's turn, the engine `await`s this closure. The view model bridges it
   to the UI with a `CheckedContinuation`: buttons resume the continuation,
   the engine proceeds. The game loop is a single `async` function — no state
   machine flags to desynchronize.
3. **`aiDelay: Duration`** — AI "thinking" pause. Tests set it to `.zero` to
   run full hands in milliseconds.

## Fairness guarantees

- **Shuffle**: `Deck.shuffled()` uses Swift's `shuffled(using:)` (Fisher–
  Yates) with `SystemRandomNumberGenerator`, which is backed by the OS
  cryptographic RNG on Apple platforms. Every permutation of the deck is
  equally likely and unpredictable.
- **Information hiding**: AI decisions (`GameEngine.aiDecision`) read only
  that player's hole cards, the public board, and public bet sizes. Nothing
  reads the undealt deck or another player's cards.
- **Authentic procedure**: a burn card precedes each street, exactly as dealt
  live.

## Hand evaluation

`HandEvaluator.evaluate5` scores a 5-card hand as a single integer:
`category` in the high digits, then up to five base-15 tiebreaker ranks. Two
scores compare with plain `>`, which makes showdown and Monte Carlo loops
trivial. 6- and 7-card hands evaluate all C(n,5) subsets (21 at most) — simple,
allocation-light, and fast enough for tens of thousands of evaluations per
second, which the equity estimator relies on.

## Equity estimation

`Equity.estimate` runs N Monte Carlo trials (UI: 2,500 per street; AI
opponents: 150 per decision). Each trial deals random opponent hole cards and
completes the board via a partial Fisher–Yates (only the first `k` cards are
needed), then compares scores. Wins and ties are tracked separately; the
dashboard displays both, while decisions use `win + tie/2`.

**Known modeling simplification**: opponents are dealt *uniformly random*
hands. Real opponents who bet have stronger-than-random ranges, so displayed
equity is slightly optimistic against aggression. This is intentional for a
teaching app — pot odds vs. equity is the lesson — and range-weighting is the
natural next iteration.

## Outs

`Outs.compute` enumerates every unseen card and counts it as an out when it
upgrades the hand **category** and a hole card is part of the cards that form
the new category (the pair, the flush, the straight — not a kicker). This
excludes cards that merely pair the board, which improve every player's
nominal hand equally. The UI pairs the out count with the rule of 4 and 2 to
teach quick equity estimation.

## AI opponents

Deliberately simple and fully observable: Chen-formula thresholds preflop,
equity vs. pot odds postflop, with a small randomized loose-call/bluff rate so
play isn't exploitable by pure pattern matching. The goal is a realistic
*teaching* table, not a maximally strong opponent.

## Side pots

`GameEngine.buildPots` layers each player's total contribution: every layer
takes `min(contribution, layer level)` from each player and is contested only
by non-folded players who fully matched that layer. Folded chips stay in the
pot but confer no eligibility. The algorithm is `nonisolated` and pure, with
dedicated unit tests for all-in, folded-contribution, and overhang cases.

## Concurrency model

- The engine and all UI state live on the **main actor**.
- Monte Carlo work runs in `Task.detached(priority: .userInitiated)` and
  returns value types; results hop back to the main actor for publication.
- Stat recomputation is keyed by `(hand, board size, live opponents)` so a
  street triggers exactly one simulation, with stale tasks cancelled.
