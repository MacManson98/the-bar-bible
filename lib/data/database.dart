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
  TextColumn get imagePath => text().nullable()(); // Path to cocktail image (local asset)
  TextColumn get imageUrl => text().nullable()(); // Firebase Storage URL
  TextColumn get category => text().withDefault(const Constant('cocktail'))(); // cocktail | shot | mocktail
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  TextColumn get firestoreId => text().nullable()(); // Firestore document ID
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
  TextColumn get firestoreId => text()(); // Firestore document ID (stable across syncs)
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

// User-created cocktails
class UserCocktails extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get method => text()(); // shake, stir, build, blend
  TextColumn get methodInstructions => text().nullable()();
  TextColumn get glass => text()();
  TextColumn get ice => text().nullable()();
  TextColumn get garnish => text().nullable()();
  TextColumn get baseSpirit => text()();
  IntColumn get difficulty => integer().withDefault(const Constant(1))();
  TextColumn get tags => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('cocktail'))();
  BoolColumn get isAiGenerated => boolean().withDefault(const Constant(false))();
  TextColumn get firestoreId => text().nullable()();
  TextColumn get imageUrl => text().nullable()(); // Firebase Storage URL
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Ingredients for user-created cocktails
class UserCocktailIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userCocktailId => integer().references(UserCocktails, #id)();
  TextColumn get ingredientName => text()(); // free text, not FK to ingredients
  RealColumn get amount => real()();
  TextColumn get unit => text()(); // ml, oz, dash, etc
  TextColumn get prepNote => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

// Favorites table - simple, fast access to favorited cocktails
class Favorites extends Table {
  TextColumn get firestoreId => text()(); // Firestore document ID (stable across syncs)
  DateTimeColumn get favoritedAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {firestoreId};
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
    UserCocktails,
    UserCocktailIngredients,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 18;

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
      if (from <= 9) {
        // Add tiles_notes column — safe to ignore if it already exists (e.g.
        // a DB that was created fresh via onCreate when schemaVersion was 9).
        try {
          await migrator.addColumn(cocktails, cocktails.tilesNotes);
        } catch (_) {}
      }
      if (from <= 11) {
        await migrator.addColumn(cocktails, cocktails.category);
      }
      if (from <= 12) {
        await customStatement('ALTER TABLE cocktails ADD COLUMN is_premium INTEGER NOT NULL DEFAULT 0');
      }
      if (from <= 13) {
        await customStatement('ALTER TABLE cocktails ADD COLUMN firestore_id TEXT');
        await customStatement('DROP TABLE IF EXISTS favorites');
        await customStatement('CREATE TABLE IF NOT EXISTS favorites (firestore_id TEXT NOT NULL PRIMARY KEY, favorited_at INTEGER NOT NULL)');
      }
      if (from <= 14) {
        await customStatement('DROP TABLE IF EXISTS collection_cocktails');
        await customStatement('CREATE TABLE IF NOT EXISTS collection_cocktails (id INTEGER PRIMARY KEY AUTOINCREMENT, collection_id INTEGER NOT NULL REFERENCES collections(id), firestore_id TEXT NOT NULL, added_at INTEGER NOT NULL DEFAULT (unixepoch()))');
      }
      if (from <= 15) {
        await customStatement('ALTER TABLE cocktails ADD COLUMN image_url TEXT');
      }
      if (from <= 17) {
        try {
          await customStatement('ALTER TABLE user_cocktails ADD COLUMN image_url TEXT');
        } catch (_) {}
      }
      if (from <= 16) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS user_cocktails (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            method TEXT NOT NULL,
            method_instructions TEXT,
            glass TEXT NOT NULL,
            ice TEXT,
            garnish TEXT,
            base_spirit TEXT NOT NULL,
            difficulty INTEGER NOT NULL DEFAULT 1,
            tags TEXT,
            notes TEXT,
            category TEXT NOT NULL DEFAULT 'cocktail',
            is_ai_generated INTEGER NOT NULL DEFAULT 0,
            firestore_id TEXT,
            created_at INTEGER NOT NULL DEFAULT (unixepoch()),
            updated_at INTEGER NOT NULL DEFAULT (unixepoch())
          )
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS user_cocktail_ingredients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_cocktail_id INTEGER NOT NULL REFERENCES user_cocktails(id) ON DELETE CASCADE,
            ingredient_name TEXT NOT NULL,
            amount REAL NOT NULL,
            unit TEXT NOT NULL,
            prep_note TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
      }
      if (from <= 10) {
        // Create tables that exist in Drift schema but may be absent
        // from the Python-exported asset DB
        await customStatement('CREATE TABLE IF NOT EXISTS collections (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT, created_at INTEGER NOT NULL DEFAULT (unixepoch()))');
        await customStatement('CREATE TABLE IF NOT EXISTS collection_cocktails (id INTEGER PRIMARY KEY AUTOINCREMENT, collection_id INTEGER NOT NULL REFERENCES collections(id), cocktail_id INTEGER NOT NULL REFERENCES cocktails(id), added_at INTEGER NOT NULL DEFAULT (unixepoch()))');
        await customStatement('CREATE TABLE IF NOT EXISTS saved_bars (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, is_default INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL DEFAULT (unixepoch()), last_used INTEGER NOT NULL DEFAULT (unixepoch()))');
        await customStatement('CREATE TABLE IF NOT EXISTS saved_bar_ingredients (id INTEGER PRIMARY KEY AUTOINCREMENT, saved_bar_id INTEGER NOT NULL REFERENCES saved_bars(id), ingredient_id INTEGER NOT NULL REFERENCES ingredients(id), added_at INTEGER NOT NULL DEFAULT (unixepoch()), UNIQUE(saved_bar_id, ingredient_id))');
        await customStatement('CREATE TABLE IF NOT EXISTS shopping_list (id INTEGER PRIMARY KEY AUTOINCREMENT, ingredient_id INTEGER NOT NULL REFERENCES ingredients(id), unlocks_count INTEGER NOT NULL DEFAULT 0, added_at INTEGER NOT NULL DEFAULT (unixepoch()))');
      }
    },
  );

  // Favorites helper methods
  Future<bool> isFavorited(String firestoreId) async {
    final result = await (select(
      favorites,
    )..where((f) => f.firestoreId.equals(firestoreId))).getSingleOrNull();
    return result != null;
  }

  Future<void> toggleFavorite(String firestoreId) async {
    final existing = await (select(
      favorites,
    )..where((f) => f.firestoreId.equals(firestoreId))).getSingleOrNull();

    if (existing != null) {
      // Remove from favorites
      await (delete(
        favorites,
      )..where((f) => f.firestoreId.equals(firestoreId))).go();
    } else {
      // Add to favorites
      await into(
        favorites,
      ).insert(FavoritesCompanion(firestoreId: Value(firestoreId)));
    }
  }

  Future<List<Cocktail>> getFavoriteCocktails() async {
    final query = select(cocktails).join([
      innerJoin(favorites, favorites.firestoreId.equalsExp(cocktails.firestoreId)),
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

  // ── User Cocktail helper methods ──────────────────────────────────────────

  Future<List<UserCocktail>> getUserCocktails() async {
    return await (select(userCocktails)
          ..orderBy([(u) => OrderingTerm.desc(u.createdAt)]))
        .get();
  }

  Future<UserCocktail> insertUserCocktail(UserCocktailsCompanion entry) async {
    final id = await into(userCocktails).insert(entry);
    return await (select(userCocktails)..where((u) => u.id.equals(id))).getSingle();
  }

  Future<void> updateUserCocktail(UserCocktailsCompanion entry) async {
    await (update(userCocktails)..where((u) => u.id.equals(entry.id.value)))
        .write(entry);
  }

  /// Synthetic key used for favorites/collections for user-created cocktails.
  static String userCocktailKey(int id) => 'user_$id';

  Future<void> deleteUserCocktail(int id) async {
    final key = userCocktailKey(id);
    // Clean up favourites and collection entries
    await (delete(favorites)..where((f) => f.firestoreId.equals(key))).go();
    await (delete(collectionCocktails)..where((c) => c.firestoreId.equals(key))).go();
    await (delete(userCocktailIngredients)..where((u) => u.userCocktailId.equals(id))).go();
    await (delete(userCocktails)..where((u) => u.id.equals(id))).go();
  }

  Future<List<UserCocktailIngredient>> getUserCocktailIngredients(
    int userCocktailId,
  ) async {
    return await (select(userCocktailIngredients)
          ..where((u) => u.userCocktailId.equals(userCocktailId))
          ..orderBy([(u) => OrderingTerm.asc(u.sortOrder)]))
        .get();
  }

  Future<void> replaceUserCocktailIngredients(
    int userCocktailId,
    List<UserCocktailIngredientsCompanion> ingredients,
  ) async {
    await (delete(userCocktailIngredients)
          ..where((u) => u.userCocktailId.equals(userCocktailId)))
        .go();
    for (final ingredient in ingredients) {
      await into(userCocktailIngredients).insert(ingredient);
    }
  }
}
