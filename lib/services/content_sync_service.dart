import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';

/// Content sync contract:
/// Manifest JSON
/// {
///   "content_version": 12,
///   "generated_at": "2026-02-26T18:30:00Z",
///   "payload_url": "https://example.com/content/payload_v12.json"
/// }
///
/// Payload JSON
/// {
///   "cocktails": [
///     {
///       "id": 1,
///       "name": "Negroni",
///       "method": "stir",
///       "method_instructions": "...",
///       "history": "...",
///       "tasting_notes": "...",
///       "tiles_notes": "...",
///       "glass": "Old Fashioned",
///       "ice": "large cube",
///       "garnish": "orange peel",
///       "base_spirit": "Gin",
///       "difficulty": 2,
///       "tags": "[\"bitter\",\"boozy\"]",
///       "image_path": "assets/images/cocktails/negroni.png"
///     }
///   ],
///   "ingredients": [
///     {"id": 1, "name": "Gin", "category": "Spirits"}
///   ],
///   "cocktail_ingredients": [
///     {
///       "id": 1,
///       "cocktail_id": 1,
///       "ingredient_id": 1,
///       "amount": 30,
///       "unit": "ml",
///       "prep_note": null
///     }
///   ]
/// }
class ContentSyncService {
  ContentSyncService(this._db);

  static const String _manifestUrl = String.fromEnvironment(
    'CONTENT_SYNC_MANIFEST_URL',
    defaultValue: '',
  );
  static const String _fallbackPayloadUrl = String.fromEnvironment(
    'CONTENT_SYNC_PAYLOAD_URL',
    defaultValue: '',
  );
  static const String _localVersionKey = 'content_sync.local_version';

  final AppDatabase _db;

  Future<void> syncIfNeeded() async {
    if (_manifestUrl.isEmpty) {
      _log('Skipped: CONTENT_SYNC_MANIFEST_URL is not configured.');
      return;
    }

    try {
      _log('Sync check started.');

      final localVersion = await _readLocalVersion();
      _log('Local content_version=$localVersion');

      final manifestJson = await _fetchJsonObject(Uri.parse(_manifestUrl));
      final manifest = _ContentManifest.fromJson(
        manifestJson,
        fallbackPayloadUrl: _fallbackPayloadUrl,
      );
      if (manifest.generatedAt != null && manifest.generatedAt!.isNotEmpty) {
        _log('Manifest generated_at=${manifest.generatedAt}');
      }

      if (manifest.contentVersion <= localVersion) {
        _log(
          'No sync needed. remote=${manifest.contentVersion} local=$localVersion',
        );
        return;
      }

      if (manifest.payloadUrl.isEmpty) {
        _log(
          'Skipped: payload URL missing in manifest and CONTENT_SYNC_PAYLOAD_URL is empty.',
        );
        return;
      }

      _log(
        'Update available. remote=${manifest.contentVersion} local=$localVersion',
      );

      final payloadJson = await _fetchJsonObject(
        Uri.parse(manifest.payloadUrl),
      );
      final payload = _ContentPayload.fromJson(payloadJson);

      await _applyPayload(payload);
      await _writeLocalVersion(manifest.contentVersion);

      _log(
        'Sync complete. content_version updated to ${manifest.contentVersion}',
      );
    } catch (e, st) {
      _log('Sync failed: $e');
      log('[ContentSync] Stack trace:\n$st', name: 'ContentSync');
    }
  }

  Future<void> _applyPayload(_ContentPayload payload) async {
    _log(
      'Applying payload: '
      'ingredients=${payload.ingredients.length}, '
      'cocktails=${payload.cocktails.length}, '
      'cocktail_ingredients=${payload.cocktailIngredients.length}',
    );

    await _db.transaction(() async {
      for (final row in payload.ingredients) {
        final id = _asInt(row['id']);
        final name = _asString(row['name']);
        final category = _asString(row['category']) ?? 'Other';
        if (id == null || name == null || name.isEmpty) {
          _log('Skipping ingredient with invalid required fields: $row');
          continue;
        }

        await _db
            .into(_db.ingredients)
            .insertOnConflictUpdate(
              IngredientsCompanion(
                id: Value(id),
                name: Value(name),
                category: Value(category),
              ),
            );
      }

      for (final row in payload.cocktails) {
        final id = _asInt(row['id']);
        final name = _asString(row['name']);
        final method = _asString(row['method']);
        final glass = _asString(row['glass']);
        final baseSpirit = _asString(row['base_spirit']);
        final difficulty = _asInt(row['difficulty']);

        if (id == null ||
            name == null ||
            method == null ||
            glass == null ||
            baseSpirit == null ||
            difficulty == null) {
          _log('Skipping cocktail with invalid required fields: $row');
          continue;
        }

        await _db
            .into(_db.cocktails)
            .insertOnConflictUpdate(
              CocktailsCompanion(
                id: Value(id),
                name: Value(name),
                method: Value(method),
                methodInstructions: Value(
                  _asString(row['method_instructions']),
                ),
                history: Value(_asString(row['history'])),
                tastingNotes: Value(_asString(row['tasting_notes'])),
                tilesNotes: Value(_asString(row['tiles_notes'])),
                glass: Value(glass),
                ice: Value(_asString(row['ice'])),
                garnish: Value(_asString(row['garnish'])),
                baseSpirit: Value(baseSpirit),
                difficulty: Value(difficulty),
                tags: Value(_asString(row['tags'])),
                imagePath: Value(_asString(row['image_path'])),
              ),
            );
      }

      final ingredientIds = await _fetchIngredientIds();
      final cocktailIds = await _fetchCocktailIds();

      for (final row in payload.cocktailIngredients) {
        final id = _asInt(row['id']);
        final cocktailId = _asInt(row['cocktail_id']);
        final ingredientId = _asInt(row['ingredient_id']);
        final amount = _asDouble(row['amount']);
        final unit = _asString(row['unit']);

        if (id == null ||
            cocktailId == null ||
            ingredientId == null ||
            amount == null ||
            unit == null) {
          _log(
            'Skipping cocktail_ingredient with invalid required fields: $row',
          );
          continue;
        }

        if (!cocktailIds.contains(cocktailId) ||
            !ingredientIds.contains(ingredientId)) {
          _log(
            'Skipping cocktail_ingredient id=$id because relation is missing '
            '(cocktail_id=$cocktailId, ingredient_id=$ingredientId).',
          );
          continue;
        }

        final companion = CocktailIngredientsCompanion(
          cocktailId: Value(cocktailId),
          ingredientId: Value(ingredientId),
          amount: Value(amount),
          unit: Value(unit),
          prepNote: Value(_asString(row['prep_note'])),
        );

        final updated = await (_db.update(
          _db.cocktailIngredients,
        )..where((t) => t.id.equals(id))).write(companion);
        if (updated > 0) {
          continue;
        }

        final existingByPair =
            await (_db.select(_db.cocktailIngredients)
                  ..where(
                    (t) =>
                        t.cocktailId.equals(cocktailId) &
                        t.ingredientId.equals(ingredientId),
                  )
                  ..limit(1))
                .getSingleOrNull();

        if (existingByPair != null) {
          await (_db.update(
            _db.cocktailIngredients,
          )..where((t) => t.id.equals(existingByPair.id))).write(companion);
          continue;
        }

        await _db
            .into(_db.cocktailIngredients)
            .insert(
              CocktailIngredientsCompanion(
                id: Value(id),
                cocktailId: Value(cocktailId),
                ingredientId: Value(ingredientId),
                amount: Value(amount),
                unit: Value(unit),
                prepNote: Value(_asString(row['prep_note'])),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  Future<Set<int>> _fetchIngredientIds() async {
    final rows = await (_db.selectOnly(
      _db.ingredients,
    )..addColumns([_db.ingredients.id])).get();
    return rows
        .map((row) => row.read(_db.ingredients.id))
        .whereType<int>()
        .toSet();
  }

  Future<Set<int>> _fetchCocktailIds() async {
    final rows = await (_db.selectOnly(
      _db.cocktails,
    )..addColumns([_db.cocktails.id])).get();
    return rows
        .map((row) => row.read(_db.cocktails.id))
        .whereType<int>()
        .toSet();
  }

  Future<Map<String, dynamic>> _fetchJsonObject(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode} for $uri', uri: uri);
      }

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object at root.');
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<int> _readLocalVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_localVersionKey) ?? 0;
  }

  Future<void> _writeLocalVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_localVersionKey, version);
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  void _log(String message) {
    log('[ContentSync] $message', name: 'ContentSync');
  }
}

class _ContentManifest {
  _ContentManifest({
    required this.contentVersion,
    required this.generatedAt,
    required this.payloadUrl,
  });

  final int contentVersion;
  final String? generatedAt;
  final String payloadUrl;

  factory _ContentManifest.fromJson(
    Map<String, dynamic> json, {
    required String fallbackPayloadUrl,
  }) {
    final rawVersion = json['content_version'];
    final contentVersion = rawVersion is int
        ? rawVersion
        : int.tryParse('${rawVersion ?? ''}');
    if (contentVersion == null) {
      throw const FormatException('Manifest is missing valid content_version.');
    }

    final payloadUrl =
        (json['payload_url']?.toString().trim().isNotEmpty ?? false)
        ? json['payload_url'].toString().trim()
        : fallbackPayloadUrl.trim();

    return _ContentManifest(
      contentVersion: contentVersion,
      generatedAt: json['generated_at']?.toString(),
      payloadUrl: payloadUrl,
    );
  }
}

class _ContentPayload {
  _ContentPayload({
    required this.cocktails,
    required this.ingredients,
    required this.cocktailIngredients,
  });

  final List<Map<String, dynamic>> cocktails;
  final List<Map<String, dynamic>> ingredients;
  final List<Map<String, dynamic>> cocktailIngredients;

  factory _ContentPayload.fromJson(Map<String, dynamic> json) {
    return _ContentPayload(
      cocktails: _asObjectList(json['cocktails']),
      ingredients: _asObjectList(json['ingredients']),
      cocktailIngredients: _asObjectList(json['cocktail_ingredients']),
    );
  }

  static List<Map<String, dynamic>> _asObjectList(dynamic value) {
    if (value is! List) return const [];

    final output = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is Map) {
        output.add(Map<String, dynamic>.from(item));
      }
    }
    return output;
  }
}
