import '../../data/database.dart';
import '../../data/ingredient_data.dart';

/// Computes analytics about the user's bar: unlock counts, smart suggestions,
/// bar level, etc. Shared between My Bar and Finder screens.
class BarAnalytics {
  final AppDatabase database;

  BarAnalytics(this.database);

  /// Compute how many cocktails the current bar can make (exact + with subs).
  /// Also returns the "smart suggestion" — the single ingredient that would
  /// unlock the most new cocktails if added.
  Future<BarAnalyticsResult> compute() async {
    // 1. Load bar
    final bar = await database.getDefaultSavedBar();
    if (bar == null) return BarAnalyticsResult.empty();

    final barIngredients = await database.getSavedBarIngredients(bar.id);
    final barIds = barIngredients.map((i) => i.id).toSet();
    if (barIds.isEmpty) return BarAnalyticsResult.empty();

    // 2. Load all data
    final allCocktails = await database.select(database.cocktails).get();
    final allIngredients = await database.select(database.ingredients).get();
    final ingredientMap = {for (var i in allIngredients) i.id: i};

    // Build canonical sets
    final Set<String> barCanonicals = {};
    for (final id in barIds) {
      final name = ingredientMap[id]?.name;
      if (name != null) barCanonicals.add(IngredientEquivalence.normalise(name));
    }

    final Set<String> barSubCanonicals = {};
    for (final canon in barCanonicals) {
      barSubCanonicals.addAll(IngredientSubstitutions.getSubstitutes(canon));
    }

    int exactCount = 0;
    int closeCount = 0; // missing 1
    // Track which ingredient canonical names are "missing 1" across all cocktails
    final Map<String, int> missingIngredientUnlocks = {};

    for (final cocktail in allCocktails) {
      final ciRows = await (database.select(database.cocktailIngredients)
            ..where((ci) => ci.cocktailId.equals(cocktail.id)))
          .get();
      if (ciRows.isEmpty) continue;

      // Deduplicate by canonical
      final Map<String, String> requiredCanonToDisplay = {};
      for (final ci in ciRows) {
        final name = ingredientMap[ci.ingredientId]?.name;
        if (name == null) continue;
        final canon = IngredientEquivalence.normalise(name);
        requiredCanonToDisplay.putIfAbsent(canon, () => name);
      }
      if (requiredCanonToDisplay.isEmpty) continue;

      final List<String> missingCanons = [];
      for (final canon in requiredCanonToDisplay.keys) {
        if (!barCanonicals.contains(canon) && !barSubCanonicals.contains(canon)) {
          missingCanons.add(canon);
        }
      }

      if (missingCanons.isEmpty) {
        exactCount++;
      } else if (missingCanons.length == 1) {
        closeCount++;
        // This cocktail would be unlocked if user added this one ingredient
        final missingCanon = missingCanons.first;
        missingIngredientUnlocks[missingCanon] =
            (missingIngredientUnlocks[missingCanon] ?? 0) + 1;
      }
    }

    // Find the best suggestion
    SmartSuggestion? suggestion;
    if (missingIngredientUnlocks.isNotEmpty) {
      final sorted = missingIngredientUnlocks.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final best = sorted.first;

      // Find a display name for this canonical
      String displayName = best.key;
      for (final ing in allIngredients) {
        if (IngredientEquivalence.normalise(ing.name) == best.key) {
          displayName = ing.name;
          break;
        }
      }

      // Find some cocktail names this would unlock
      final List<String> unlockNames = [];
      for (final cocktail in allCocktails) {
        if (unlockNames.length >= 3) break;
        final ciRows = await (database.select(database.cocktailIngredients)
              ..where((ci) => ci.cocktailId.equals(cocktail.id)))
            .get();

        final Map<String, String> required = {};
        for (final ci in ciRows) {
          final name = ingredientMap[ci.ingredientId]?.name;
          if (name == null) continue;
          final canon = IngredientEquivalence.normalise(name);
          required.putIfAbsent(canon, () => name);
        }

        final missing = required.keys.where(
          (c) => !barCanonicals.contains(c) && !barSubCanonicals.contains(c),
        ).toList();

        if (missing.length == 1 && missing.first == best.key) {
          unlockNames.add(cocktail.name);
        }
      }

      suggestion = SmartSuggestion(
        ingredientName: displayName,
        canonicalName: best.key,
        unlocksCount: best.value,
        exampleCocktails: unlockNames,
      );
    }

    // Category breakdown of bar
    final Map<String, int> categoryBreakdown = {};
    for (final id in barIds) {
      final ing = ingredientMap[id];
      if (ing != null) {
        categoryBreakdown[ing.category] = (categoryBreakdown[ing.category] ?? 0) + 1;
      }
    }

    return BarAnalyticsResult(
      ingredientCount: barIds.length,
      exactMatchCount: exactCount,
      closeMatchCount: closeCount,
      totalCocktails: allCocktails.length,
      barLevel: _computeLevel(barIds.length),
      suggestion: suggestion,
      categoryBreakdown: categoryBreakdown,
    );
  }

  /// Compute how many NEW cocktails adding a specific ingredient would unlock.
  /// Used for the "+N" animation on toggle.
  Future<int> computeUnlockDelta(int ingredientId, bool adding) async {
    final bar = await database.getDefaultSavedBar();
    if (bar == null) return 0;

    final barIngredients = await database.getSavedBarIngredients(bar.id);
    final allIngredients = await database.select(database.ingredients).get();
    final ingredientMap = {for (var i in allIngredients) i.id: i};

    // Build current bar canonicals
    Set<String> barCanonicals = {};
    for (final bi in barIngredients) {
      final name = bi.name;
      barCanonicals.add(IngredientEquivalence.normalise(name));
    }

    // Build sub-reachable
    Set<String> barSubCanonicals = {};
    for (final canon in barCanonicals) {
      barSubCanonicals.addAll(IngredientSubstitutions.getSubstitutes(canon));
    }

    // Simulate adding/removing
    final targetName = ingredientMap[ingredientId]?.name;
    if (targetName == null) return 0;
    final targetCanon = IngredientEquivalence.normalise(targetName);

    Set<String> newBarCanonicals;
    Set<String> newBarSubCanonicals;

    if (adding) {
      newBarCanonicals = {...barCanonicals, targetCanon};
      newBarSubCanonicals = {...barSubCanonicals};
      newBarSubCanonicals.addAll(IngredientSubstitutions.getSubstitutes(targetCanon));
    } else {
      newBarCanonicals = {...barCanonicals}..remove(targetCanon);
      // Rebuild subs without this ingredient
      newBarSubCanonicals = {};
      for (final canon in newBarCanonicals) {
        newBarSubCanonicals.addAll(IngredientSubstitutions.getSubstitutes(canon));
      }
    }

    // Count cocktails makeable before and after
    final allCocktails = await database.select(database.cocktails).get();
    int beforeCount = 0;
    int afterCount = 0;

    for (final cocktail in allCocktails) {
      final ciRows = await (database.select(database.cocktailIngredients)
            ..where((ci) => ci.cocktailId.equals(cocktail.id)))
          .get();
      if (ciRows.isEmpty) continue;

      final Map<String, String> required = {};
      for (final ci in ciRows) {
        final name = ingredientMap[ci.ingredientId]?.name;
        if (name == null) continue;
        final canon = IngredientEquivalence.normalise(name);
        required.putIfAbsent(canon, () => name);
      }
      if (required.isEmpty) continue;

      // Check before
      final missingBefore = required.keys.where(
        (c) => !barCanonicals.contains(c) && !barSubCanonicals.contains(c),
      ).length;
      if (missingBefore == 0) beforeCount++;

      // Check after
      final missingAfter = required.keys.where(
        (c) => !newBarCanonicals.contains(c) && !newBarSubCanonicals.contains(c),
      ).length;
      if (missingAfter == 0) afterCount++;
    }

    return afterCount - beforeCount;
  }

  static BarLevel _computeLevel(int ingredientCount) {
    if (ingredientCount == 0) return BarLevel.empty;
    if (ingredientCount <= 5) return BarLevel.starter;
    if (ingredientCount <= 15) return BarLevel.homeBartender;
    if (ingredientCount <= 30) return BarLevel.wellStocked;
    return BarLevel.professional;
  }
}

enum BarLevel {
  empty(label: 'Empty Bar', icon: '🪹', nextThreshold: 1),
  starter(label: 'Getting Started', icon: '🥉', nextThreshold: 6),
  homeBartender(label: 'Home Bartender', icon: '🥈', nextThreshold: 16),
  wellStocked(label: 'Well Stocked', icon: '🥇', nextThreshold: 31),
  professional(label: 'Professional Setup', icon: '💎', nextThreshold: 999);

  final String label;
  final String icon;
  final int nextThreshold;
  const BarLevel({required this.label, required this.icon, required this.nextThreshold});
}

class BarAnalyticsResult {
  final int ingredientCount;
  final int exactMatchCount;
  final int closeMatchCount;
  final int totalCocktails;
  final BarLevel barLevel;
  final SmartSuggestion? suggestion;
  final Map<String, int> categoryBreakdown;

  BarAnalyticsResult({
    required this.ingredientCount,
    required this.exactMatchCount,
    required this.closeMatchCount,
    required this.totalCocktails,
    required this.barLevel,
    this.suggestion,
    required this.categoryBreakdown,
  });

  factory BarAnalyticsResult.empty() => BarAnalyticsResult(
        ingredientCount: 0,
        exactMatchCount: 0,
        closeMatchCount: 0,
        totalCocktails: 0,
        barLevel: BarLevel.empty,
        categoryBreakdown: {},
      );

  double get unlockPercentage =>
      totalCocktails > 0 ? exactMatchCount / totalCocktails : 0;
}

class SmartSuggestion {
  final String ingredientName;
  final String canonicalName;
  final int unlocksCount;
  final List<String> exampleCocktails;

  SmartSuggestion({
    required this.ingredientName,
    required this.canonicalName,
    required this.unlocksCount,
    required this.exampleCocktails,
  });
}
