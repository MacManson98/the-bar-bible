# The Bar Bible — Fix Batch 1 Follow-Up (Claude Code prompt)

Paste into a fresh Claude Code session at `C:\flutter_projects\BartenderApp\the_bar_bible`.

This follows directly on from the previous fix batch (startup hang, crash
fixes, bar-sync completeness, firestore.rules committed). Scope here: confirm
Group 5 from that batch actually landed, plus two small fixes found during
live testing of that batch.

---

## Prompt to paste

```
Continuing work on "The Bar Bible" (Flutter/Dart, Firebase, RevenueCat,
Drift/SQLite, Provider) right after a previous fix batch. Same ground rules
as before: inspect before editing, verify against the actual filesystem,
match existing patterns, run `flutter analyze` after each group and resolve
new issues before moving on, commit locally per group, do not push.

## Group A — Confirm/complete dead-code deletion

Check whether these are still present. If any still exist, grep the whole
`lib/` tree yourself to confirm zero references, then delete:

- `lib/core/models/cocktail_recommendation.dart`
- `lib/core/services/taste_preferences_service.dart`
- `lib/core/services/taste_profile_service.dart`
- `lib/widgets/bartenders_choice_card.dart`
- `lib/widgets/cocktail_scroll_section.dart`
- `lib/widgets/home_hero_card.dart`
- `lib/widgets/your_taste_card.dart`
- `lib/screens/builder_screen.dart`
- `FavoriteIconCompact` class inside `lib/widgets/favorite_button.dart`
  (delete just that class, keep `FavoriteButton`, remove now-unused imports)

If they're already gone (deleted in the previous batch), just confirm that
in your summary and move on — no need to re-commit anything.

## Group B — my_bar_screen.dart rename doesn't push to cloud

`finder_screen.dart`'s `_showRenameBarDialog` was already fixed to call
`UserSyncService(widget.database).pushBars(uid)` after a successful rename.
`my_bar_screen.dart`'s `_showRenameBarDialog` has the identical gap — it
renames locally but never pushes to Firestore, unlike its own
`_createNewBar`/delete/clear flows which already call
`_pushBarsToCloud()`. Add the same call after a successful rename in
`my_bar_screen.dart`, matching the pattern already used elsewhere in that
same file.

## Group C — Dialog dispose-during-transition crash

Found live in `my_bar_screen.dart` and `finder_screen.dart` (both have an
identical `_showRenameBarDialog`): the `TextEditingController` used by the
rename dialog's `TextField` is disposed synchronously right after
`showDialog()` returns. If the dialog's closing transition is still
rebuilding the `TextField` when that happens, it throws "A TextEditingController
was used after being disposed" as a fatal widget-tree assertion.

Fix in both files: don't dispose the controller immediately after
`showDialog()` resolves. Either defer disposal to the next frame with
`WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose())`,
or restructure so the controller is only disposed once you're certain the
dialog's route has fully been removed (e.g. via the route's own popped
future/animation status) rather than right after the awaited `showDialog`
call returns. Pick whichever fits the existing code shape better once
you've inspected it — keep the fix minimal.

## Final summary

Report: dead-code status (already done / freshly deleted / any skipped and
why), confirmation the my_bar_screen.dart rename now pushes to Firestore,
confirmation the dispose crash is fixed in both files, and whether
`flutter analyze` is clean.
```
