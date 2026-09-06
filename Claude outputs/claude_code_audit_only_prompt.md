# The Bar Bible — Audit-Only Session (Claude Code prompt)

Paste the block below into a fresh Claude Code session opened at
`C:\flutter_projects\BartenderApp\the_bar_bible`.

This is audit-only. No code changes, no fixes, no commits beyond the report
itself.

---

## Prompt to paste

```
You're auditing "The Bar Bible", a Flutter/Dart cocktail app for bartenders
(Firebase Auth/Firestore/Storage, RevenueCat for purchases, Drift/SQLite for
local offline cache, Provider for state management).

DO NOT FIX ANYTHING. This is audit-only — read, analyze, and report. Do not
edit any source file. The only file you write is the report itself.

Ground rules:
- Inspect the actual current file before making any claim about it. A prior
  partial audit (listed below as a starting checklist) is not a source of
  truth — some of it may already be fixed, verify everything against what's
  actually on disk, and find things that aren't on the list at all.
- Go through every file under lib/, not just the ones mentioned below.
- Cite exact file:line for every finding — no vague claims.

## Already fixed — verify these are actually resolved, don't re-flag as bugs
unless your inspection shows otherwise

- Favorites/collections keyed on stable `firestoreId` (not local
  autoincrement IDs) — `database.dart` Favorites/CollectionCocktails tables,
  `user_cocktail_detail_screen.dart` `_favoritesKey`.
- AI-credit / create-quota spend happens only after the cocktail +
  ingredients are durably saved — `cocktail_creator_screen.dart` `_save()`
  and `ai_generator_screen.dart` `_generate()`.
- Deleted user cocktails no longer resurrect from a failed delete —
  `user_sync_service.dart` `deleteUserCocktailFromFirestore` +
  `_addPendingDelete`/`_flushPendingDeletes`.
- `AuthService.isEffectivelyPremium` is wired into all real premium-gating
  call sites (`main.dart`, `home_screen.dart`, `finder_screen.dart`,
  `back_bar_screen.dart`, `cocktail_creator_screen.dart`,
  `ai_generator_screen.dart`).
- `admin_cocktail_editor_screen.dart`: name-required guard before image
  upload, Ice "Other" validation, ingredient-required validation,
  auto-sync-to-local-cache after a live publish.
- Admin-only "Simulate Non-Premium" toggle in Settings (`auth_service.dart`).

## Known candidate issues — confirm status, don't assume still present

### Crash / data-loss
1. App can hang on a blank screen at startup — `main.dart` awaits
   `pullFromFirestore` before `runApp()`, no `.timeout()` in
   `user_sync_service.dart`; `splash_screen.dart` `onReady()` has no
   try/catch/timeout.
2. `admin_cocktail_editor_screen.dart` `initState()` — `(d['tags'] as
   List?)` throws CastError on legacy docs where tags was a comma-separated
   String.
3. Unguarded `setState()` after possible dispose: `paywall_screen.dart`,
   `settings_screen.dart`, `admin_user_management_screen.dart`,
   `add_cocktails_dialog.dart`.
4. `my_bar_screen.dart` `_switchToBar` calls `.getSingle()` with no
   null-guard.
5. `user_sync_service.dart` `pullUserCocktails` never removes a local
   user-cocktail that's missing from the Firestore snapshot — cross-device
   staleness.

### Broken UX
6. `UserSyncService` push/delete methods only log on failure; call sites
   fire-and-forget with no await/check.
7. Dead double-credit code in `back_bar_screen.dart` `_handleAiTap`
   referencing a nav pattern (`Navigator.push<bool>`) that no longer exists.
8. Favorite-button double-tap race — PK violation on fast double-tap.
9. Duplicate-insert/flicker in "Add to Collection" dialogs.
10. Infinite spinner on load failure — no try/catch around initial async
    loads in `favorites_screen.dart`, `cocktail_detail_screen.dart`,
    `user_cocktail_detail_screen.dart`.
11. Purchase flow silently swallows failures in `paywall_screen.dart`.
12. No "forgot password" entry point in `auth_sheet.dart` despite
    `AuthService.sendPasswordReset` existing.
13. No delete-account option in `settings_screen.dart`.
14. Sign-out has no error handling/loading state.
15. `admin_staging_screen.dart` `_reject` has no try/catch, unlike
    `_approve`.
16. Home screen's bar switcher compares bars by name, not id.
17. Bar renames don't propagate to sibling screens.
18. `my_bar_screen.dart` `_openCategory` race — no generation token.
19. `finder_screen.dart`'s mode filter is dead code.
20. AI response parsing type-safety — `ai_service.dart` uses `as int?` for
    difficulty instead of `as num?`.
21. Image picker/preview gaps in creator screen.
22. Creator/AI-generator AppBar close buttons tappable mid-save.
23. `back_bar_screen.dart` limit checks have no try/catch.
24. `FavoriteIconCompact` never pushes to Firestore, unlike `FavoriteButton`
    — unused landmine.

### Cosmetic / style
- `collections_screen.dart` dialog controllers never disposed.
- `cocktail_detail_screen.dart` vestigial calc + raw exception text shown to
  user.
- `favorites_screen.dart` no re-entrancy guard on row tap.
- `my_bar_tab_screen.dart` all 4 tabs eager-load on mount.
- `builder_screen.dart` possibly entirely dead code — confirm.
- Anthropic API key fetched via Remote Config, used client-side with a
  hardcoded fallback — extractable from a build.
- `database.dart` schemaVersion 18→19 — confirm intentional no-op.
- "Add New Cocktail" tile title mismatch ("NEW DRAFT" vs "ADD COCKTAIL").

## What to add beyond the known list

This app has grown incrementally over a long solo build. Beyond confirming
the above, scan the whole `lib/` tree fresh for:

- **Obsolete / dead code**: unused files, unused widgets, unused methods,
  commented-out blocks left in place, unreachable navigation routes,
  duplicated logic that now has a newer equivalent elsewhere (e.g.
  `builder_screen.dart` vs `finder_screen.dart` matching logic).
- **Overcomplicated code**: functions doing too much (long `build()`
  methods, deeply nested conditionals), state that could be simplified,
  business logic embedded in widgets that belongs in a service, repeated
  boilerplate that could be a shared helper/widget, screens rebuilding more
  than necessary (heavy work inside `build()`, missing `const`, unnecessary
  `Consumer`/`context.watch` scope).
- **Obviously-present bugs** not on the list above — null-safety gaps,
  off-by-one errors, incorrect async/await usage (missing awaits, unhandled
  Futures), inconsistent error handling patterns between similar screens,
  copy-paste mistakes.
- **Architecture drift**: inconsistent patterns for the same kind of thing
  (e.g. some screens use `context.read`, others hold a service reference in
  state, for equivalent needs), inconsistent naming, files that violate the
  project's existing data/domain/ui separation.
- **Security/config smells**: secrets or keys in source, permissive
  Firestore rules assumptions baked into client code, anything that trusts
  client-side state for something that should be server-verified (e.g.
  premium/limit checks that could be bypassed by a modified client).

## Output

Write everything to `AUDIT_REPORT.md` at the repo root. Structure:

1. **Summary** — one paragraph, total findings by category and severity.
2. **Crash / data-loss** — confirmed findings only, each with file:line,
   what's wrong, and what a user would actually experience.
3. **Broken UX** — same format.
4. **Overcomplicated / architecture debt** — each with file:line, what's
   overcomplicated, and a one-line suggestion (not a full fix).
5. **Obsolete / dead code** — each with file(s), why it's dead, confidence
   level (certain vs. probable — flag anything you're not 100% sure is
   unreferenced).
6. **Cosmetic / style** — low-priority polish items.
7. **Already-fixed confirmations** — a short list confirming which
   "already fixed" items above you verified as actually resolved (or flag
   if any turned out not to be).

Do not create a plan for fixing these, do not estimate effort, do not touch
any source file. This session's only output is the report. When you're
done, tell me in chat how many total findings landed in each section.
```
