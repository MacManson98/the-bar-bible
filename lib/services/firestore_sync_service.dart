import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';

/// Syncs cocktail/ingredient data from Firestore into local Drift cache.
/// User data (favourites, bar inventory, collections) stays local only.
class FirestoreSyncService {
  FirestoreSyncService(this._db);

  final AppDatabase _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _lastSyncKey = 'firestore_sync.last_sync_ms';
  static const int _syncIntervalHours = 24;

  /// Syncs if no sync has occurred in the last [_syncIntervalHours] hours.
  Future<void> syncIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursSinceLast = (now - lastSync) / (1000 * 60 * 60);

      if (hoursSinceLast < _syncIntervalHours) {
        _log('Skipped: last sync was ${hoursSinceLast.toStringAsFixed(1)}h ago');
        return;
      }

      await sync();
      await prefs.setInt(_lastSyncKey, now);
    } catch (e, st) {
      _log('Sync failed: $e\n$st');
    }
  }

  /// Force a full sync regardless of last sync time.
  Future<void> sync() async {
    _log('Starting sync...');

    final cocktailSnap = await _firestore.collection('cocktails').get();
    final ingredientSnap = await _firestore.collection('ingredients').get();

    _log('Fetched ${cocktailSnap.docs.length} cocktails, ${ingredientSnap.docs.length} ingredients');

    await _db.transaction(() async {
      // ── Ingredients master list ─────────────────────────────────────────
      for (final doc in ingredientSnap.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        final category = data['category'] as String? ?? 'Other';
        if (name.isEmpty) continue;

        await _db.into(_db.ingredients).insert(
          IngredientsCompanion(
            name: Value(name),
            category: Value(category),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }

      // Build ingredient name → local id map
      final allIngredients = await _db.select(_db.ingredients).get();
      final ingredientIdMap = {
        for (final i in allIngredients) i.name: i.id,
      };

      // ── Cocktails ────────────────────────────────────────────────────────
      for (final doc in cocktailSnap.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        if (name.isEmpty) continue;

        final tags = (data['tags'] as List?)?.join(',') ?? '';
        final isPremium = data['is_premium'] as bool? ?? false;

        // Upsert cocktail by name (use insertOnConflictUpdate keyed on name)
        // We need the local id after insert, so check first
        final existing = await (_db.select(_db.cocktails)
              ..where((c) => c.name.equals(name)))
            .getSingleOrNull();

        final companion = CocktailsCompanion(
          firestoreId: Value(doc.id),
          name: Value(name),
          method: Value(data['method'] as String? ?? ''),
          methodInstructions: Value(data['method_instructions'] as String?),
          history: Value(data['history'] as String?),
          tastingNotes: Value(data['tasting_notes'] as String?),
          tilesNotes: Value(data['tiles_notes'] as String?),
          glass: Value(data['glass'] as String? ?? ''),
          ice: Value(data['ice'] as String?),
          garnish: Value(data['garnish'] as String?),
          baseSpirit: Value(data['base_spirit'] as String? ?? ''),
          difficulty: Value((data['difficulty'] as num?)?.toInt() ?? 2),
          tags: Value(tags),
          imagePath: Value(data['image_path'] as String?),
          imageUrl: Value(data['image_url'] as String?),
          category: Value(data['category'] as String? ?? 'cocktail'),
          isPremium: Value(isPremium),
        );

        int cocktailId;
        if (existing != null) {
          await (_db.update(_db.cocktails)
                ..where((c) => c.id.equals(existing.id)))
              .write(companion);
          cocktailId = existing.id;
        } else {
          cocktailId = await _db.into(_db.cocktails).insert(companion);
        }

        // ── Ingredients for this cocktail ──────────────────────────────
        final rawIngredients = data['ingredients'] as List? ?? [];

        // Delete existing relationships for this cocktail
        await (_db.delete(_db.cocktailIngredients)
              ..where((ci) => ci.cocktailId.equals(cocktailId)))
            .go();

        for (final ing in rawIngredients) {
          if (ing is! Map) continue;
          final ingName = ing['name'] as String? ?? '';
          if (ingName.isEmpty) continue;

          // Ensure ingredient exists in master list
          var ingId = ingredientIdMap[ingName];
          if (ingId == null) {
            final category = ing['category'] as String? ?? 'Other';
            ingId = await _db.into(_db.ingredients).insert(
              IngredientsCompanion(
                name: Value(ingName),
                category: Value(category),
              ),
            );
            ingredientIdMap[ingName] = ingId;
          }

          // Read unit — fall back to 'ml' for legacy docs without unit field
          final unit = ing['unit'] as String? ?? 'ml';
          // For ml/oz use the numeric amount; for others use the string amount
          final double amount;
          if (unit == 'ml') {
            amount = (ing['amount_ml'] as num?)?.toDouble() ?? 0.0;
          } else if (unit == 'oz') {
            amount = (ing['amount_oz'] as num?)?.toDouble() ?? 0.0;
          } else {
            // Non-liquid: store numeric portion of amount string (e.g. "2" from "2 dash")
            final raw = ing['amount']?.toString() ?? '';
            amount = double.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
          }

          await _db.into(_db.cocktailIngredients).insert(
            CocktailIngredientsCompanion(
              cocktailId: Value(cocktailId),
              ingredientId: Value(ingId),
              amount: Value(amount),
              unit: Value(unit),
              prepNote: Value(ing['prep_note'] as String?),
            ),
          );
        }
      }
    });

    _log('Sync complete: ${cocktailSnap.docs.length} cocktails cached locally');
  }

  void _log(String message) {
    log('[FirestoreSync] $message', name: 'FirestoreSync');
  }
}
