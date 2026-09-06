# The Bar Bible — Fix Batch 2 (Claude Code prompt)

Paste into a fresh Claude Code session at `C:\flutter_projects\BartenderApp\the_bar_bible`.

Scope: the remaining broken-UX items from the audit (U1-U10, U12, U14-U16).
U11/U17/dead-code/firestore.rules are already done (Batch 1 + Follow-Up —
see AUDIT_REPORT.md / project audit doc Fix Log if present). U13 (Finder's
mode filter) is explicitly OUT of scope — that's a real planned feature
(the user wants "One Away"/"Show All" modes eventually), not a bug, and
needs actual UI design work in a separate session. Do not touch
`_FinderMode`, its switch branches, or anything related to it in this batch.

---

## Prompt to paste

```
Continuing work on "The Bar Bible" (Flutter/Dart, Firebase, RevenueCat,
Drift/SQLite, Provider). Same ground rules as previous batches: inspect
before editing, verify against the actual filesystem (line numbers below
may have drifted), match existing patterns, run `flutter analyze` after
each group and resolve new issues before moving on, commit locally per
group, do not push. Fix ONLY what's listed — note anything else you notice
in your final summary instead of touching it.

Explicitly OUT OF SCOPE: `_FinderMode`, `finder_screen.dart`'s mode
filter/switch statement, or building any mode-switching UI. That's a real
planned feature for a separate session, not a bug fix — do not delete it,
do not "helpfully" wire it up either.

## Group 1 — Sync failures should surface to the user (U1)

Every push method in `user_sync_service.dart` (`pushFavourites`,
`pushBars`, `pushCollections`, `pushUserCocktails`) catches its own errors
and only logs them — every call site fires them without awaiting or
checking the result, so a sync failure is completely invisible to the user.

Keep this fix minimal — do NOT build a generic retry-queue system for every
push type (that's bigger architecture work, not today's scope). Instead:
at each call site currently firing these fire-and-forget
(`favorite_button.dart`, `collections_screen.dart`, `my_bar_screen.dart`,
`finder_screen.dart`, `cocktail_creator_screen.dart`,
`ai_generator_screen.dart`, `cocktail_detail_screen.dart`,
`user_cocktail_detail_screen.dart` — grep for `UserSyncService(` to find
them all), await the push and show a brief, non-blocking failure indicator
(a SnackBar like "Couldn't sync to cloud — will retry later" is fine) only
on failure. Success stays silent, as it already effectively is. Don't
block the calling action's own success feedback on the sync result — the
local write already succeeded, this is purely about not hiding a sync
failure.

## Group 2 — Race conditions causing false errors / duplicate data (U2, U3)

**U2**: `database.dart` `toggleFavorite` is a non-atomic check-then-act with
no re-entrancy guard, and `favorite_button.dart`'s `_toggleFavorite` has no
busy-flag. A fast double-tap fires two concurrent toggles; the second
insert collides on the `firestoreId` primary key and throws, shown to the
user as a false "Failed to update favorite" even though the first tap
succeeded. Fix with a busy-flag/in-flight guard in `favorite_button.dart` so
a second tap while one is in-flight is a no-op (or queues, your call —
simplest is ignoring taps while busy).

**U3**: `CollectionCocktails` (`database.dart`) has no unique constraint on
`(collectionId, firestoreId)`, unlike `SavedBarIngredients` which has one.
Combined with no re-entrancy guard on the toggle handlers in
`add_cocktails_dialog.dart`, `cocktail_detail_screen.dart`, and
`user_cocktail_detail_screen.dart`, a fast double-tap creates duplicate
membership rows, and the cocktail then renders twice in the collection.
Fix both: add the unique constraint (bump `schemaVersion`, add a migration
step and a matching `uniqueKeys` override on the table, following the exact
pattern already used for `SavedBarIngredients`), AND add a busy-flag guard
on the toggle handlers in the three files above, same approach as U2.

## Group 3 — Infinite spinners on load failure (U4)

No try/catch around the initial data load in `favorites_screen.dart`
(`_loadFavorites`), `cocktail_detail_screen.dart` (`_loadIngredients`), and
`user_cocktail_detail_screen.dart` (`_loadIngredients`). Wrap each in
try/catch so `isLoading`/`_isLoading` is always set to `false` in a
`finally` (or the catch block), and show a simple error state instead of
spinning forever.

## Group 4 — Purchase & account UX (U5, U6, U7, U8)

**U5**: `paywall_screen.dart` — `purchasePremium(...)` returning `false`
(any failure besides a graceful null package) currently has no `else`
branch in the `onPressed` handler, so the spinner just stops with zero
feedback. Add a SnackBar on failure, matching the pattern the "Restore
purchase" handler two sections below already uses.

**U6**: `auth_sheet.dart` has no "forgot password" entry point despite
`AuthService.sendPasswordReset` already existing and working. Add a text
button/link (e.g. under the email/password sign-in form: "Forgot
password?") that prompts for an email and calls
`auth.sendPasswordReset(email)`, with a confirmation SnackBar/dialog on
success and friendly error handling on failure.

**U7**: `settings_screen.dart` has sign-out but no delete-account option.
Add one. Requirements: confirmation dialog warning it's irreversible;
delete the Firestore `users/{uid}` doc (and its `user_cocktails`
subcollection) before deleting the Auth account; call
`FirebaseAuth.currentUser.delete()`; handle the
`requires-recent-login`/`FirebaseAuthException` case by prompting the user
to sign in again before retrying the delete (Firebase requires a recent
sign-in for account deletion) — show a clear message rather than a raw
exception; on success, sign out and navigate back to the unauthenticated
state. Keep the UI consistent with the existing settings tile style.

**U8**: `settings_screen.dart`'s sign-out button has no try/catch or
loading/disabled state while the async sign-out is in flight. Add both,
matching how other async actions in this file are already handled (e.g.
`_forceSync`'s loading-state pattern).

## Group 5 — Misc error handling, race guard, type-safety (U9, U10, U12, U14, U15, U16)

**U9**: `admin_staging_screen.dart`'s `_reject` has no try/catch, unlike
`_approve`. Add one, matching `_approve`'s error-handling shape.

**U10**: `home_screen.dart`'s bar switcher compares bars by `name`, not
`id` — two same-named bars both show "active" or neither does. Rather than
threading a bar ID through every screen that currently passes bar names
around (bigger refactor, out of scope), fix this at the root: enforce bar
name uniqueness at creation and rename time (in both
`my_bar_screen.dart` and `finder_screen.dart`'s create/rename flows) —
reject a duplicate name with a friendly inline error instead of allowing
it. This closes the actual bug (the ambiguity can't exist if names are
unique) without a large refactor.

**U12**: `my_bar_screen.dart` `_openCategory` has no generation token — a
slow category-A load can apply its results after a faster category-B load
if the user switches quickly. Add a simple generation counter
(increment on each call, capture the value at call start, check it's still
current before calling `setState` at the end).

**U14**: `ai_service.dart` — `difficulty: (json['difficulty'] as int? ?? 2).clamp(1, 5)`
will throw if the LLM emits a JSON float (e.g. `2.0`). Change to `as num?`
(matching how `AiIngredient.amount` already does it) and convert to int
appropriately before clamping.

**U15**: `cocktail_creator_screen.dart` and `ai_generator_screen.dart`'s
AppBar close (`Icons.close`) buttons are tappable mid-save/mid-generate,
letting a user think they cancelled when the DB write and quota-increment
actually completed anyway. Disable the close button (or show a confirm
dialog) while `_isSaving`/`_isGenerating` is true, matching whatever pattern
these screens already use to disable their main save/generate button during
that state.

**U16**: `back_bar_screen.dart`'s `_handleCreateTap` and `_handleAiTap` call
`auth.canCreateCocktail(...)`/`auth.canUseAi(...)` with no try/catch — a
network failure silently no-ops the tap instead of showing a message.
Wrap both in try/catch matching `_CreateTabState._loadData`'s existing
pattern in the same file, and show a friendly error SnackBar on failure.

## Final summary

Report per group: what changed, any deviation from the description above
and why, and confirm `flutter analyze` is clean after every group. Flag
anything you found but didn't fix because it was out of scope.
```
