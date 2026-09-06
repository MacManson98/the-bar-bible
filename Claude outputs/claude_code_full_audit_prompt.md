# The Bar Bible — Full Audit & Fix Session (Claude Code prompt)

Paste the block below into a fresh Claude Code session opened at
`C:\flutter_projects\BartenderApp\the_bar_bible`.

---

## Prompt to paste

```
You're auditing and fixing "The Bar Bible", a Flutter/Dart cocktail app for
bartenders (Firebase Auth/Firestore/Storage, RevenueCat for purchases,
Drift/SQLite for local offline cache, Provider for state management).

Ground rules for this whole session:
- Inspect the actual current file before touching it. A prior audit (listed
  below) is a starting checklist, not a source of truth — some of it is
  already fixed, verify everything against what's actually on disk.
- Don't invent code structure. If something in this brief doesn't match
  what you find, trust the filesystem and adjust.
- Match existing architecture and naming (Provider for state, Drift for
  local DB, the existing UserSyncService/FirestoreSyncService patterns for
  Firebase sync).
- After each logical group of fixes, run `flutter analyze` and resolve any
  new errors/warnings it introduces before moving to the next group.
- Commit locally after each group with a descriptive message. Do NOT push —
  leave commits local for review. Do NOT touch pubspec.yaml version.
- Don't touch RevenueCat config, Codemagic config, or CI/signing setup —
  out of scope, already handled separately.

## Already fixed this session — do not re-flag or re-touch these

- Favorites/collections now keyed on stable `firestoreId` (not local
  autoincrement IDs) — `database.dart` Favorites/CollectionCocktails tables,
  `user_cocktail_detail_screen.dart` `_favoritesKey`.
- AI-credit / create-quota spend happens only after the cocktail + ingredients
  are durably saved — `cocktail_creator_screen.dart` `_save()` and
  `ai_generator_screen.dart` `_generate()`.
- Deleted user cocktails no longer resurrect from a failed delete —
  `user_sync_service.dart` `deleteUserCocktailFromFirestore` +
  `_addPendingDelete`/`_flushPendingDeletes`, called before every pull.
- `AuthService.isEffectivelyPremium` is wired into all real premium-gating
  call sites across `main.dart`, `home_screen.dart`, `finder_screen.dart`,
  `back_bar_screen.dart`, `cocktail_creator_screen.dart`,
  `ai_generator_screen.dart`.
- `admin_cocktail_editor_screen.dart`: name-required guard before image
  upload (prevents `cocktail_images/.jpg` collisions), Ice "Other"
  validation, "at least one ingredient" validation, auto-sync-to-local-cache
  after a live publish.
- New admin-only "Simulate Non-Premium" toggle in Settings
  (`auth_service.dart` `adminSimulateNonPremium` / `setAdminSimulateNonPremium`,
  persisted via SharedPreferences) — lets an admin test the free-user
  experience without losing admin access.

## STEP 1 — Re-verify and write an audit report

Check every item below against the current code (file/line references may
have drifted — find the real location). For each item, determine: still
present as described / already fixed / different than described / not
found. Also do a fresh scan for anything NOT on this list — this list is
from a review 2 days before this session started, plus a couple of things
found since; it is not guaranteed complete.

### Crash / data-loss
1. App can hang on a blank screen at startup — `main.dart` awaits
   `pullFromFirestore` before `runApp()`, no `.timeout()` anywhere in
   `user_sync_service.dart`; `splash_screen.dart` `onReady()` has no
   try/catch/timeout either.
2. `admin_cocktail_editor_screen.dart` `initState()` — `(d['tags'] as
   List?)` throws CastError on legacy docs where tags was stored as a
   comma-separated String instead of a list.
3. Unguarded `setState()` after possible dispose: `paywall_screen.dart`
   (restore-purchase), `settings_screen.dart` (`_loadSettings`/
   `_toggleUnits`/`_toggleStrictMatching`/`_setDefaultSort`),
   `admin_user_management_screen.dart` (search — inconsistent with its own
   guarded `finally`), `add_cocktails_dialog.dart`.
4. `my_bar_screen.dart` `_switchToBar` calls `.getSingle()` with no
   null-guard — throws if the target bar was deleted in a race.
5. `user_sync_service.dart` `pullUserCocktails` only adds/updates from the
   Firestore snapshot, never removes a local user-cocktail that's missing
   from it — a cocktail deleted on Device A leaves a stale, never-cleaned-up
   copy on Device B after its next pull. (Not a resurrection — the delete
   fix already handles that — but still a real cross-device staleness bug.)
   Fix by diffing local `firestoreId`s against the pulled snapshot's doc IDs
   and deleting locals not present remotely, inside the same transaction.

### Broken UX
6. Every `UserSyncService` push/delete method only logs on failure; every
   call site fires without awaiting or checking the result
   (`favorite_button.dart`, `ai_generator_screen.dart`,
   `cocktail_creator_screen.dart`, `cocktail_detail_screen.dart`,
   `collections_screen.dart`, `my_bar_screen.dart`). Cross-device drift can
   happen indefinitely with zero UI indication.
7. Dead double-credit code in `back_bar_screen.dart` `_handleAiTap` —
   re-increments credit on a `Navigator.push<bool>` result that
   `AiGeneratorScreen` no longer returns (it uses `pushReplacement` now).
   Currently dead but a landmine; also means `_CreateTab._loadData()` never
   reruns after a successful AI generation.
8. Favorite-button double-tap race — no in-flight guard; `Favorites`'s PK is
   `firestoreId`, so a fast double-tap throws a PK violation on the second
   insert, reverting the optimistic UI and showing a spurious failure toast
   on what was actually a successful toggle.
9. Duplicate-insert/flicker in "Add to Collection" dialogs
   (`cocktail_detail_screen.dart`, `user_cocktail_detail_screen.dart`) — no
   unique constraint on (collectionId, firestoreId), no tap guard, dialog
   closes/reopens to refresh causing flicker.
10. Infinite spinner on load failure — no try/catch around initial async
    load in `favorites_screen.dart` (`_loadFavorites`),
    `cocktail_detail_screen.dart` (`_loadIngredients`/`_resolveImagePath`),
    `user_cocktail_detail_screen.dart` (`_loadIngredients`).
11. Purchase flow silently swallows failures — no try/catch around
    `purchasePremium` in `paywall_screen.dart`; failed offerings load still
    renders all 3 tiles as tappable (silent no-op); restore-purchase
    network errors misreported as "No previous purchase found."
12. No "forgot password" entry point in `auth_sheet.dart` despite
    `AuthService.sendPasswordReset` already existing.
13. No delete-account option in `settings_screen.dart` (only sign-out) —
    likely an App Store/Play Store compliance gap given account creation is
    supported.
14. Sign-out has no error handling/loading state (`settings_screen.dart`).
15. `admin_staging_screen.dart` `_reject` has no try/catch, unlike
    `_approve`.
16. Home screen's bar switcher compares bars by name, not id
    (`home_screen.dart`) — `SavedBars.name` has no uniqueness constraint.
17. Bar renames don't propagate to sibling screens (`finder_screen.dart`,
    `my_bar_screen.dart` `_showRenameBarDialog` updates local state only).
18. `my_bar_screen.dart` `_openCategory` race — no generation token guarding
    async unlock-delta computation.
19. `finder_screen.dart`'s mode filter is dead — `_mode` never reassigned,
    `_buildResultsForMode` ignores the matches it's given.
20. AI response parsing type-safety inconsistency — `ai_service.dart` uses
    `as int?` for difficulty (vs. safer `as num?` for amount);
    `"difficulty": 2.0` throws and degrades to a generic "check your
    connection" error.
21. Image picker/preview gaps in creator screen — `picker.pickImage()` sits
    outside its try block; image previews lack `errorBuilder`/`errorWidget`.
22. Creator/AI-generator AppBar close buttons stay tappable mid-save (no
    crash, but user can navigate away during an in-flight credit-spend + DB
    write).
23. `back_bar_screen.dart` `_handleCreateTap`/`_handleAiTap` call
    `auth.canCreateCocktail`/`canUseAi` with no try/catch (inconsistent with
    `_loadData`) — network failure during limit check makes the CTA
    silently no-op.
24. `FavoriteIconCompact` (`favorite_button.dart`) never pushes to
    Firestore, unlike `FavoriteButton`. Currently unused anywhere but a
    landmine if wired up later — either fix it to match `FavoriteButton` or
    remove it if truly dead.

### Cosmetic / style (fix if time allows after the above two tiers are done)
- `collections_screen.dart` — dialog `TextEditingController`s never disposed.
- `cocktail_detail_screen.dart` — vestigial unused collapse-progress calc in
  a SliverAppBar LayoutBuilder; raw exception text shown to user in
  `_openEditor`.
- `favorites_screen.dart` — no re-entrancy guard on row tap.
- `my_bar_tab_screen.dart` — all 4 tabs eager-load on mount instead of
  lazily.
- `builder_screen.dart` is entirely dead code (unreferenced in navigation),
  duplicates matching logic diverged from `finder_screen.dart` — confirm
  it's truly unreferenced, then delete it.
- Anthropic API key fetched via Firebase Remote Config, used directly
  client-side in `ai_service.dart` with a hardcoded placeholder fallback —
  extractable from a decompiled/intercepted build. Flag in the report but
  don't attempt a fix (needs a Cloud Function proxy — out of scope for this
  session, just document it clearly).
- `database.dart` schemaVersion bumped 18→19 — confirm this was intentional
  and genuinely has no accompanying column change; note in the report either
  way.
- `admin_cocktail_editor_screen.dart` / `admin_staging_screen.dart`: the
  "Add New Cocktail" tile from Settings opens the editor with no
  `stagingDocId`, so its title shows "NEW DRAFT" instead of something like
  "ADD COCKTAIL" — cosmetic mismatch, low priority.

Write the findings to `AUDIT_REPORT.md` at the repo root: one section per
tier (crash/data-loss, broken UX, cosmetic), each item marked with its
verification status and exact current file:line location. Commit this file
on its own first ("docs: full audit report").

## STEP 2 — Fix everything, in this order

1. All crash/data-loss items (1-5 above, re-numbered per your verified
   findings). Commit as a group: "fix: crash and data-loss issues (sync
   staleness, tags CastError, dispose races, ...)".
2. All broken-UX items (6-24 above). These are more numerous — group them
   sensibly (e.g. "sync reliability + feedback", "race conditions",
   "account management gaps", "misc UX bugs") and commit each group
   separately rather than one giant commit.
3. Cosmetic items, if session time/budget allows. Commit separately.

For each fix: keep it minimal and scoped to the actual bug, don't refactor
unrelated code, match existing patterns (e.g. the pending-delete-queue style
already used for the delete-resurrection fix is a good model for making
other sync operations resilient rather than fire-and-forget).

## STEP 3 — Final summary

Update `AUDIT_REPORT.md` with a "Fixed in this session" changelog (one line
per item, with the commit it landed in) and a "Deferred" section for
anything not reached, with a one-line reason why (e.g. "needs backend
change, out of scope" for the Remote Config API key issue). Give me a final
summary in chat: how many items fixed, how many deferred and why, and
whether `flutter analyze` is clean at the end.
```
