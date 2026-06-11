## Summary

<!-- What does this PR do, and why? Link the issue if one exists. -->

## Changes

<!-- Bullet the notable changes. Call out anything reviewers should focus on. -->

## Test results

<!-- REQUIRED. A PR without test evidence is not reviewable. -->

### Engine tests

```
<!-- Paste the summary lines from `cd PokerEngine && swift test` here. -->
```

### UI verification (if UI changed)

<!-- Screenshot(s) from the simulator, or a description of the manual check.
     Tip: launch with `-autodeal -autopilot` to automate a full hand. -->

## Checklist

- [ ] Tests added/updated for behavior changes (mandatory for `PokerEngine/`)
- [ ] `swift test` passes locally
- [ ] `CHANGELOG.md` updated under *Unreleased* (user-facing changes)
- [ ] `project.yml` changed → `xcodegen generate` run and project committed
