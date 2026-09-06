import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

class AiCocktailSpec {
  final String name;
  final String method;
  final String glass;
  final String baseSpirit;
  final String category;
  final int difficulty;
  final String? ice;
  final String? garnish;
  final String? notes;
  final String? tags;
  final List<AiIngredient> ingredients;

  AiCocktailSpec({
    required this.name,
    required this.method,
    required this.glass,
    required this.baseSpirit,
    required this.category,
    required this.difficulty,
    this.ice,
    this.garnish,
    this.notes,
    this.tags,
    required this.ingredients,
  });

  factory AiCocktailSpec.fromJson(Map<String, dynamic> json) {
    final ingredientsList = (json['ingredients'] as List<dynamic>? ?? [])
        .map((i) => AiIngredient.fromJson(i as Map<String, dynamic>))
        .toList();

    return AiCocktailSpec(
      name: json['name'] as String? ?? 'Unnamed Cocktail',
      method: _normaliseMethod(json['method'] as String? ?? 'shake'),
      glass: json['glass'] as String? ?? 'Coupe',
      baseSpirit: json['base_spirit'] as String? ?? 'Other',
      category: _normaliseCategory(json['category'] as String? ?? 'cocktail'),
      difficulty: ((json['difficulty'] as num? ?? 2).round()).clamp(1, 5),
      ice: json['ice'] as String?,
      garnish: json['garnish'] as String?,
      notes: json['notes'] as String?,
      tags: json['tags'] as String?,
      ingredients: ingredientsList,
    );
  }

  static String _normaliseMethod(String raw) {
    final lower = raw.toLowerCase();
    const valid = ['shake', 'stir', 'build', 'blend'];
    return valid.firstWhere((m) => lower.contains(m), orElse: () => 'shake');
  }

  static String _normaliseCategory(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('mocktail')) return 'mocktail';
    if (lower.contains('shot')) return 'shot';
    return 'cocktail';
  }
}

class AiIngredient {
  final String name;
  final double amount;
  final String unit;
  final String? prepNote;

  AiIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    this.prepNote,
  });

  factory AiIngredient.fromJson(Map<String, dynamic> json) {
    return AiIngredient(
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      unit: _normaliseUnit(json['unit'] as String? ?? 'ml'),
      prepNote: json['prep_note'] as String?,
    );
  }

  static String _normaliseUnit(String raw) {
    const valid = ['ml', 'oz', 'dash', 'tsp', 'tbsp', 'splash', 'top'];
    final lower = raw.toLowerCase();
    return valid.firstWhere((u) => lower == u, orElse: () => 'ml');
  }
}

class AiService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _remoteConfigKey = 'anthropic_api_key';

  // Fallback used only if Remote Config hasn't fetched yet.
  // Replace with your real key — Remote Config will override this in production.
  static const String _fallbackApiKey = 'YOUR_ANTHROPIC_API_KEY';

  static Future<String> _getApiKey() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.fetchAndActivate();
      final key = rc.getString(_remoteConfigKey);
      if (key.isNotEmpty) return key;
    } catch (_) {}
    return _fallbackApiKey;
  }

  static const String _systemPrompt = '''
You are a professional bartender generating cocktail recipes.

Respond ONLY with valid JSON. No markdown fences, no explanation, no preamble.

JSON schema:
{
  "name": "string",
  "method": "shake|stir|build|blend",
  "glass": "string (e.g. Coupe, Rocks, Highball, Martini, Nick and Nora)",
  "base_spirit": "string (e.g. Gin, Vodka, Rum, Bourbon, Whiskey, Tequila, Mezcal, Brandy, Cognac, Other)",
  "category": "cocktail|mocktail|shot",
  "difficulty": 1,
  "ice": "string or null",
  "garnish": "string or null",
  "notes": "string or null",
  "tags": "string or null (comma-separated)",
  "ingredients": [
    { "name": "string", "amount": 50, "unit": "ml|oz|dash|tsp|tbsp|splash|top", "prep_note": "string or null" }
  ]
}

—— HARD LIMITS — NEVER BREAK THESE ——

1. SPIRIT VOLUME: One spirit maximum 50ml. Total spirits in recipe maximum 75ml.
2. TOTAL RECIPE VOLUME: Maximum 150ml pre-dilution (excluding "top" mixers).
3. NO INGREDIENT OVER 60ml ever.
4. BITTERS: Always "dash" unit, 1-3 dashes only, never ml.
5. SYRUPS / SWEETENERS: 10-20ml maximum. Never exceed 20ml.
6. DIFFICULTY: Default to 1 or 2. Only use 3+ if the technique genuinely requires advanced skill (e.g. fat-washing, clarification, multi-day prep). Most cocktails are 1-2.
7. HIGHBALL / SPARKLING MIXER: Always "top" unit. Never specify ml for soda, tonic, ginger beer, champagne, prosecco.

—— STANDARD RATIOS BY STYLE ——

SHORT SOUR (spirit + citrus + sweet): spirit 50ml, citrus 25ml, sweetener 12-15ml
CITRUS SOUR (spirit + liqueur + citrus): spirit 45ml, liqueur 22ml, citrus 20ml
EQUAL PARTS: 25ml each, max 3 parts
SPIRIT + VERMOUTH: spirit 50ml, vermouth 15-20ml
SPIRIT FORWARD (no citrus): spirit 50-60ml, modifier 5-10ml, bitters in dashes
HIGHBALL: spirit 50ml, mixer "top"
TIKI (multi-ingredient): primary spirit 45ml, secondary spirit max 25ml, total juice 45-60ml, sweetener 15ml
SHOT: total 45-50ml, 1-2 ingredients

—— GARNISH RULES ——
- Spirit-forward stirred: citrus twist only
- Sours: citrus wheel or wedge matching the juice
- Highball: citrus wedge or slice
- Shots: no garnish
- All garnishes must be realistic bar prep

—— DIFFICULTY GUIDE ——
1 = pour and stir, simple build
2 = standard shake/stir, one fresh ingredient
3 = multiple fresh elements, layering, specific technique
4 = advanced technique (infusions, clarification, batching)
5 = professional-only (fat-washing, centrifuge, multi-day)
Default to 1 unless genuinely complex.
''';

  Future<AiCocktailSpec> generateCocktail(String prompt) async {
    final apiKey = await _getApiKey();
    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': 'claude-haiku-4-5',
            'max_tokens': 1024,
            'system': _systemPrompt,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        (data['content'] as List<dynamic>).first as Map<String, dynamic>;
    final text = content['text'] as String;

    // Strip any accidental markdown fences
    final cleaned = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return AiCocktailSpec.fromJson(json);
  }
}
