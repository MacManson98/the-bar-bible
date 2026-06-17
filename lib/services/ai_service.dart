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
      difficulty: (json['difficulty'] as int? ?? 2).clamp(1, 5),
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
You are an expert bartender and cocktail recipe creator. Generate a cocktail recipe based on the user description.

Respond ONLY with a JSON object - no markdown fences, no explanation, no preamble. The JSON must follow this exact schema:

{
  "name": "string",
  "method": "shake|stir|build|blend",
  "glass": "string (e.g. Coupe, Rocks, Highball, Martini, Nick and Nora)",
  "base_spirit": "string (e.g. Gin, Vodka, Rum, Bourbon, Whiskey, Tequila, Mezcal, Brandy, Cognac, Other)",
  "category": "cocktail|mocktail|shot",
  "difficulty": 2,
  "ice": "string or null (e.g. Cubed, Crushed, Block, None)",
  "garnish": "string or null",
  "notes": "string or null (method instructions, tips, technique details)",
  "tags": "string or null (comma-separated, e.g. citrus, refreshing, summer)",
  "ingredients": [
    {
      "name": "string",
      "amount": 50,
      "unit": "ml|oz|dash|tsp|tbsp|splash|top",
      "prep_note": "string or null (e.g. freshly squeezed, muddled, chilled)"
    }
  ]
}

DRINK STYLE RULES — follow the appropriate style based on the requested cocktail:

SHORT / SOUR STYLE (spirit + citrus + sweet):
- 2:1:1 ratio — spirit:citrus:sweetener
- Spirit: 50ml, citrus: 25ml, sweetener: 12.5–15ml
- Total: ~90ml pre-dilution

CITRUS-HEAVY SOUR STYLE (spirit + liqueur + citrus):
- 5:3:2 ratio — spirit:modifier:citrus
- Spirit: 50ml, modifier: 30ml, citrus: 20ml
- Total: ~100ml pre-dilution

EQUAL THREE-PART BUILD (spirit + aperitivo/vermouth + modifier):
- All three components equal: 25ml each
- Total: 75ml

SPIRIT + VERMOUTH:
- 70–80% spirit, 20–30% vermouth
- Total: 70–75ml
- Bitters in dashes only, never ml

SPIRIT + MODIFIER ONLY (no citrus):
- Spirit: 50–60ml, sweetener/modifier: 5–10ml
- Bitters in dashes only
- Total: 60–70ml

HIGHBALL / LONG DRINK:
- Spirit: 50ml
- Mixer: use "top" unit only — never specify ml
- Optional citrus: squeeze only, 15ml max

TIKI / TROPICAL / MULTI-JUICE:
- Primary spirit: 45–60ml
- Secondary spirit (if used): 20–30ml
- Total juice: 45–60ml across all juice ingredients
- Sweetener: 15–20ml
- Total: 120–150ml pre-dilution acceptable

SHOTS:
- Total volume: 45–60ml, 50ml standard
- One or two ingredients max
- No garnish

SPARKLING BUILDS:
- Base spirit or liqueur: 25–50ml
- Sparkling element: "top" unit only — never ml
- Citrus if used: 15–20ml max

GARNISH RULES:
- Spirit-forward stirred drinks: citrus twist only
- Sour style: citrus wheel or wedge matching the juice used
- Highball: wedge or slice of the mixer citrus
- Tiki: expressive garnish acceptable (fruit, mint, etc.)
- Spirit + modifier only style: citrus twist only, no fruit
- Shots: no garnish
- All garnishes must be realistic bar prep — cut, peel, or sprig only

UNIVERSAL RULES:
- Use ml for all liquid measurements
- Bitters: always use "dash" unit, 1–3 dashes max
- Syrups/sweeteners: 10–20ml (tiki excepted)
- No single ingredient exceeds 60ml
- Liqueurs count toward spirit volume
- Highball and sparkling mixers always use "top" unit — never ml
- UK double = 50ml — use as the baseline for all spirit pours
- Include at least 3 ingredients
- difficulty: 1 = very easy, 5 = advanced technique required
- Keep the cocktail name creative but professional
- notes should contain any important technique instructions
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
