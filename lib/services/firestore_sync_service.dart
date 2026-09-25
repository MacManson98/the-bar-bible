import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';

/// Syncs cocktail/ingredient data from Firestore into local Drift cache.
/// User data (favourites, bar inventory, collections) stays local only.
class FirestoreSyncService {
  FirestoreSyncService(this._db, {VoidCallback? onSynced}) : _onSynced = onSynced;

  final AppDatabase _db;
  final VoidCallback? _onSynced;
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
      // Matched by name, not blind insertOrReplace: ingredients.name now has
      // a unique index (see database.dart migration 20→21), and
      // insertOrReplace on a unique-but-not-primary-key column deletes and
      // re-inserts the conflicting row with a NEW id — which would silently
      // orphan every saved-bar/cocktail row that referenced the old id on
      // every single sync. Select-then-insert-or-update preserves the id.
      for (final doc in ingredientSnap.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? '';
        final category = data['category'] as String? ?? 'Other';
        if (name.isEmpty) continue;

        final existing = await (_db.select(_db.ingredients)
              ..where((i) => i.name.equals(name)))
            .getSingleOrNull();
        if (existing != null) {
          if (existing.category != category) {
            await (_db.update(_db.ingredients)..where((i) => i.id.equals(existing.id)))
                .write(IngredientsCompanion(category: Value(category)));
          }
        } else {
          await _db.into(_db.ingredients).insert(
            IngredientsCompanion.insert(name: name, category: Value(category)),
          );
        }
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
    // Catalog-reading screens (Browse, Finder) cache their cocktail/ingredient
    // snapshot in memory and never re-query on their own — see
    // CatalogSyncNotifier for why. Only fires after a real sync, never on
    // syncIfNeeded()'s throttled skip (that path never calls sync() at all).
    _onSynced?.call();
  }

  void _log(String message) {
    log('[FirestoreSync] $message', name: 'FirestoreSync');
  }
}
