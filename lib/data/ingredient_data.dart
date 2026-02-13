// Ingredient categories for organization
class IngredientCategory {
  static const String spirits = 'Spirits';
  static const String liqueurs = 'Liqueurs';
  static const String mixers = 'Mixers';
  static const String juices = 'Juices';
  static const String citrus = 'Citrus';
  static const String sweeteners = 'Sweeteners';
  static const String bitters = 'Bitters';
  // Garnish removed — garnish info lives in cocktail.garnish text column
  static const String coffee = 'Coffee';
  static const String other = 'Other';

  static const Map<String, String> categoryIcons = {
    spirits: '🥃',
    liqueurs: '🍷',
    citrus: '🍋',
    juices: '🍊',
    sweeteners: '🍯',
    mixers: '🥤',
    bitters: '💧',
    coffee: '☕',
    other: '📦',
  };

  static const List<String> allCategories = [
    spirits,
    liqueurs,
    citrus,
    juices,
    sweeteners,
    mixers,
    bitters,
    coffee,
    other,
  ];
}

// ─── Ingredient Equivalence Engine ───────────────────────────────────────────
//
// Two-tier matching:
//   1. NORMALISATION — strips prefixes like "Fresh", normalises casing,
//      so "Fresh Lime Juice", "Lime Juice", "Lime juice" all become
//      the canonical form "lime juice". Ingredients that normalise to
//      the same string are treated as IDENTICAL (auto-match, no sub tag).
//
//   2. SUBSTITUTIONS — explicit map for ingredients that are genuinely
//      different but can stand in for each other (e.g. Bourbon ↔ Rye).
//      These get flagged as "using subs" in the Finder.
//

class IngredientEquivalence {
  /// Prefixes stripped during normalisation (order matters — longest first).
  static const _stripPrefixes = [
    'fresh ',
    'bottled ',
    'raw ',
    'superfine ',
    'white cane ',
  ];

  /// Explicit canonical overrides for tricky names.
  /// Maps lowercase input → canonical lowercase form.
  static const Map<String, String> _canonicalOverrides = {
    'sugar syrup': 'simple syrup',
    'sugar cube': 'sugar',
    'white cane sugar': 'sugar',
    'superfine sugar': 'sugar',
    'marachino luxardo': 'maraschino luxardo',
    'angostura bitters': 'aromatic bitters',
    'goslings rum': 'dark rum',
    'gosling\'s rum': 'dark rum',
  };

  /// Normalise an ingredient name to its canonical form.
  /// "Fresh Lime Juice" → "lime juice"
  /// "Lemon juice" → "lemon juice"
  /// "Sugar Syrup" → "simple syrup"
  static String normalise(String name) {
    var n = name.trim().toLowerCase();

    // Apply explicit overrides first
    if (_canonicalOverrides.containsKey(n)) {
      return _canonicalOverrides[n]!;
    }

    // Strip common prefixes
    for (final prefix in _stripPrefixes) {
      if (n.startsWith(prefix)) {
        n = n.substring(prefix.length);
        break; // only strip one prefix
      }
    }

    return n;
  }

  /// Returns true if two ingredient names are equivalent
  /// (same canonical form).
  static bool areEquivalent(String a, String b) {
    return normalise(a) == normalise(b);
  }

  /// Build a lookup: canonical name → set of ingredient IDs that
  /// resolve to it. Used by Finder to do fast set-intersection matching.
  ///
  /// Example output:
  ///   "lime juice" → {30, 33}
  ///   "lemon juice" → {10, 19}
  static Map<String, Set<int>> buildCanonicalMap(
    List<({int id, String name})> ingredients,
  ) {
    final map = <String, Set<int>>{};
    for (final i in ingredients) {
      final canon = normalise(i.name);
      map.putIfAbsent(canon, () => {}).add(i.id);
    }
    return map;
  }
}

// ─── Explicit Substitutions ──────────────────────────────────────────────────
// These are for genuinely DIFFERENT ingredients that can stand in.
// Normalisation handles variant naming; this handles flavour swaps.

class IngredientSubstitutions {
  // Bidirectional substitution groups.
  // Each inner list = a group of interchangeable ingredients.
  // Names should be in canonical (normalised) form.
  static const List<List<String>> _groups = [
    // Orange liqueurs
    ['cointreau', 'triple sec', 'grand marnier', 'curacao'],
    // Whiskeys
    ['bourbon', 'rye whiskey', 'whiskey'],
    // Scotch ↔ whiskey (looser)
    ['scotch', 'whiskey'],
    // Light rums
    ['white rum', 'light rum', 'silver rum', 'white cuban rum'],
    // Dark rums
    ['dark rum', 'aged rum', 'spiced rum'],
    // Vermouths
    ['dry vermouth', 'white vermouth'],
    ['sweet vermouth', 'red vermouth', 'rosso vermouth'],
    // Sweeteners
    ['simple syrup', 'sugar', 'agave syrup'],
    ['honey', 'honey syrup'],
    // Bitters (loose)
    ['aromatic bitters', 'angostura bitters'],
    // Coffee liqueurs
    ['coffee liqueur', 'kahlua'],
    // Cream
    ['fresh cream', 'heavy cream', 'cream'],
    // Maraschino
    ['maraschino luxardo', 'maraschino liqueur'],
    // Sparkling
    ['champagne', 'prosecco'],
  ];

  /// Lazily built reverse index: canonical name → set of canonical substitutes.
  static Map<String, Set<String>>? _index;

  static Map<String, Set<String>> get _subIndex {
    if (_index != null) return _index!;
    _index = {};
    for (final group in _groups) {
      for (final item in group) {
        final canon = IngredientEquivalence.normalise(item);
        _index!.putIfAbsent(canon, () => {});
        for (final other in group) {
          final otherCanon = IngredientEquivalence.normalise(other);
          if (otherCanon != canon) {
            _index![canon]!.add(otherCanon);
          }
        }
      }
    }
    return _index!;
  }

  /// Check if ingredient A (by name) can substitute for ingredient B (by name).
  /// Both names are normalised before lookup.
  static bool canSubstitute(String ingredientA, String ingredientB) {
    final canonA = IngredientEquivalence.normalise(ingredientA);
    final canonB = IngredientEquivalence.normalise(ingredientB);

    // If they normalise to the same thing, they're equivalent — not a "sub"
    if (canonA == canonB) return false;

    final subs = _subIndex[canonB];
    return subs != null && subs.contains(canonA);
  }

  /// Get all substitute canonical names for an ingredient.
  static List<String> getSubstitutes(String ingredient) {
    final canon = IngredientEquivalence.normalise(ingredient);
    return _subIndex[canon]?.toList() ?? [];
  }
}

// ─── Bar Presets ─────────────────────────────────────────────────────────────

class BarPresets {
  static const Map<String, List<String>> presets = {
    'Classic Bar': [
      'Vodka',
      'Gin',
      'White Rum',
      'Bourbon',
      'Dry Vermouth',
      'Sweet Vermouth',
      'Cointreau',
      'Lemon Juice',
      'Lime Juice',
      'Sugar Syrup',
      'Angostura Bitters',
      'Soda Water',
    ],
    'Tiki Bar': [
      'White Rum',
      'Lime Juice',
      'Pineapple Juice',
      'Orange juice',
      'Falernum',
      'Sugar Syrup',
    ],
    'Whiskey Lover': [
      'Bourbon',
      'Sweet Vermouth',
      'Angostura Bitters',
      'Sugar Syrup',
      'Lemon Juice',
      'Orange Bitters',
    ],
  };

  static List<String> getPreset(String presetName) {
    return presets[presetName] ?? [];
  }

  static List<String> getAllPresetNames() {
    return presets.keys.toList();
  }
}
