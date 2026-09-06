# The Bar Bible — Bug Fix Session Changelog

**Date:** 2026-09-06
**Source:** Full codebase audit (`AUDIT_REPORT.md`) followed by two Claude
Code fix batches, plus a third batch of fixes made directly in this session
from bugs Connor found while testing. This document combines all of it into
one record.
**Status:** All commits below are local only — nothing has been pushed to
`origin` yet. Not yet tested end-to-end on device.

---

## Batch 1 — Crash/data-loss fixes + bar-sync completeness + cleanup

Scope: all 7 crash/data-loss items from the audit (C1-C7), two related
bar-sync UX bugs (U11, U17), committing `firestore.rules` to the repo, and
deleting confirmed dead code.

**Group 1 — Startup hang (C1)**
`main.dart` and `splash_screen.dart` now wrap the pre-launch sync calls in
an 8s timeout + catch, so a stalled network call always falls through to
rendering the app instead of leaving the user on a blank screen.

**Group 2 — Crash fixes (C2-C6)**
Fixed the unsafe `tags` cast in the admin cocktail editor (crashed on
legacy String-format tags), three unguarded post-await `setState()` calls
(`paywall_screen.dart`, `admin_user_management_screen.dart`,
`add_cocktails_dialog.dart`), and the `.getSingle()` → `.getSingleOrNull()`
crash in `my_bar_screen.dart`'s `_switchToBar` (now falls back via
`_loadData()` instead of throwing).

**Group 3 — Bar sync completeness (C7, U11, U17)**
- `pullUserCocktails` now prunes locally-stale cocktails that were deleted
  on another device.
- Both `my_bar_screen.dart` and `finder_screen.dart`'s rename dialogs now
  notify their parent screen, so a rename propagates immediately.
- Finder's bar create/rename flows now push to Firestore (previously
  local-only).
- Verified live on an emulator: creating and renaming a bar updates the
  Home header immediately (no restart needed) from both the My Bar and
  Finder tabs, and the rename survives a full app restart.

**Group 4 — `firestore.rules` committed to the repo**
Created at the repo root with the tightened `allow update` rule (blocks
`is_admin`/`is_premium` changes on update, and blocks `creates_used`/
`ai_credits_used`/`ai_credits_used_today` from ever being *decreased* by
the document owner — closes a self-service quota-reset gap).

**Found but explicitly left unfixed in this batch (deferred to Follow-Up):**
- A crash discovered during live testing: `my_bar_screen.dart`'s (and
  `finder_screen.dart`'s identical) `_showRenameBarDialog` called
  `controller.dispose()` synchronously right after `showDialog()` returned,
  while the dialog was still playing its closing transition — if that
  transition rebuilt the `TextField`, it threw "TextEditingController used
  after being disposed" as a fatal widget-tree assertion.
- `my_bar_screen.dart`'s own rename flow still didn't call
  `_pushBarsToCloud()` (only Finder's was in scope for U17 in this batch).
- Group 5 (dead-code deletion) was scoped into this batch but **did not
  actually get completed** — carried into Follow-Up instead.

---

## Batch 1 Follow-Up — Dead code, missed sync call, dispose crash

**Group A — Dead code**
None of it had been deleted yet in Batch 1. Re-verified all 8 targets with
fresh whole-tree greps (zero references beyond their own declarations) and
deleted:
- The 7 "1.0 Blueprint refactor" stub files
- `builder_screen.dart` (1,423 lines, superseded by My Bar + Finder tabs)
- The `FavoriteIconCompact` class from `favorite_button.dart` (kept
  `FavoriteButton`; no imports became unused)

`flutter analyze` clean.

**Group B — `my_bar_screen.dart` rename → Firestore**
Confirmed the gap and added `_pushBarsToCloud()` after a successful rename,
matching this file's own established pattern (`_createNewBar`,
`_clearCurrentBarWithConfirm`, `_deleteBarWithConfirm` all already call it).

**Group C — Dialog dispose crash**
Fixed in both `my_bar_screen.dart` and `finder_screen.dart`. The
`addPostFrameCallback` one-frame-defer approach was considered and rejected
after re-examining the earlier crash log — the keyboard-hide animation
that follows a dialog close runs for many frames, so a one-frame defer
wouldn't reliably survive it. Instead, each dialog was given its own
`_RenameBarDialog` `StatefulWidget` that owns and disposes its controller
in its own `dispose()` — the one point Flutter guarantees is safe,
independent of animation timing.

Verified the hard way: reproduced the exact crash sequence from the
previous session (create bar → Rename → edit text → Save) in both files.
Before the fix this reliably crashed; after, both renamed cleanly with zero
exceptions in logcat, and the new name propagated live to the Home screen.

`flutter analyze` clean after every group. No scope creep — everything
else in these files was left alone.

---

## Batch 2 — Remaining broken-UX fixes

Scope: the remaining 15 broken-UX items from the audit (U1-U10, U12,
U14-U16). **U13 (Finder's mode filter) was explicitly excluded** — the
user wants "One Away"/"Show All" as a real future feature, not a bug fix,
so `_FinderMode` and its switch statement were left untouched.

**Group 1 (U1) — Silent sync failures**
`pushFavourites`/`pushBars`/`pushCollections`/`pushUserCocktails`/
`pushSingleUserCocktail` in `user_sync_service.dart` now return `bool`
instead of swallowing errors. All 8 call sites await the result and show a
"Couldn't sync to cloud — will retry later" SnackBar only on failure,
without blocking the calling action's own success feedback (used a
captured `ScaffoldMessenger` for the two screens that navigate away
immediately after the push).

**Group 2 (U2, U3) — Race conditions / duplicate data**
- Busy-flag guard added to `favorite_button.dart`'s toggle (fixes the false
  "Failed to update favorite" error on a fast double-tap).
- Added a unique `(collectionId, firestoreId)` constraint on
  `CollectionCocktails` (schema v20, dedupe-then-index migration, mirrors
  `SavedBarIngredients`) plus regenerated `database.g.dart` via
  `build_runner`.
- Busy-flag guards added to the three collection-toggle handlers in
  `add_cocktails_dialog.dart`, `cocktail_detail_screen.dart`,
  `user_cocktail_detail_screen.dart`.
- Also switched the Firestore-pull path to `insertOrIgnore` so it can't
  crash on duplicates already present in previously-synced data — a direct
  consequence of adding the new constraint, not scope creep.

**Group 3 (U4) — Infinite spinners**
Load methods in `favorites_screen.dart`, `cocktail_detail_screen.dart`,
`user_cocktail_detail_screen.dart` wrapped in try/catch with retry-able
error states instead of spinning forever on failure.

**Group 4 (U5-U8) — Purchase & account UX**
- Paywall failure now shows a SnackBar (previously silent).
- "Forgot password?" link + dialog added to `auth_sheet.dart`.
- Delete Account flow added to `settings_screen.dart`: confirmation dialog
  → Firestore cleanup → Auth account delete → requires-recent-login
  reauth-and-retry handling, backed by a new `AuthService.deleteAccount()`.
- Sign-out button now has try/catch + loading/disabled state.

**Group 5 (U9, U10, U12, U14, U15, U16) — Misc error handling, races, type-safety**
- `admin_staging_screen.dart`'s `_reject` now has try/catch, matching
  `_approve`.
- Bar-rename dialogs in both `my_bar_screen.dart` and `finder_screen.dart`
  now reject duplicate names inline (closes the "bar switcher compares by
  name not ID" ambiguity at the root, without a larger ID-threading
  refactor). Bar *creation* already auto-generates unique names, so that
  path needed no change.
- Generation counter added to `my_bar_screen.dart`'s `_openCategory` (fixes
  a stale-async-result race when switching categories quickly).
- `ai_service.dart`'s difficulty parsing now accepts `num` instead of a
  strict `int` cast (was throwing on a float difficulty value from the LLM).
- Creator/AI-generator AppBar close buttons now disabled mid-save/mid-generate.
- `back_bar_screen.dart`'s limit checks wrapped in try/catch with SnackBar
  feedback on failure.

`flutter analyze` clean after every group. All 5 groups committed locally,
nothing pushed.

**Notes from the Batch 2 session:**
- `settings_screen.dart` and `auth_service.dart` already had unrelated
  uncommitted work sitting in the working tree before this session started
  (the admin "simulate non-premium" toggle, added earlier). It got bundled
  into the Group 4 commit since it lives in the same files — not authored
  or reviewed as part of this batch, just carried along.
- Nothing else obviously broken was spotted while in these files beyond
  what was listed. `AUDIT_REPORT.md` and a `claude_outputs/`-style
  untracked directory are still sitting in the repo root, untouched.

---

## Full list of files touched across all three sessions

Based on the summaries above (not independently re-verified against
`git diff` — confirm with `git log`/`git show` before relying on this for
a release note):

- `main.dart`, `splash_screen.dart`
- `admin_cocktail_editor_screen.dart`
- `paywall_screen.dart`, `admin_user_management_screen.dart`,
  `add_cocktails_dialog.dart`
- `my_bar_screen.dart`, `finder_screen.dart` (+ new shared
  `_RenameBarDialog` widget)
- `user_sync_service.dart`
- `database.dart` / `database.g.dart` (schema v18 → v20)
- `favorite_button.dart`, `cocktail_detail_screen.dart`,
  `user_cocktail_detail_screen.dart`
- `settings_screen.dart`, `auth_sheet.dart`, `auth_service.dart`
- `back_bar_screen.dart`, `ai_service.dart`
- `cocktail_creator_screen.dart`, `ai_generator_screen.dart`
- `admin_staging_screen.dart`
- `firestore.rules` (new)
- Deleted: 7 "1.0 Blueprint" stub files, `builder_screen.dart`,
  `FavoriteIconCompact` (class only, file kept)

---

## Batch 3 — Home screen bar-sync + UI consistency (done directly in this session, no Claude Code)

Reported by Connor: deleting a bar doesn't sync to Home, and Home's bar
switcher looked worse than My Bar's.

**Root cause 1 — stale Home state**: `main.dart`'s `_onBarChanged()` (fired
by My Bar on create/rename/delete) only reloaded `_activeBarName` and
refreshed the Finder tabs. It never told `HomeScreen` to reload — Home is
kept alive in the `IndexedStack` and only reloaded on its own internal
navigation events (`initState`, a couple of `Navigator.push().then()`
returns). So Home's `_savedBars` list and ingredient/can-make stats went
stale on any bar create/rename/delete, not just delete.

**Root cause 2 — duplicate UI**: Home had its own bespoke `_showBarSwitcher()`
bottom sheet (plain text list). My Bar/Finder use the shared
`BarSelectorDropdown` widget (gold pill + dropdown menu).

**Fix**:
- `lib/widgets/bar_selector_dropdown.dart` — added a `showManagementActions`
  flag (default `true`); when `false`, hides Create/Clear/Delete and only
  allows switching. Made `onCreateBar`/`onClearBar`/`onDeleteBar` nullable
  to support this. No behavior change for existing callers (My Bar).
- `lib/screens/home_screen.dart` — made the State class public
  (`HomeScreenState`) with a public `loadData()` entry point; added
  `_activeBarId` (threaded through `_HomeLoadResult`); replaced the bespoke
  `_showBarSwitcher()` bottom sheet with `BarSelectorDropdown`
  (`showManagementActions: false`) in the Section 1 header, next to the
  ingredient-count badge.
- `lib/main.dart` — added `_homeKey = GlobalKey<HomeScreenState>()`, wired
  it to the `HomeScreen` widget, and call `_homeKey.currentState?.loadData()`
  from both `_onBarChanged()` (debounced, same as the Finder-tab refresh)
  and `_switchBarFromPill()` — same pattern already used for
  `_myBarKey`/`_myBarTabKey`.

Committed directly to the device (not yet pushed to `origin`). Not run
through `flutter analyze` in this session — recommend running it plus a
manual pass (create/rename/delete a bar from My Bar, confirm Home's pill
and ingredient count update without switching tabs) before pushing.

## Not yet done / explicitly deferred

- **U13** (Finder mode filter / "One Away", "Show All") — real planned
  feature, needs UI design, separate session.
- **Architecture debt** (A1-A6 from the audit) — duplication, matching
  logic implemented 3x, inconsistent service access pattern. Not bugs,
  intentionally deferred.
- **Cosmetic items** (§6 of the audit) — dialog controller disposal,
  hardcoded version strings, the "NEW DRAFT" vs "ADD COCKTAIL" title
  mismatch, etc. Low priority, fold into future sessions touching the same
  files.
- **Pushing to `origin`** and bumping `pubspec.yaml` — waiting on manual
  testing first.
