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
  TextColumn get description => text().nullable()();
  TextColumn get method => text()(); // shake, stir, build
  TextColumn get methodInstructions => text().nullable()(); // Full instructions
  TextColumn get history => text().nullable()(); // History/origin story
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
  TextColumn get category => text().withDefault(const Constant('Other'))(); // spirits, liqueurs, mixers, etc
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
}

// Shopping list items
class ShoppingList extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ingredientId => integer().references(Ingredients, #id)();
  IntColumn get unlocksCount => integer().withDefault(const Constant(0))(); // How many cocktails this unlocks
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Cocktails, 
  Ingredients, 
  CocktailIngredients, 
  Collections, 
  CollectionCocktails,
  SavedBars,
  SavedBarIngredients,
  ShoppingList,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6; // Add saved bars + shopping list

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'cocktails.sqlite'));
      return NativeDatabase(file);
    });
  }
  
  @override
  MigrationStrategy get migration => MigrationStrategy(
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
    },
  );
}
