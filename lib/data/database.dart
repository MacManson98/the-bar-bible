import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Cocktails table
class Cocktails extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get method => text()(); // shake, stir, build
  TextColumn get methodInstructions => text().nullable()(); // Full instructions
  TextColumn get history => text().nullable()(); // History/origin story
  TextColumn get tastingNotes =>
      text().nullable()(); // Flavor profile, tasting notes
  TextColumn get tilesNotes => text()
      .named('tiles_notes')
      .nullable()(); // Curated short notes for finder tiles
  TextColumn get glass => text()();
  TextColumn get ice => text().nullable()();
  TextColumn get garnish => text().nullable()();
  TextColumn get baseSpirit => text()();
  IntColumn get difficulty => integer()(); // 1-5
  TextColumn get tags => text().nullable()(); // JSON array as string for now
  TextColumn get imagePath => text().nullable()(); // Path to cocktail image
}

// Ingredients table
class Ingredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(
    const Constant('Other'),
  )(); // spirits, liqueurs, mixers, etc
}

// Join table for cocktail ingredients
class CocktailIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cocktailId => integer().references(Cocktails, #id)();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  RealColumn get amount => real()();
  TextColumn get unit => text()(); // ml or oz
  TextColumn get prepNote => text().nullable()(); // "muddled", "fresh", etc
}

// Collections table
class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Junction table for cocktails in collections
class CollectionCocktails extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get collectionId => integer().references(Collections, #id)();
  IntColumn get cocktailId => integer().references(Cocktails, #id)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

// Saved bars (user's ingredient inventories)
class SavedBars extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUsed => dateTime().withDefault(currentDateAndTime)();
}

// Junction table for ingredients in saved bars
class SavedBarIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get savedBarId => integer().references(SavedBars, #id)();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {savedBarId, ingredientId},
  ];
}

// Shopping list items
class ShoppingList extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  IntColumn get unlocksCount => integer().withDefault(
    const Constant(0),
  )(); // How many cocktails this unlocks
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

// Favorites table - simple, fast access to favorited cocktails
class Favorites extends Table {
  IntColumn get cocktailId =>
      integer().references(Cocktails, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get favoritedAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {cocktailId}; // Cocktail ID is the primary key (one favorite per cocktail)
}

@DriftDatabase(
  tables: [
    Cocktails,
    Ingredients,
    CocktailIngredients,
    Collections,
    CollectionCocktails,
    SavedBars,
    SavedBarIngredients,
    ShoppingList,
    Favorites,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 9; // Add unique key for saved bar ingredients

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'cocktails.db'));
      return NativeDatabase(file);
    });
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_saved_bar_ingredients_unique
ON saved_bar_ingredients(saved_bar_id, ingredient_id)
''');
    },
    onUpgrade: (migrator, from, to) async {
      if (from == 1) {
        // Add new columns for existing users
        await migrator.addColumn(cocktails, cocktails.methodInstructions);
        await migrator.addColumn(cocktails, cocktails.history);
      }
      if (from <= 2) {
        // Add image path column
        await migrator.addColumn(cocktails, cocktails.imagePath);
      }
      if (from <= 4) {
        // Add collections tables
        await migrator.createTable(collections);
        await migrator.createTable(collectionCocktails);
      }
      if (from <= 5) {
        // Add ingredient category column
        await migrator.addColumn(ingredients, ingredients.category);
        // Add saved bars tables
        await migrator.createTable(savedBars);
        await migrator.createTable(savedBarIngredients);
        await migrator.createTable(shoppingList);
      }
      if (from <= 6) {
        // Add favorites table
        await migrator.createTable(favorites);
      }
      if (from <= 7) {
        // Add tasting notes column
        await migrator.addColumn(cocktails, cocktails.tastingNotes);
      }
      if (from <= 8) {
        // Deduplicate first so unique index can be created safely.
        await customStatement('''
DELETE FROM saved_bar_ingredients
WHERE id NOT IN (
  SELECT MIN(id)
  FROM saved_bar_ingredients
  GROUP BY saved_bar_id, ingredient_id
)
''');
        await customStatement('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_saved_bar_ingredients_unique
ON saved_bar_ingredients(saved_bar_id, ingredient_id)
''');
      }
    },
  );

  // Favorites helper methods
  Future<bool> isFavorited(int cocktailId) async {
    final result = await (select(
      favorites,
    )..where((f) => f.cocktailId.equals(cocktailId))).getSingleOrNull();
    return result != null;
  }

  Future<void> toggleFavorite(int cocktailId) async {
    final existing = await (select(
      favorites,
    )..where((f) => f.cocktailId.equals(cocktailId))).getSingleOrNull();

    if (existing != null) {
      // Remove from favorites
      await (delete(
        favorites,
      )..where((f) => f.cocktailId.equals(cocktailId))).go();
    } else {
      // Add to favorites
      await into(
        favorites,
      ).insert(FavoritesCompanion(cocktailId: Value(cocktailId)));
    }
  }

  Future<List<Cocktail>> getFavoriteCocktails() async {
    final query = select(cocktails).join([
      innerJoin(favorites, favorites.cocktailId.equalsExp(cocktails.id)),
    ])..orderBy([OrderingTerm.desc(favorites.favoritedAt)]);

    final results = await query.get();
    return results.map((row) => row.readTable(cocktails)).toList();
  }

  // Helper methods for home screen

  /// Get the ingredients for a cocktail
  Future<List<CocktailIngredient>> getCocktailIngredients(
    int cocktailId,
  ) async {
    return await (select(
      cocktailIngredients,
    )..where((ci) => ci.cocktailId.equals(cocktailId))).get();
  }

  /// Get cocktail ingredients with ingredient names
  Future<List<Map<String, dynamic>>> getCocktailIngredientsWithNames(
    int cocktailId,
  ) async {
    final query = select(cocktailIngredients).join([
      innerJoin(
        ingredients,
        ingredients.id.equalsExp(cocktailIngredients.ingredientId),
      ),
    ])..where(cocktailIngredients.cocktailId.equals(cocktailId));

    final results = await query.get();
    return results.map((row) {
      final ci = row.readTable(cocktailIngredients);
      final ing = row.readTable(ingredients);
      return {
        'amount': ci.amount,
        'unit': ci.unit,
        'name': ing.name,
        'prepNote': ci.prepNote,
      };
    }).toList();
  }

  /// Get the default saved bar
  Future<SavedBar?> getDefaultSavedBar() async {
    final result = await (select(
      savedBars,
    )..where((sb) => sb.isDefault.equals(true))).getSingleOrNull();

    // If no default, get the most recently used
    if (result == null) {
      return await (select(savedBars)
            ..orderBy([(sb) => OrderingTerm.desc(sb.lastUsed)])
            ..limit(1))
          .getSingleOrNull();
    }

    return result;
  }

  /// Get ingredients in a saved bar
  Future<List<Ingredient>> getSavedBarIngredients(int savedBarId) async {
    final query = select(ingredients).join([
      innerJoin(
        savedBarIngredients,
        savedBarIngredients.ingredientId.equalsExp(ingredients.id),
      ),
    ])..where(savedBarIngredients.savedBarId.equals(savedBarId));

    final results = await query.get();
    return results.map((row) => row.readTable(ingredients)).toList();
  }

  /// Idempotent add: returns true if inserted, false if it already existed.
  Future<bool> addIngredientToSavedBar({
    required int savedBarId,
    required int ingredientId,
  }) async {
    final inserted = await into(savedBarIngredients).insert(
      SavedBarIngredientsCompanion.insert(
        savedBarId: savedBarId,
        ingredientId: ingredientId,
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return inserted != 0;
  }
}
