// Ingredient categories for organization
class IngredientCategory {
  static const String spirits = 'Spirits';
  static const String liqueurs = 'Liqueurs';
  static const String mixers = 'Mixers';
  static const String citrus = 'Citrus';
  static const String syrups = 'Syrups';
  static const String bitters = 'Bitters';
  static const String garnish = 'Garnish';
  static const String other = 'Other';

  static const Map<String, String> categoryIcons = {
    spirits: '🥃',
    liqueurs: '🍷',
    mixers: '🥤',
    citrus: '🍋',
    syrups: '🍯',
    bitters: '💧',
    garnish: '🌿',
    other: '📦',
  };

  static const List<String> allCategories = [
    spirits,
    liqueurs,
    citrus,
    syrups,
    mixers,
    bitters,
    garnish,
    other,
  ];
}

// Ingredient substitutions - what can replace what
class IngredientSubstitutions {
  // Map of ingredient name -> list of acceptable substitutes
  static const Map<String, List<String>> substitutions = {
    // Liqueurs
    'Cointreau': ['Triple Sec', 'Grand Marnier', 'Orange Liqueur'],
    'Triple Sec': ['Cointreau', 'Grand Marnier'],
    'Grand Marnier': ['Cointreau', 'Triple Sec'],
    
    // Spirits
    'Whiskey': ['Bourbon', 'Rye Whiskey', 'Scotch'],
    'Bourbon': ['Whiskey', 'Rye Whiskey'],
    'Rye Whiskey': ['Bourbon', 'Whiskey'],
    'Scotch': ['Whiskey'],
    
    'Vodka': ['Gin (in a pinch)'],
    'Gin': ['Vodka (in a pinch)'],
    
    'White Rum': ['Light Rum', 'Silver Rum'],
    'Light Rum': ['White Rum', 'Silver Rum'],
    'Dark Rum': ['Aged Rum', 'Spiced Rum'],
    
    // Vermouths
    'Dry Vermouth': ['White Vermouth'],
    'Sweet Vermouth': ['Red Vermouth', 'Rosso Vermouth'],
    
    // Syrups
    'Simple Syrup': ['Sugar', 'Agave Syrup', 'Honey Syrup'],
    'Sugar': ['Simple Syrup'],
    'Honey Syrup': ['Simple Syrup', 'Agave Syrup'],
    'Agave Syrup': ['Simple Syrup', 'Honey Syrup'],
    
    // Citrus
    'Fresh Lemon Juice': ['Lemon Juice', 'Bottled Lemon'],
    'Fresh Lime Juice': ['Lime Juice', 'Bottled Lime'],
    'Lemon Juice': ['Fresh Lemon Juice'],
    'Lime Juice': ['Fresh Lime Juice', 'Lemon Juice (substitute)'],
    
    // Bitters
    'Angostura Bitters': ['Aromatic Bitters'],
    'Orange Bitters': ['Angostura Bitters (different flavor)'],
    
    // Liqueurs
    'Amaretto': ['Almond Liqueur'],
    'Kahlua': ['Coffee Liqueur'],
    'Coffee Liqueur': ['Kahlua'],
    
    // Cream
    'Heavy Cream': ['Fresh Cream', 'Cream'],
    'Fresh Cream': ['Heavy Cream', 'Cream'],
  };

  // Check if ingredient A can substitute for ingredient B
  static bool canSubstitute(String ingredientA, String ingredientB) {
    final subs = substitutions[ingredientB.toLowerCase()];
    if (subs == null) return false;
    return subs.any((s) => s.toLowerCase() == ingredientA.toLowerCase());
  }

  // Get all possible substitutes for an ingredient
  static List<String> getSubstitutes(String ingredient) {
    return substitutions[ingredient] ?? [];
  }
}

// Preset bar configurations
class BarPresets {
  static const Map<String, List<String>> presets = {
    'Classic Bar': [
      'Vodka',
      'Gin',
      'Rum',
      'Tequila',
      'Whiskey',
      'Bourbon',
      'Dry Vermouth',
      'Sweet Vermouth',
      'Cointreau',
      'Lemon Juice',
      'Lime Juice',
      'Simple Syrup',
      'Angostura Bitters',
      'Tonic Water',
      'Soda Water',
    ],
    'Tiki Bar': [
      'White Rum',
      'Dark Rum',
      'Lime Juice',
      'Pineapple Juice',
      'Orange Juice',
      'Orgeat',
      'Falernum',
      'Simple Syrup',
      'Angostura Bitters',
      'Mint',
    ],
    'Student Budget': [
      'Vodka',
      'Rum',
      'Orange Juice',
      'Cranberry Juice',
      'Lemon Juice',
      'Lime Juice',
      'Simple Syrup',
      'Soda Water',
      'Tonic Water',
    ],
    'Whiskey Lover': [
      'Bourbon',
      'Rye Whiskey',
      'Scotch',
      'Sweet Vermouth',
      'Angostura Bitters',
      'Simple Syrup',
      'Lemon Juice',
      'Orange Bitters',
      'Maraschino Cherry',
    ],
  };

  static List<String> getPreset(String presetName) {
    return presets[presetName] ?? [];
  }

  static List<String> getAllPresetNames() {
    return presets.keys.toList();
  }
}
