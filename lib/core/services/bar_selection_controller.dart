import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../data/database.dart';
import 'bar_service.dart';

/// Single source of truth for the app's active bar + bar list.
///
/// Provided app-wide via [ChangeNotifierProvider] in main.dart. Every screen
/// that shows or manages bars (Home, My Bar, Finder ×3) listens to this and
/// reacts to changes made from *any* of them — that's the whole point: swap
/// bars in one place and it's reflected everywhere.
///
/// This owns the raw DB reads/writes for bar CRUD (previously duplicated
/// almost verbatim across MyBarScreen and FinderScreen). It does NOT own
/// each screen's own derived data (ingredient sets, cocktail matches,
/// analytics) — that stays local to each screen, recomputed in response to
/// this controller's notifications.
class BarSelectionController extends ChangeNotifier {
  final AppDatabase db;
  late final BarService _barService = BarService(db);

  BarSelectionController(this.db);

  SavedBar? _activeBar;
  List<SavedBar> _savedBars = const [];
  Timer? _contentsChangedDebounce;
  bool _loaded = false;
  Future<void>? _initialLoad;

  SavedBar? get activeBar => _activeBar;
  List<SavedBar> get savedBars => _savedBars;

  @override
  void dispose() {
    _contentsChangedDebounce?.cancel();
    super.dispose();
  }

  /// Screens' own passive reloads — the ones triggered BY this controller's
  /// notifyListeners(), e.g. "someone else switched bars, let me re-render"
  /// — must call this, never [refresh] directly. [refresh] itself notifies,
  /// so calling it from inside a listener callback re-triggers every other
  /// screen's listener, which (if any of them also call refresh from their
  /// own passive path) re-notifies again — an infinite reload loop that
  /// pegs the main thread. This resolves to the controller's one
  /// in-flight/initial load and is a no-op (no DB round-trip, no notify)
  /// once that's done. Bar identity only ever changes via the mutation
  /// methods below, which already call refresh()/notify themselves.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _initialLoad ??= refresh();
  }

  /// Pings listeners that the active bar's *contents* changed (an ingredient
  /// was added/removed) without touching the bar list or active bar itself.
  /// Debounced so rapid-fire ingredient taps behind the bar during service
  /// don't force every screen to reload on every single tap.
  void notifyBarContentsChanged() {
    _contentsChangedDebounce?.cancel();
    _contentsChangedDebounce = Timer(const Duration(milliseconds: 250), () {
      notifyListeners();
    });
  }

  Future<List<SavedBar>> _loadBarsOrdered() =>
      (db.select(db.savedBars)
            ..orderBy([(b) => OrderingTerm.desc(b.lastUsed)]))
          .get();

  /// Reloads the active bar + bar list from DB truth. Bootstraps a default
  /// "My Bar" if none exists yet (fresh install).
  Future<void> refresh() async {
    var bars = await _loadBarsOrdered();
    var active = await db.getDefaultSavedBar();

    if (active == null && bars.isEmpty) {
      final id = await db.into(db.savedBars).insert(
            SavedBarsCompanion.insert(
              name: 'My Bar',
              isDefault: const Value(true),
            ),
          );
      bars = await _loadBarsOrdered();
      active = bars.firstWhere((b) => b.id == id, orElse: () => bars.first);
    }
    active ??= bars.isNotEmpty ? bars.first : null;

    _activeBar = active;
    _savedBars = bars;
    _loaded = true;
    notifyListeners();
  }

  String nextAutoBarName() {
    final names = _savedBars.map((b) => b.name.trim().toLowerCase()).toSet();
    const base = 'new bar';
    if (!names.contains(base)) return 'New Bar';
    var index = 2;
    while (names.contains('$base $index')) {
      index++;
    }
    return 'New Bar $index';
  }

  Future<void> switchTo(int barId) async {
    if (_activeBar?.id == barId) return;
    await _barService.setDefaultBar(barId);
    await refresh();
  }

  /// Creates a new bar and makes it the default. Pass [name] for a
  /// user-chosen name (trimmed); omitted or blank falls back to
  /// [nextAutoBarName].
  Future<SavedBar> createBar({String? name}) async {
    final now = DateTime.now();
    final chosenName = (name != null && name.trim().isNotEmpty) ? name.trim() : nextAutoBarName();
    final id = await db.into(db.savedBars).insert(
          SavedBarsCompanion.insert(
            name: chosenName,
            isDefault: const Value(true),
            lastUsed: Value(now),
          ),
        );
    await _barService.setDefaultBar(id);
    await refresh();
    return _savedBars.firstWhere(
      (b) => b.id == id,
      orElse: () => SavedBar(
        id: id,
        name: chosenName,
        isDefault: true,
        createdAt: now,
        lastUsed: now,
      ),
    );
  }

  Future<void> renameBar(int barId, String name) async {
    await (db.update(db.savedBars)..where((b) => b.id.equals(barId)))
        .write(SavedBarsCompanion(name: Value(name)));
    await refresh();
  }

  /// Removes all ingredients from [barId]. Does not change the bar list or
  /// active bar, so this only needs to notify — listeners re-derive their
  /// own ingredient/match state from DB truth.
  Future<void> clearBar(int barId) async {
    await (db.delete(db.savedBarIngredients)
          ..where((bi) => bi.savedBarId.equals(barId)))
        .go();
    notifyListeners();
  }

  /// Deletes [bar]. Refuses if it's the last remaining bar. Ensures a
  /// default exists among whatever remains afterward.
  Future<void> deleteBar(SavedBar bar) async {
    if (_savedBars.length <= 1) return;

    await (db.delete(db.savedBarIngredients)
          ..where((row) => row.savedBarId.equals(bar.id)))
        .go();
    await (db.delete(db.savedBars)..where((row) => row.id.equals(bar.id)))
        .go();

    final remaining = await _loadBarsOrdered();
    if (remaining.isEmpty) {
      _activeBar = null;
      _savedBars = const [];
      notifyListeners();
      return;
    }

    final hasDefault = remaining.any((b) => b.isDefault);
    final activeStillExists =
        _activeBar != null && remaining.any((b) => b.id == _activeBar!.id);
    if (!hasDefault || !activeStillExists) {
      await _barService.setDefaultBar(remaining.first.id);
    }
    await refresh();
  }
}
