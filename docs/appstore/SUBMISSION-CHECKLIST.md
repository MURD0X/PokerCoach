# App Store submission checklist

Everything I can produce is in this folder. The items marked (you) require your
Apple ID in App Store Connect — I can't perform them.

## Already done
- [x] App icon (1024, in the asset catalog)
- [x] Bundle ID, signing team, export compliance key
- [x] Versioning correct (2.0.0 / build 17 — the tournaments release)
- [x] Listing copy, keywords, description (LISTING.md)
- [x] Privacy policy text (PRIVACY.md) — host it (GitHub Pages or the repo raw URL)
- [x] Screenshots — 6.9" set (1320×2868) in docs/appstore/screenshots/6.9/,
      indexed in that folder's README; a 6.9" set covers the iPhone requirement

## You — in App Store Connect
- [ ] App Information: name, subtitle, category (Games/Card + Education)
- [ ] Pricing: Free
- [ ] App Privacy: answer "Data Not Collected" (matches PRIVACY.md)
- [ ] Age rating questionnaire → Simulated Gambling = Yes → 17+
- [ ] Paste description, promotional text, keywords, support URL, privacy URL
- [ ] Upload the 6.9" screenshots from docs/appstore/screenshots/6.9/
- [ ] Attach build 17 (v2.0.0) from TestFlight
- [ ] Submit for review

## Review notes to paste (helps reviewers)
"PokerCoach is a free, offline Texas Hold'em training app. It contains
simulated card play for education only — there is no real-money gambling,
no wagering, no in-app purchases, and no accounts. No data is collected."
