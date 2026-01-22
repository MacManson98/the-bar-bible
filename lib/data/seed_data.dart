import 'database.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeedData {
  // Increment this version when you fix cocktail data
  static const int seedDataVersion = 5; // Changed from 1 to force re-seed
  
  static Future<void> seedDatabase(AppDatabase db) async {
    // Check current seed version
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getInt('seed_data_version') ?? 0;
    
    // If seed data version changed, clear and re-seed
    if (currentVersion != seedDataVersion) {
      
      // Clear all data
      await db.delete(db.cocktailIngredients).go();
      await db.delete(db.cocktails).go();
      await db.delete(db.ingredients).go();
      
      // Update version
      await prefs.setInt('seed_data_version', seedDataVersion);
    } else {
      // Check if already seeded
      final existingCocktails = await db.select(db.cocktails).get();
      if (existingCocktails.isNotEmpty) return;
    }

    // Create ingredient map to avoid duplicates
    final Map<String, int> ingredientIds = {};
    
    // Helper to get or create ingredient
    Future<int> getIngredientId(String name) async {
      if (ingredientIds.containsKey(name)) {
        return ingredientIds[name]!;
      }
      
      final id = await db.into(db.ingredients).insert(
        IngredientsCompanion.insert(name: name),
      );
      ingredientIds[name] = id;
      return id;
    }


    // Alexander
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Alexander',
          method: 'shake',
          methodInstructions: const Value(r"""Pour ingredients into a shaker filled with ice, shake well and fine strain into a cocktail glass."""),
          glass: 'Cocktail',
          garnish: const Value(r"""A sprinkling of fresh nutmeg."""),
          baseSpirit: 'Cognac',
          difficulty: 2,
          history: const Value(r"""The Alexander has evolved over time and has had a few variations including with Brandy, gin and egg whites. The cocktail dates back to before 1915, rumoured to be named after bartender Troy Alexander, who worked at Rector's restaurant in New York City."""),
          imagePath: const Value('assets/images/cocktails/alexander.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Cognac'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Creme de Cacao'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Fresh Cream'),
          amount: 30,
          unit: 'ml',
        ),
      );
    }

    // Americano
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Americano',
          method: 'stir',
          methodInstructions: const Value(r"""Stir ingredients in a rocks glass filled with ice, top up with Soda Water and more ice."""),
          glass: 'Rocks',
          garnish: const Value(r"""Flamed orange peel."""),
          baseSpirit: 'Campari',
          difficulty: 2,
          history: const Value(r"""The Americano originated in the 1860s at Gaspare Campari's bar in Milan, Italy. Its original name comes from its two main ingredients Campari and Sweet Vermouth invented in Milan and Torino respectively."""),
          imagePath: const Value('assets/images/cocktails/americano.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Campari'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Sweet Vermouth'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Soda Water'),
          amount: 30,
          unit: 'ml',
        ),
      );
    }

    // Angel Face
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Angel Face',
          method: 'shake',
          methodInstructions: const Value(r"""Pour ingredients into a shaker filled with ice, shake well and fine strain into a cocktail glass."""),
          glass: 'Cocktail',
          garnish: const Value(r"""Orange peel, Lemon peel or an apple slice."""),
          baseSpirit: 'Gin',
          difficulty: 2,
          history: const Value(r"""The Angel Face cocktail first appears in the Savoy Cocktail Book compiled by Harry Craddock in 1930."""),
          imagePath: const Value('assets/images/cocktails/angelface.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Gin'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Apricot Brandy'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Calvados'),
          amount: 30,
          unit: 'ml',
        ),
      );
    }

    // Aviation
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Aviation',
          method: 'shake',
          methodInstructions: const Value(r"""Pour ingredients into a shaker filled with ice, shake well and fine strain into a coupe glass."""),
          glass: 'Coupe',
          garnish: const Value(r"""Cherry on a stick or a flamed lemon peel."""),
          baseSpirit: 'Gin',
          difficulty: 2,
          history: const Value(r"""The Aviation was created by Hugo Ensslin, head bartender at the Hotel Wallick in New York, and first appeared in his 1916 book."""),
          imagePath: const Value('assets/images/cocktails/aviation.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Gin'),
          amount: 40,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Maraschino Luxardo'),
          amount: 10,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Lemon Juice'),
          amount: 10,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Orange Bitters'),
          amount: 2,
          unit: 'ml',
        ),
      );
    }

    // Bellini
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Bellini',
          method: 'stir',
          methodInstructions: const Value(r"""Pour the puree into a flute glass, add the prosecco and stir gently."""),
          glass: 'Flute',
          garnish: const Value(r"""Edible flower if available."""),
          baseSpirit: 'Prosecco',
          difficulty: 2,
          history: const Value(r"""The Bellini was created by Giuseppe Cipriani at Harry's Bar in Venice, Italy around 1948."""),
          imagePath: const Value('assets/images/cocktails/bellini.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Prosecco'),
          amount: 90,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('White Peach Puree'),
          amount: 60,
          unit: 'ml',
        ),
      );
    }

    // Between the Sheets
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Between the Sheets',
          method: 'shake',
          methodInstructions: const Value(r"""Add ingredients to a cocktail shaker, shake well and fine strain into a cocktail glass."""),
          glass: 'Cocktail',
          garnish: const Value(r"""N/A"""),
          baseSpirit: 'Rum',
          difficulty: 4,
          history: const Value(r"""Between the Sheets is mostly credited to Harry MacElhone at Harry's New York Bar in Paris."""),
          imagePath: const Value('assets/images/cocktails/betweenthesheets.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('White Rum'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Cognac'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Triple Sec'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Lemon Juice'),
          amount: 20,
          unit: 'ml',
        ),
      );
    }

    // Black Russian
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Black Russian',
          method: 'stir',
          methodInstructions: const Value(r"""Pour the ingredients into a rocks glass filled with ice, stir gently."""),
          glass: 'Rocks',
          garnish: const Value(r"""N/A (Some use a Maraschino Cherry or Lemon twist."""),
          baseSpirit: 'Vodka',
          difficulty: 2,
          history: const Value(r"""Originating in the 1940s, in the bar at the Hotel Metropole in Brussels, Gustave Tops created a signature drink for Perle Mesta."""),
          imagePath: const Value('assets/images/cocktails/blackrussian.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Vodka'),
          amount: 50,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Coffee Liqueur'),
          amount: 20,
          unit: 'ml',
        ),
      );
    }

    // Bloody Mary
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Bloody Mary',
          method: 'shake',
          methodInstructions: const Value(r"""'Roll' the ingredients in a shaker with ice to gently combine the mixture, strain into a tall glass."""),
          glass: 'Highball',
          garnish: const Value(r"""Celery stick, lemon wedge"""),
          baseSpirit: 'Vodka',
          difficulty: 4,
          history: const Value(r"""The Bloody Mary likely emerged in Paris in the 1920s and is credited to Fernand Petiot at Harry's New York Bar."""),
          imagePath: const Value('assets/images/cocktails/bloodymary.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Vodka'),
          amount: 45,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Tomato Juice'),
          amount: 90,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Lemon Juice'),
          amount: 15,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Worcestershire Sauce'),
          amount: 2,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Tabasco'),
          amount: 2,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Celery Salt'),
          amount: 1,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Pepper'),
          amount: 1,
          unit: 'ml',
        ),
      );
    }

    // Boulevardier
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Boulevardier',
          method: 'stir',
          methodInstructions: const Value(r"""Pour the ingredients into a mixing glass, stir thoroughly and strain into a coupe glass."""),
          glass: 'Coupe',
          garnish: const Value(r"""Orange twist or lemon twist."""),
          baseSpirit: 'Bourbon',
          difficulty: 2,
          history: const Value(r"""The Boulevardier is a whiskey based Negroni variation, originated in 1920s Paris."""),
          imagePath: const Value('assets/images/cocktails/boulevardier.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Bourbon'),
          amount: 45,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Campari'),
          amount: 30,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Sweet Vermouth'),
          amount: 30,
          unit: 'ml',
        ),
      );
    }

    // Bramble
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Bramble',
          method: 'shake',
          methodInstructions: const Value(r"""Pour ingredients except Creme De Mure into a shaker, shake well and strain into a rocks glass filled with crushed ice, pour over Creme De Mure and add garnish."""),
          glass: 'Rocks',
          garnish: const Value(r"""Lemon slice and blackberries"""),
          baseSpirit: 'Gin',
          difficulty: 4,
          history: const Value(r"""The Bramble is a more modern classic, invented in 1984 by Dick Bradsell at Fred's Club in London."""),
          imagePath: const Value('assets/images/cocktails/bramble.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Gin'),
          amount: 50,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Lemon Juice'),
          amount: 25,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Sugar Syrup'),
          amount: 15,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Creme De Mure'),
          amount: 15,
          unit: 'ml',
        ),
      );
    }

    // Brandy Crusta
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Brandy Crusta',
          method: 'shake',
          methodInstructions: const Value(r"""Mix ingredients in a mixing glass and strain into a slim cocktail glass."""),
          glass: 'Cocktail',
          garnish: const Value(r"""Rub a slice of orange and dip it into pulverized white sugar so the sugar sticks to the edge of the glass."""),
          baseSpirit: 'Brandy',
          difficulty: 4,
          history: const Value(r"""Invented in the 1850s by Joseph Santini in New Orleans in his bar, The Jewel of the South."""),
          imagePath: const Value('assets/images/cocktails/brandycrusta.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Brandy'),
          amount: 52.5,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Maraschino Luxardo'),
          amount: 7.5,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Curacao'),
          amount: 1,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Lemon Juice'),
          amount: 15,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Sugar Syrup'),
          amount: 1,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Aromatic Bitters'),
          amount: 2,
          unit: 'ml',
        ),
      );
    }

    // Caipirinha
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Caipirinha',
          method: 'stir',
          methodInstructions: const Value(r"""Place chopped lime and sugar into a rocks glass and muddle gently. Fill the glass with cracked ice and add Cachaca."""),
          glass: 'Rocks',
          garnish: const Value(r"""Lime slices are in the cocktail already."""),
          baseSpirit: 'Cachaca',
          difficulty: 2,
          history: const Value(r"""The Caipirinha, Brazil's national cocktail, evolved from an early 20th century medicinal tonic for the Spanish Flu."""),
          imagePath: const Value('assets/images/cocktails/caipirinha.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Cachaca'),
          amount: 60,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Lime'),
          amount: 1,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('White Cane Sugar'),
          amount: 4,
          unit: 'ml',
        ),
      );
    }

    // Canchanchara
    {
      final cocktailId = await db.into(db.cocktails).insert(
        CocktailsCompanion.insert(
          name: 'Canchanchara',
          method: 'stir',
          methodInstructions: const Value(r"""Mix the honey with water and lime juice, spread the mixture on the bottom and sides of the glass. Add cracked ice and then the rum."""),
          glass: 'Coupe',
          garnish: const Value(r"""Lime wheel"""),
          baseSpirit: 'Rum',
          difficulty: 4,
          history: const Value(r"""The Canchanchara is one of Cuba's oldest cocktails, originating in the 19th century as a medicinal tonic for Cuban Mambi fighters."""),
          imagePath: const Value('assets/images/cocktails/canchanchara.png'),
        ),
      );
      
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Cuban Aguardiente'),
          amount: 60,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Lime Juice'),
          amount: 15,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Raw Honey'),
          amount: 15,
          unit: 'ml',
        ),
      );
      await db.into(db.cocktailIngredients).insert(
        CocktailIngredientsCompanion.insert(
          cocktailId: cocktailId,
          ingredientId: await getIngredientId('Water'),
          amount: 50,
          unit: 'ml',
        ),
      );
    }
  }
}
