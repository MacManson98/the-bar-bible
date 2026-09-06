# The Bar Bible — Code Audit Report

Audit date: 2026-09-06. Branch: `ui-system-refactor`. Every file under `lib/` was
inspected directly against the current working tree (not against the prior
partial audit, which was used only as a starting checklist to verify).

## 1. Summary

This audit examined all 53 Dart files under `lib/` (~23,000 hand-written
lines, excluding the generated `database.g.dart`). Total findings: **7
crash/data-loss**, **17 broken-UX**, **6 overcomplicated/architecture-debt**,
**11 obsolete/dead-code**, and **9 cosmetic/style** issues, plus confirmation
of **6 previously-fixed items** (one of which — the legacy `tags` cast in the
admin editor — turned out to still be broken and is called out explicitly).
The most serious confirmed issues are a genuine app-wide startup hang caused
by two unguarded/untimed awaits ahead of `runApp()` and inside the splash
screen, a legacy-data crash in the admin cocktail editor, and a missing
database uniqueness constraint that lets "Add to Collection" flows silently
create duplicate rows. Two entire files (`builder_screen.dart`, ~1,400 lines)
and one widget (`FavoriteIconCompact`) are confirmed dead code with zero
references anywhere in the tree, alongside seven placeholder stub files left
over from a "1.0 Blueprint refactor." The AI-generation flow also has a
client-side-only API key and quota model that a modified client could bypass
entirely.

---

## 2. Crash / data-loss

**C1. App can hang on a blank screen at startup, twice over.**
`main.dart:41-45` awaits `purchaseService.loginUser(uid)` and
`userSyncService.pullFromFirestore(uid)` for any already-signed-in user
*before* `runApp()` is ever called — neither call has a `.timeout()`, and
`pullFromFirestore` (`user_sync_service.dart:24-48`) only wraps its body in a
try/catch, which does nothing for a network call that simply never resolves
(e.g. a Firestore `get()` stalled on a flaky connection). If either hangs, no
widget tree is ever built — not even the splash screen. Separately, once past
that point, `splash_screen.dart:36-44`'s `_init()` does
`await Future.wait([widget.onReady(), Future.delayed(2000ms)])` with no
try/catch and no timeout either; if `onReady` (`FirestoreSyncService.syncIfNeeded`)
throws or stalls, `_ready` never becomes `true` and the user is stuck on the
splash screen indefinitely. **User experience:** app appears frozen/blank on
a poor connection, with no error, no retry, no timeout.

**C2. Legacy `tags` field crashes the admin cocktail editor on open.**
`admin_cocktail_editor_screen.dart:99-100`:
```dart
_tagsCtrl = TextEditingController(
    text: (d['tags'] as List?)?.join(', ') ?? d['tags'] as String? ?? '');
```
If `d['tags']` is a non-null `String` (a legacy comma-separated value, which
the original partial audit specifically flagged as existing in old docs),
`(d['tags'] as List?)` throws a `TypeError` — Dart's `as` cast fails for a
non-null value of the wrong type, it does not return `null`. This is a
regression risk that was **not** fixed alongside the rest of the editor's
validation work (see §7 — the other validation items in the same area *are*
fixed). **User experience:** opening a legacy cocktail for editing crashes
the editor screen outright.

**C3. Unguarded `setState()` after possible dispose — `paywall_screen.dart:202`.**
In the "Restore purchase" handler, `setState(() => _isRestoring = true)` is
followed by `await purchaseService.restorePurchases()` and then
`setState(() => _isRestoring = false)` with no `mounted` check on the second
call. If the user navigates away while the restore call is in flight, this
throws.

**C4. Unguarded `setState()` after possible dispose — `admin_user_management_screen.dart:121` and `:202-210`.**
Both `_toggleAdmin` and `_togglePremium` check `mounted` once before their
`await _firestore....update(...)` call, then call `setState()` afterward
without re-checking `mounted`. A screen pop during the Firestore write
crashes with "setState() called after dispose()".

**C5. Unguarded `setState()` after possible dispose — `add_cocktails_dialog.dart:411-439`.**
The picker row's `onTap` awaits a DB insert/delete and then calls
`setState(() {})` (line 438) with no `mounted`/context-alive check.

**C6. `my_bar_screen.dart:605` `_switchToBar` uses `.getSingle()` with no guard.**
```dart
final active = await (widget.database.select(widget.database.savedBars)
      ..where((b) => b.id.equals(barId))).getSingle();
```
`getSingle()` throws `StateError` if no row matches. There is no try/catch
around this call, and no fallback if `barId` refers to a bar that was deleted
concurrently (e.g. via a stale key from another screen).

**C7. `user_sync_service.dart:371-431` `pullUserCocktails` never deletes local user-cocktails that were removed from Firestore.**
The pull loop only upserts docs found in the snapshot; a cocktail deleted on
another device (or successfully deleted here but the local delete somehow
lagged) will never be removed locally by a later pull, producing permanent
cross-device staleness/resurrection of a "deleted" cocktail's local copy.

---

## 3. Broken UX

**U1. Cloud-sync failures are invisible.**
Every push method in `user_sync_service.dart` (`pushFavourites` 141-151,
`pushBars` 155-181, `pushCollections` 185-208, `pushUserCocktails` 212-258)
catches its own errors and only logs them via `log(...)`. Every call site —
`favorite_button.dart:85`, `collections_screen.dart:37`,
`my_bar_screen.dart:141-145`, etc. — calls these fire-and-forget with no
`await` and no error surfaced to the user. A user who is offline or has a
permissions issue will believe everything is syncing when nothing is.

**U2. Favourite double-tap race causes a false "Failed to update favorite" error.**
`database.dart:310-326` `toggleFavorite` is a non-atomic check-then-act
(select, then insert-or-delete) with no re-entrancy guard, and
`favorite_button.dart:75-121`'s `_toggleFavorite` has no busy-flag either. A
fast double-tap fires two concurrent toggles; the second `insert` collides on
the `firestoreId` primary key and throws, which is caught and shown to the
user as "Failed to update favorite" even though the original tap succeeded.

**U3. Duplicate rows can be created in "Add to Collection" flows.**
`CollectionCocktails` (`database.dart:62-67`) has **no unique constraint** on
`(collectionId, firestoreId)` — contrast with `SavedBarIngredients`
(`database.dart:79-89`), which explicitly declares one. Combined with no
re-entrancy guard on the toggle handlers in `add_cocktails_dialog.dart:411-439`,
`cocktail_detail_screen.dart:227-251`, and
`user_cocktail_detail_screen.dart:213-239`, a fast double-tap on the same row
inserts two membership rows. Since `collections_screen.dart:594-604` and
`_CollectionDetailScreenState._loadCocktails` join on this table without
deduplicating, the affected cocktail then renders twice in the collection.

**U4. Infinite spinner on load failure.**
No try/catch around the initial data load in:
`favorites_screen.dart:31-56` (`_loadFavorites`),
`cocktail_detail_screen.dart:263-289` (`_loadIngredients`), and
`user_cocktail_detail_screen.dart:39-46` (`_loadIngredients`). If the query
throws, `isLoading`/`_isLoading` is never set to `false` and the screen spins
forever.

**U5. Purchase failure is silently swallowed.**
`paywall_screen.dart:161-171`: `purchaseService.purchasePremium(...)` returns
`false` on any failure other than a graceful `null` package, but the
`onPressed` handler only acts `if (success)` — there is no `else` branch, so
a declined card or network error just makes the spinner stop with zero
feedback. Contrast with the "Restore purchase" handler two sections below
(`196-211`), which does show a SnackBar either way — the asymmetry suggests
this was simply missed, not a deliberate choice.

**U6. No "forgot password" entry point.**
`auth_sheet.dart` has no button, link, or code path that calls
`AuthService.sendPasswordReset` (`auth_service.dart:192-194`), even though
that method exists and is otherwise unused in the whole `lib/` tree.

**U7. No delete-account option.**
`settings_screen.dart` has a "Sign out" tile (372-382) but nothing that
deletes the Firebase Auth account or associated Firestore user doc.

**U8. Sign-out has no error handling or loading state.**
`settings_screen.dart:376-381`: `onPressed: () async { await auth.signOut(); }`
— no try/catch, no disabled/loading state on the button while the async
Google/Firebase sign-out calls are in flight.

**U9. `admin_staging_screen.dart:192-225` `_reject` has no try/catch, unlike `_approve` (127-190).**
A failed `.delete()` call (permissions, offline) throws unhandled with no
user feedback, whereas the approve path handles the same class of failure
gracefully.

**U10. Home screen's bar switcher compares bars by name, not ID.**
`home_screen.dart:314`: `final isActive = bar.name == widget.activeBarName;`
`SavedBars.name` has no uniqueness constraint in the schema, so two bars with
the same name will both appear "active" (or neither will), and tapping the
non-active same-named bar becomes a silent no-op (`onTap: isActive ? null : ...`).

**U11. Bar renames don't propagate to sibling screens.**
`my_bar_screen.dart:737-776` (`_showRenameBarDialog`) and
`finder_screen.dart:1139-1190` (same method) both update the renamed bar in
their own local state only — neither calls `widget.onBarChanged` or
`widget.onBarSwitched` afterward. `MainNavigationScreen._activeBarName`
(`main.dart:100`) and the Home screen header it feeds keep showing the old
name until an unrelated refresh happens to fire.

**U12. `my_bar_screen.dart:206-229` `_openCategory` has no generation token.**
Opening category A kicks off a per-ingredient `await` loop
(`computeUnlockDelta`); if the user backs out and opens category B before it
finishes, A's results are applied via `setState` after B's, since there is no
check that `_activeCategoryFilter` is still A when the loop completes.

**U13. Finder's mode filter is permanently stuck on "Can Make."**
`finder_screen.dart:60` initializes `_FinderMode _mode = _FinderMode.canMake;`
and it is **never reassigned anywhere else in the 3,680-line file** (verified
by search — the only occurrences of `_mode = ...` are that one
initialization). The `oneAway` and `all` branches of the switch at
`finder_screen.dart:529-535` are unreachable dead code, and any UI that was
meant to let a user switch modes either doesn't exist or is disconnected.

**U14. `ai_service.dart:43` difficulty parsing will crash on a float from the LLM.**
```dart
difficulty: (json['difficulty'] as int? ?? 2).clamp(1, 5),
```
Dart's `jsonDecode` produces a `double` for any JSON number with a decimal
point. If the model ever emits `"difficulty": 2.0` (a plausible LLM
formatting choice, since the system prompt's schema only shows
`"difficulty": 1` as an example with no explicit type constraint), this cast
throws a `TypeError` instead of parsing. `AiIngredient.amount` (line 82)
correctly uses `as num?`; `difficulty` should too.

**U15. Creator/AI-generator AppBar close buttons are tappable mid-save.**
`cocktail_creator_screen.dart:498-501` and `ai_generator_screen.dart:163-166`
both wire their `Icons.close` button to a bare `Navigator.pop(context)` with
no check against `_isSaving`/`_isGenerating`. Because the actual DB
transaction and quota-increment (`cocktail_creator_screen.dart:311-344`,
`ai_generator_screen.dart:107-127`) run to completion regardless of whether
the widget is still mounted, tapping close mid-save consumes the user's
create/AI quota and durably saves the cocktail, but the confirmation screen
navigation is silently skipped (guarded by `if (mounted)`) — the user is left
thinking they cancelled when they didn't.

**U16. `back_bar_screen.dart` limit checks have no try/catch.**
`_handleCreateTap` (151-174) and `_handleAiTap` (176-210) both call
`auth.canCreateCocktail(...)` / `auth.canUseAi(...)` directly, which
internally hit Firestore via `getUserLimits()` (`auth_service.dart:229-241`).
If that read throws (offline, permission error), the tap silently does
nothing rather than showing a friendly message — contrast with the
`_CreateTabState._loadData` method a few lines above, which *does* wrap its
equivalent read in try/catch.

**U17. `finder_screen.dart`'s bar create/rename flows never push to Firestore.**
`_createNewBar` (1036-1137) and `_showRenameBarDialog` (1139-1190) both write
directly to the local `SavedBars` table but never call
`UserSyncService(...).pushBars(uid)` — there is no reference to
`UserSyncService` anywhere in `finder_screen.dart` (verified by search).
Compare `my_bar_screen.dart`, which calls `_pushBarsToCloud()` after every
equivalent mutation (create, clear, delete, toggle). A bar created or renamed
from the Finder tab's bar selector will not appear on the user's other
devices.

---

## 4. Overcomplicated / architecture debt

**A1. The entire "create new bar" flow is duplicated near-verbatim between two files.**
`my_bar_screen.dart:667-735` (`_createNewBar`) + `625-665`
(`_scheduleCreateHydration`) and `finder_screen.dart:1036-1137`
(`_createNewBar`) + `970-1034` (`_scheduleDeferredBarRefresh`) — same
two-phase optimistic-insert/deferred-hydration pattern, same
`_nextAutoBarName` helper (`my_bar_screen.dart:251-260`,
`finder_screen.dart:149-158`, byte-for-byte identical), same
`BarCreateDiagnosticsFlow` wiring, same rename dialog. *Suggestion: extract a
shared `BarCreationController`/mixin used by both screens.*

**A2. Elaborate stall-detector instrumentation is permanently shipped in two large screens.**
`core/utils/bar_create_diagnostics.dart` (139 lines) — a `Timer.periodic`
main-thread-stall detector plus step/counter logging — is wired into both
`my_bar_screen.dart` and `finder_screen.dart`'s bar-creation paths. It's
`kDebugMode`-gated so it's a no-op in release builds, but it reads as
debugging scaffolding from a specific past performance investigation that
was never cleaned up. *Suggestion: remove once the underlying stall issue is
confirmed resolved, or move to a dev-only branch/flag.*

**A3. `finder_screen.dart` is 3,680 lines with a blanket lint suppression.**
Line 1: `// ignore_for_file: unused_element, prefer_final_fields`. This
silences exactly the class of dead-code warning that would have flagged the
unreachable `_FinderMode` branches (U13) automatically. *Suggestion: split
into smaller widgets/files and remove the suppression to let the linter do
its job.*

**A4. Cocktail-matching logic is implemented independently in at least two places.**
`core/utils/bar_analytics.dart`'s `BarAnalytics` class computes "which
cocktails can I make" via canonical-ingredient-set intersection. `my_bar_screen.dart:374-418`
(`_ensureMatchDataLoaded`/`_computeExactMatchCocktailIds`) implements the same
computation again from scratch inside the screen's state, and
`finder_screen.dart` has its own parallel snapshot/matching machinery too.
Three independent implementations of the same core domain rule are a
correctness risk if one is tweaked without the others.

**A5. Inconsistent access pattern for services.**
`AuthService` and `PurchaseService` are provided app-wide via `Provider` and
read with `context.read<T>()`. `UserSyncService(widget.database)` and
`FirestoreSyncService(widget.database)`, by contrast, are freshly constructed
inline at nearly every call site across ~8 files (`favorite_button.dart`,
`collections_screen.dart`, `my_bar_screen.dart`,
`admin_cocktail_editor_screen.dart`, `settings_screen.dart`,
`cocktail_creator_screen.dart`, `ai_generator_screen.dart`,
`cocktail_detail_screen.dart`, `user_cocktail_detail_screen.dart`) instead of
following the same DI pattern already established in the app.

**A6. Vestigial calculation in `cocktail_detail_screen.dart:392-400`.**
Inside the `SliverAppBar`'s `LayoutBuilder`, a collapse-fraction is computed
and `.clamp(0.0, 1.0)`'d but the result is never assigned to anything or
used — dead expression statement, almost certainly a leftover from a removed
fade effect.

---

## 5. Obsolete / dead code

**Certain — zero references anywhere in `lib/` (verified by search):**

- `lib/core/models/cocktail_recommendation.dart` — file body is just
  `// This file has been removed as part of the 1.0 Blueprint refactor.`
- `lib/core/services/taste_preferences_service.dart` — same, stub comment only.
- `lib/core/services/taste_profile_service.dart` — same, stub comment only.
- `lib/widgets/bartenders_choice_card.dart` — same, stub comment only.
- `lib/widgets/cocktail_scroll_section.dart` — same, stub comment only.
- `lib/widgets/home_hero_card.dart` — same, stub comment only.
- `lib/widgets/your_taste_card.dart` — same, stub comment only.
  (All seven are placeholder files left over from a "1.0 Blueprint refactor"
  — safe to delete outright.)
- `lib/screens/builder_screen.dart` — the entire 1,423-line `BuilderScreen`
  class is never imported or instantiated anywhere else in `lib/`. It's an
  older "pick ingredients, see matching cocktails" screen, superseded by the
  My Bar + Finder tabs, which duplicate its ingredient/cocktail-matching
  purpose with a different (and now sole) implementation.
- `lib/widgets/favorite_button.dart:155-243` — `FavoriteIconCompact` is
  defined but never referenced anywhere else. Note also that if it were ever
  wired up, its `_toggleFavorite` (189-216) never calls
  `UserSyncService(...).pushFavourites(uid)` the way `FavoriteButton` does
  (line 85) — it would silently fail to sync.

**Probable — currently unreachable given today's navigation, but not literally unused code:**

- `back_bar_screen.dart:196-209` — the `if (created == true && mounted) { await auth.incrementAiCreditsUsed(...); ... }` block after `Navigator.push<bool>(... AiGeneratorScreen ...)`. `AiGeneratorScreen` always finishes via `Navigator.pushReplacement` (`ai_generator_screen.dart:138-146`), never via `Navigator.pop(context, true)`, so `created` can never actually be `true` through this path and the credit-increment call never fires. It is a landmine, not just dead weight: `ai_generator_screen.dart:127` already increments the AI credit right after saving, so if a future refactor changes the generator's navigation to `pop(context, true)` (mirroring what `cocktail_creator_screen.dart:365` does for edits), this dormant code would silently reintroduce a double-spend of the user's AI credit.
- `finder_screen.dart:23,530-535` — `_FinderMode.oneAway` and `_FinderMode.all` enum values and their switch branches (see U13 above for the user-facing angle).

---

## 6. Cosmetic / style

- `collections_screen.dart:121-122` — `nameController`/`descController` in
  `_createCollection`'s dialog are created fresh each call and never
  `.dispose()`d.
- `cocktail_detail_screen.dart:168` — raw exception text
  (`'Error loading cocktail: $e'`) shown directly to the user in a SnackBar.
- `favorites_screen.dart:58-69` — `_viewCocktailDetail` has no re-entrancy
  guard; a fast double-tap can push the detail route twice.
- `my_bar_tab_screen.dart:69-118` — all four tabs (My Bar + 3 `FinderScreen`
  instances) are constructed directly as `TabBarView` children, so all four
  eager-load on mount instead of lazily per-tab.
- `ai_service.dart:97-111,172-191` — the Anthropic API key is fetched from
  Firebase Remote Config but then used directly in a client-side
  `http.post` to `api.anthropic.com`. Remote Config only obscures the key at
  rest in the binary; it is still fully present in the app's outgoing
  network traffic and process memory on every generation, so it's
  recoverable via a simple proxy/MITM regardless. Combined with the AI-credit
  limit being enforced only in Dart (see §8 security note), a user who
  extracts the key could call the API directly with no quota at all.
- `database.dart:162` — `schemaVersion` bumped 18 → 19 in the same commit
  (`6a67653`) as an unrelated logic change, with no accompanying
  schema/table change and no new `if (from <= 18)` migration branch.
  Confirmed intentional/harmless no-op (verified via `git show`), but worth a
  one-line comment so a future reader doesn't mistake it for a forgotten
  migration.
- `settings_screen.dart:299` vs `:598` — two different hardcoded version
  strings ("Version 1.2.1 (Build 19)" in the Credits dialog vs
  "1.3.0 (Build 20)" in the Version tile's subtitle), and neither matches
  `pubspec.yaml`'s actual `1.3.0+25`. Neither reads from
  `package_info_plus`/`PackageInfo`.
- `settings_screen.dart:412-418` — the admin "Add New Cocktail" tile
  (subtitle: "Add directly to the live database") navigates to
  `AdminCocktailEditorScreen` without passing `saveLive: true`, so the pushed
  screen's AppBar reads "NEW DRAFT" (`admin_cocktail_editor_screen.dart:449-453`)
  instead of "ADD COCKTAIL" — even though both the Save-Draft and
  Publish-Live buttons are shown regardless of that flag.
- `finder_screen.dart:1` — blanket `// ignore_for_file: unused_element,
  prefer_final_fields` suppression (see A3).

---

## 7. Already-fixed confirmations

Verified against the current code on disk:

- **Favorites/collections keyed on stable `firestoreId`** — confirmed.
  `Favorites`/`CollectionCocktails` tables use `firestoreId` as the join key
  (`database.dart:62-67,134-141`), and
  `user_cocktail_detail_screen.dart:51-54`'s `_favoritesKey` getter correctly
  guards on it.
- **AI-credit / create-quota spend only after durable save** — confirmed.
  `cocktail_creator_screen.dart:340-344` increments only after the
  `database.transaction(...)` completes; `ai_generator_screen.dart:126-127`
  follows the same pattern.
- **Deleted user cocktails no longer resurrect from a failed delete** —
  confirmed. `user_sync_service.dart:307-367`'s
  `deleteUserCocktailFromFirestore` + `_addPendingDelete`/`_flushPendingDeletes`
  is wired correctly from `user_cocktail_detail_screen.dart:106-115`. (Note:
  a *related* but distinct gap remains — see C7 above — around cocktails
  deleted on another device never being pruned by a normal pull.)
- **`AuthService.isEffectivelyPremium` wired into all named gating call
  sites** — confirmed across `main.dart`, `home_screen.dart`,
  `finder_screen.dart`, `back_bar_screen.dart`, `cocktail_creator_screen.dart`,
  and `ai_generator_screen.dart`.
- **`admin_cocktail_editor_screen.dart` validation batch** — confirmed:
  name-required guard before image upload (202-210), Ice "Other" validation
  (367-372), ingredient-required validation (373-378), and
  auto-sync-to-local-cache after a live publish (411-419) are all present and
  correct. **However**, the closely-related legacy `tags`-as-String cast in
  the same screen's `initState` was *not* fixed — see C2 above; don't
  mistake it for part of this fixed batch.
- **Admin-only "Simulate Non-Premium" toggle** — confirmed.
  `auth_service.dart:41-58` implements it correctly, gated behind
  `auth.isAdmin` in `settings_screen.dart:431-443`.

---

## 8. Security/config note (not separately categorized above)

The app's premium/quota model (`is_admin`, `is_premium`, `creates_used`,
`ai_credits_used*` fields on the Firestore `users/{uid}` document) is read
and incremented entirely from the client
(`auth_service.dart:229-310`, `admin_user_management_screen.dart:74-234`).
No `firestore.rules` file exists anywhere in this repository, so this audit
cannot confirm server-side enforcement of who may write `is_admin`/`is_premium`
on their own user document, or that quota fields can only be incremented and
never decremented/reset by the client. If the deployed Firestore rules don't
independently lock these fields down, a modified client could grant itself
premium/admin or reset its own usage counters directly. This is a
configuration risk to verify outside this codebase, not a confirmed bug.
