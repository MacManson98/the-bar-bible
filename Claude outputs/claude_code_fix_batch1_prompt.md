# The Bar Bible — Fix Batch 1 (Claude Code prompt)

Paste the block below into a fresh Claude Code session opened at
`C:\flutter_projects\BartenderApp\the_bar_bible`.

Scope: all 7 crash/data-loss items from the audit, 2 related bar-sync UX
bugs, committing `firestore.rules` into the repo, and deleting confirmed
dead code. Nothing else — no architecture refactors, no other broken-UX
items, no cosmetic changes. That's a deliberate, separate follow-up session.

---

## Prompt to paste

```
You're fixing a specific, pre-agreed batch of issues in "The Bar Bible"
(Flutter/Dart, Firebase Auth/Firestore/Storage, RevenueCat, Drift/SQLite,
Provider). These issues were found by a full-codebase audit
(AUDIT_REPORT.md at the repo root, if present — read it for full context on
each item below).

Ground rules:
- Inspect each file before editing it. Some line numbers below may have
  drifted since the audit — find the real current location.
- Scope discipline: fix ONLY the items listed below. Do not touch anything
  else, even if you notice other issues while in these files — note them in
  your final summary instead.
- Match existing patterns (Provider for state, the try/catch + log() error
  style already used in user_sync_service.dart, the `_pushBarsToCloud()`
  pattern already in my_bar_screen.dart).
- Run `flutter analyze` after each group below and resolve any new
  errors/warnings before moving to the next group.
- Commit locally after each group with a descriptive message. Do NOT push.
- Before deleting any file, grep the whole `lib/` tree yourself to confirm
  zero references — don't take the audit's word for it, verify fresh.

## Group 1 — Startup hang (C1)

`main.dart` awaits `purchaseService.loginUser(uid)` and
`userSyncService.pullFromFirestore(uid)` for an already-signed-in user
before `runApp()` — neither has a timeout, so a stalled network call blocks
the entire app from ever rendering, not even the splash screen.

Fix: wrap both calls with a reasonable timeout (e.g. 8-10 seconds) and a
try/catch, so a hang or failure logs and falls through to `runApp()`
regardless — the user should see the app (possibly with stale/local-only
data) rather than a blank screen.

Separately, `splash_screen.dart`'s `_init()` does
`await Future.wait([widget.onReady(), Future.delayed(...)])` with no
try/catch or timeout. Apply the same treatment: timeout + catch around
`widget.onReady()` specifically, so a stalled sync doesn't strand the user
on the splash screen forever. `_ready` should still become `true` after the
timeout/failure.

## Group 2 — Crash fixes (C2-C6)

**C2**: `admin_cocktail_editor_screen.dart` `initState()` — the tags parsing
line does `(d['tags'] as List?)?.join(', ') ?? d['tags'] as String? ?? ''`,
which throws when `d['tags']` is a non-null String (legacy data format).
Fix by checking the runtime type first (`is List` / `is String`) instead of
an unsafe cast, so both old (String) and new (List) formats parse without
throwing.

**C3**: `paywall_screen.dart` — the restore-purchase handler's second
`setState()` call (after `await purchaseService.restorePurchases()`) has no
`mounted` check. Add one, matching the guard already used elsewhere in the
same handler.

**C4**: `admin_user_management_screen.dart` `_toggleAdmin` and
`_togglePremium` — both check `mounted` before their Firestore `.update()`
call but not after. Add a `mounted` check immediately before the
post-await `setState()` in both methods.

**C5**: `add_cocktails_dialog.dart` — the picker row's `onTap` awaits a DB
insert/delete then calls `setState(() {})` with no liveness check. Add a
`mounted` guard (this is a dialog/widget, not necessarily a `State` with
the same lifecycle as a screen — use whatever the correct liveness check is
for this widget's actual type once you've inspected it).

**C6**: `my_bar_screen.dart` `_switchToBar` calls `.getSingle()` on a query
that can return zero rows (bar deleted concurrently) — throws `StateError`
uncaught. Change to `.getSingleOrNull()`, and on null show a friendly
message (e.g. "That bar no longer exists") and refresh the bar list /
fall back to the default bar, rather than crashing.

## Group 3 — Bar sync completeness (C7, U11, U17)

These three are related — all about the local/cloud bar data model not
staying consistent — so fix together and test the full bar
create/rename/switch/sync flow end-to-end afterward.

**C7**: `user_sync_service.dart` `pullUserCocktails` only adds/updates from
the Firestore snapshot, never removes a local user-cocktail whose
`firestoreId` is missing from that snapshot. Fix by, inside the same
transaction, diffing local `firestoreId`s against the snapshot's doc IDs and
deleting any local rows not present remotely (and their
`UserCocktailIngredients` rows) — this makes a delete that happened on
another device actually take effect locally on the next pull.

**U11**: `my_bar_screen.dart` and `finder_screen.dart` both have a
`_showRenameBarDialog` method that updates the renamed bar in local state
only, never calling back up to update
`MainNavigationScreen._activeBarName` (`main.dart`) or whatever callback
these screens use to notify their parent of bar changes (check what
`_switchToBar`/bar-selection flows already call for this — likely
`widget.onBarChanged` or `widget.onBarSwitched`, inspect to confirm the
actual callback name and wire the rename flow to call it too, in both
files).

**U17**: `finder_screen.dart`'s `_createNewBar` and
`_showRenameBarDialog` write to the local `SavedBars` table but never push
to Firestore, unlike `my_bar_screen.dart`'s equivalent flows (which call a
`_pushBarsToCloud()`-style method after every mutation). Add the equivalent
`UserSyncService(widget.database).pushBars(uid)` call after both mutations
in `finder_screen.dart`, matching the pattern already used in
`my_bar_screen.dart`.

## Group 4 — Commit `firestore.rules` into the repo

No `firestore.rules` file exists in this repo currently, even though real
rules are deployed in the Firebase Console. Create `firestore.rules` at the
repo root with exactly this content:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.is_admin == true;
    }
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow read: if isAdmin();
      allow create: if request.auth != null
        && request.auth.uid == userId
        && !('is_admin' in request.resource.data)
        && (!('is_premium' in request.resource.data) || request.resource.data.is_premium == false);
      allow update: if request.auth != null
        && request.auth.uid == userId
        && !('is_admin' in request.resource.data.diff(resource.data).affectedKeys())
        && !('is_premium' in request.resource.data.diff(resource.data).affectedKeys())
        && (!('creates_used' in request.resource.data.diff(resource.data).affectedKeys())
            || request.resource.data.creates_used >= resource.data.creates_used)
        && (!('ai_credits_used' in request.resource.data.diff(resource.data).affectedKeys())
            || request.resource.data.ai_credits_used >= resource.data.ai_credits_used)
        && (!('ai_credits_used_today' in request.resource.data.diff(resource.data).affectedKeys())
            || request.resource.data.ai_credits_used_today >= resource.data.ai_credits_used_today);
      allow write: if isAdmin();
    }
    match /users/{userId}/user_cocktails/{docId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /cocktails/{id} {
      allow read: if true;
      allow write: if isAdmin();
    }
    match /ingredients/{id} {
      allow read: if true;
      allow write: if isAdmin();
    }
    match /cocktails_staging/{docId} {
      allow read, write: if request.auth != null;
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

This is the file already deployed live in Firebase Console (already updated
with a tightened `allow update` clause that blocks self-service quota
resets) — this step only adds it to version control, it does not change
anything live. Do not modify the content beyond what's shown above.

## Group 5 — Delete confirmed dead code

After grepping the whole `lib/` tree yourself to confirm zero references to
each of these (per the ground rules above), delete:

- `lib/core/models/cocktail_recommendation.dart`
- `lib/core/services/taste_preferences_service.dart`
- `lib/core/services/taste_profile_service.dart`
- `lib/widgets/bartenders_choice_card.dart`
- `lib/widgets/cocktail_scroll_section.dart`
- `lib/widgets/home_hero_card.dart`
- `lib/widgets/your_taste_card.dart`
- `lib/screens/builder_screen.dart`
- `FavoriteIconCompact` class inside `lib/widgets/favorite_button.dart`
  (delete just that class, keep `FavoriteButton` — check for and remove any
  now-unused imports this leaves behind in that file)

If any of these turn out to have a reference somewhere the audit missed,
skip deleting that one, note it in your summary, and move on — don't force
a deletion that breaks a build.

## Final summary

After all 5 groups are committed and `flutter analyze` is clean, tell me in
chat: which groups completed cleanly, any item you had to skip or handle
differently than described above (and why), and confirm `flutter analyze`
shows no new issues.
```
