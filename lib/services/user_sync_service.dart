import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';

/// Syncs user-specific data (favourites, bar inventory, collections) between
/// local SQLite and Firestore users/{uid} document.
///
/// Strategy:
/// - Pull on sign-in (Firestore wins — handles reinstall/new device)
/// - Push on every local write (write-through)
/// - No account → local only, no changes to existing behaviour
class UserSyncService {
  UserSyncService(this._db);

  final AppDatabase _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Pull (on sign-in) ────────────────────────────────────────────────────

  /// Pull all user data from Firestore and replace local SQLite state.
  /// Called once on sign-in. Safe to call on fresh install (empty Firestore doc).
  Future<void> pullFromFirestore(String uid) async {
    try {
      // Retry any deletes that failed to reach Firestore last time, before
      // we pull — otherwise a delete that only succeeded locally would have
      // its cocktail resurrected by the pull below.
      await _flushPendingDeletes(uid);

      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data()!;

      await _db.transaction(() async {
        await _pullFavourites(data);
        await _pullBars(data);
        await _pullCollections(data);
      });

      // User cocktails use a subcollection — pull separately
      await pullUserCocktails(uid);

      _log('Pull complete for $uid');
    } catch (e, st) {
      _log('Pull failed: $e\n$st');
    }
  }

  Future<void> _pullFavourites(Map<String, dynamic> data) async {
    final raw = data['favourites'] as List? ?? [];
    final firestoreIds = raw.map((e) => e.toString()).toList();

    // Replace all local favourites with Firestore state
    await _db.delete(_db.favorites).go();
    for (final fsId in firestoreIds) {
      await _db.into(_db.favorites).insert(
        FavoritesCompanion(firestoreId: Value(fsId)),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> _pullBars(Map<String, dynamic> data) async {
    final rawBars = data['bars'] as List? ?? [];
    if (rawBars.isEmpty) return;

    // Get all existing local ingredients for name→id lookup
    final allIngredients = await _db.select(_db.ingredients).get();
    final nameToId = {for (final i in allIngredients) i.name.toLowerCase(): i.id};

    // Clear existing bar data
    await _db.delete(_db.savedBarIngredients).go();
    await _db.delete(_db.savedBars).go();

    for (final rawBar in rawBars) {
      if (rawBar is! Map) continue;
      final name = rawBar['name'] as String? ?? 'My Bar';
      final isDefault = rawBar['is_default'] as bool? ?? false;
      final ingredientNames = (rawBar['ingredients'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final barId = await _db.into(_db.savedBars).insert(
        SavedBarsCompanion.insert(
          name: name,
          isDefault: Value(isDefault),
        ),
      );

      for (final ingName in ingredientNames) {
        final ingId = nameToId[ingName.toLowerCase()];
        if (ingId == null) continue;
        await _db.addIngredientToSavedBar(
          savedBarId: barId,
          ingredientId: ingId,
        );
      }
    }
  }

  Future<void> _pullCollections(Map<String, dynamic> data) async {
    final rawCollections = data['collections'] as List? ?? [];
    if (rawCollections.isEmpty) return;

    // Clear existing local collections
    await _db.delete(_db.collectionCocktails).go();
    await _db.delete(_db.collections).go();

    for (final rawCol in rawCollections) {
      if (rawCol is! Map) continue;
      final name = rawCol['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final description = rawCol['description'] as String?;
      final cocktailIds = (rawCol['cocktails'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final colId = await _db.into(_db.collections).insert(
        CollectionsCompanion.insert(
          name: name,
          description: Value(description),
        ),
      );

      for (final fsId in cocktailIds) {
        // insertOrIgnore: the new (collectionId, firestoreId) unique
        // constraint would otherwise throw on any duplicate already present
        // in the synced Firestore data.
        await _db.into(_db.collectionCocktails).insert(
          CollectionCocktailsCompanion.insert(
            collectionId: colId,
            firestoreId: fsId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    }
  }

  // ── Push favourites ──────────────────────────────────────────────────────

  /// Returns true on success, false if the push failed (already logged).
  Future<bool> pushFavourites(String uid) async {
    try {
      final favs = await _db.select(_db.favorites).get();
      final ids = favs.map((f) => f.firestoreId).toList();
      await _firestore.collection('users').doc(uid).update({
        'favourites': ids,
      });
      return true;
    } catch (e) {
      _log('pushFavourites failed: $e');
      return false;
    }
  }

  // ── Push bar inventory ───────────────────────────────────────────────────

  /// Returns true on success, false if the push failed (already logged).
  Future<bool> pushBars(String uid) async {
    try {
      final bars = await _db.select(_db.savedBars).get();
      final allIngredients = await _db.select(_db.ingredients).get();
      final idToName = {for (final i in allIngredients) i.id: i.name};

      final barData = <Map<String, dynamic>>[];
      for (final bar in bars) {
        final barIngredients = await _db.getSavedBarIngredients(bar.id);
        final names = barIngredients
            .map((i) => idToName[i.id])
            .whereType<String>()
            .toList();
        barData.add({
          'name': bar.name,
          'is_default': bar.isDefault,
          'ingredients': names,
        });
      }

      await _firestore.collection('users').doc(uid).update({
        'bars': barData,
      });
      return true;
    } catch (e) {
      _log('pushBars failed: $e');
      return false;
    }
  }

  // ── Push collections ─────────────────────────────────────────────────────

  /// Returns true on success, false if the push failed (already logged).
  Future<bool> pushCollections(String uid) async {
    try {
      final collections = await _db.select(_db.collections).get();
      final colData = <Map<String, dynamic>>[];

      for (final col in collections) {
        final cocktails = await (_db.select(_db.collectionCocktails)
              ..where((cc) => cc.collectionId.equals(col.id)))
            .get();
        final ids = cocktails.map((cc) => cc.firestoreId).toList();
        colData.add({
          'name': col.name,
          'description': col.description,
          'cocktails': ids,
        });
      }

      await _firestore.collection('users').doc(uid).update({
        'collections': colData,
      });
      return true;
    } catch (e) {
      _log('pushCollections failed: $e');
      return false;
    }
  }

  // ── Push user cocktails ──────────────────────────────────────────────────

  /// Returns true on success, false if the push failed (already logged).
  Future<bool> pushUserCocktails(String uid) async {
    try {
      final cocktails = await _db.getUserCocktails();
      final colRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('user_cocktails');

      for (final cocktail in cocktails) {
        final fsId = cocktail.firestoreId;
        if (fsId == null || fsId.isEmpty) continue;

        final ingredients = await _db.getUserCocktailIngredients(cocktail.id);
        final ingData = ingredients
            .map((i) => {
                  'name': i.ingredientName,
                  'amount': i.amount,
                  'unit': i.unit,
                  'prep_note': i.prepNote,
                  'sort_order': i.sortOrder,
                })
            .toList();

        await colRef.doc(fsId).set({
          'name': cocktail.name,
          'method': cocktail.method,
          'glass': cocktail.glass,
          'base_spirit': cocktail.baseSpirit,
          'category': cocktail.category,
          'difficulty': cocktail.difficulty,
          'ice': cocktail.ice,
          'garnish': cocktail.garnish,
          'notes': cocktail.notes,
          'tags': cocktail.tags,
          'image_url': cocktail.imageUrl,
          'is_ai_generated': cocktail.isAiGenerated,
          'created_at': cocktail.createdAt.toIso8601String(),
          'updated_at': cocktail.updatedAt.toIso8601String(),
          'ingredients': ingData,
        });
      }

      _log('pushUserCocktails complete for $uid (${cocktails.length} cocktails)');
      return true;
    } catch (e, st) {
      _log('pushUserCocktails failed: $e\n$st');
      return false;
    }
  }

  /// Returns true on success, false if the push failed (already logged).
  /// Also returns true when there is nothing to push (cocktail missing or
  /// not yet assigned a Firestore id) — those aren't sync failures.
  Future<bool> pushSingleUserCocktail(String uid, int localId) async {
    try {
      final cocktail = await (_db.select(_db.userCocktails)
            ..where((u) => u.id.equals(localId)))
          .getSingleOrNull();
      if (cocktail == null) return true;
      final fsId = cocktail.firestoreId;
      if (fsId == null || fsId.isEmpty) return true;

      final ingredients = await _db.getUserCocktailIngredients(localId);
      final ingData = ingredients
          .map((i) => {
                'name': i.ingredientName,
                'amount': i.amount,
                'unit': i.unit,
                'prep_note': i.prepNote,
                'sort_order': i.sortOrder,
              })
          .toList();

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('user_cocktails')
          .doc(fsId)
          .set({
        'name': cocktail.name,
        'method': cocktail.method,
        'glass': cocktail.glass,
        'base_spirit': cocktail.baseSpirit,
        'category': cocktail.category,
        'difficulty': cocktail.difficulty,
        'ice': cocktail.ice,
        'garnish': cocktail.garnish,
        'notes': cocktail.notes,
        'tags': cocktail.tags,
        'image_url': cocktail.imageUrl,
        'is_ai_generated': cocktail.isAiGenerated,
        'created_at': cocktail.createdAt.toIso8601String(),
        'updated_at': cocktail.updatedAt.toIso8601String(),
        'ingredients': ingData,
      });
      return true;
    } catch (e) {
      _log('pushSingleUserCocktail failed: $e');
      return false;
    }
  }

  /// Deletes a user cocktail's Firestore doc. Returns true on success.
  /// On failure the delete is queued locally (see [_addPendingDelete]) and
  /// retried on the next [pullFromFirestore], so a delete that fails while
  /// offline isn't lost or silently resurrected by a later pull.
  Future<bool> deleteUserCocktailFromFirestore(String uid, String fsId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('user_cocktails')
          .doc(fsId)
          .delete();
      return true;
    } catch (e) {
      _log('deleteUserCocktailFromFirestore failed: $e');
      await _addPendingDelete(uid, fsId);
      return false;
    }
  }

  // ── Pending deletes (per uid, retried on next pull) ─────────────────────

  static const _pendingDeletesKeyPrefix = 'pending_user_cocktail_deletes_';

  Future<void> _addPendingDelete(String uid, String fsId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_pendingDeletesKeyPrefix$uid';
    final pending = prefs.getStringList(key) ?? <String>[];
    if (!pending.contains(fsId)) {
      pending.add(fsId);
      await prefs.setStringList(key, pending);
    }
  }

  Future<void> _flushPendingDeletes(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_pendingDeletesKeyPrefix$uid';
    final pending = prefs.getStringList(key) ?? <String>[];
    if (pending.isEmpty) return;

    final stillPending = <String>[];
    for (final fsId in pending) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('user_cocktails')
            .doc(fsId)
            .delete();
      } catch (e) {
        stillPending.add(fsId);
        _log('flushPendingDeletes: retry failed for $fsId: $e');
      }
    }

    if (stillPending.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setStringList(key, stillPending);
    }
  }

  // ── Pull user cocktails ──────────────────────────────────────────────────

  Future<void> pullUserCocktails(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('user_cocktails')
          .get();

      final remoteIds = snapshot.docs.map((d) => d.id).toSet();

      await _db.transaction(() async {
        // Remove local user-cocktails that no longer exist remotely (e.g.
        // deleted from another device) before upserting what's left —
        // otherwise a delete that happened elsewhere would never take
        // effect here, and the cocktail would stay resurrected locally.
        final localCocktails = await _db.getUserCocktails();
        for (final cocktail in localCocktails) {
          final fsId = cocktail.firestoreId;
          if (fsId != null && fsId.isNotEmpty && !remoteIds.contains(fsId)) {
            await _db.deleteUserCocktail(cocktail.id);
          }
        }

        for (final doc in snapshot.docs) {
          final d = doc.data();
          final fsId = doc.id;

          final companion = UserCocktailsCompanion(
            name: Value(d['name'] as String? ?? ''),
            method: Value(d['method'] as String? ?? 'shake'),
            glass: Value(d['glass'] as String? ?? 'Coupe'),
            baseSpirit: Value(d['base_spirit'] as String? ?? 'Other'),
            category: Value(d['category'] as String? ?? 'cocktail'),
            difficulty: Value((d['difficulty'] as int?) ?? 2),
            ice: Value(d['ice'] as String?),
            garnish: Value(d['garnish'] as String?),
            notes: Value(d['notes'] as String?),
            tags: Value(d['tags'] as String?),
            imageUrl: Value(d['image_url'] as String?),
            isAiGenerated: Value(d['is_ai_generated'] as bool? ?? false),
            firestoreId: Value(fsId),
            updatedAt: Value(
              DateTime.tryParse(d['updated_at'] as String? ?? '') ?? DateTime.now(),
            ),
            createdAt: Value(
              DateTime.tryParse(d['created_at'] as String? ?? '') ?? DateTime.now(),
            ),
          );

          final rawIngredients = (d['ingredients'] as List<dynamic>? ?? []);
          final ingredientRows = rawIngredients
              .asMap()
              .entries
              .map((e) {
                final i = e.value as Map<String, dynamic>;
                return UserCocktailIngredientsCompanion(
                  userCocktailId: const Value.absent(), // filled in upsert
                  ingredientName: Value(i['name'] as String? ?? ''),
                  amount: Value((i['amount'] as num?)?.toDouble() ?? 0),
                  unit: Value(i['unit'] as String? ?? 'ml'),
                  prepNote: Value(i['prep_note'] as String?),
                  sortOrder: Value(i['sort_order'] as int? ?? e.key),
                );
              })
              .toList();

          await _db.upsertUserCocktailFromSync(companion, ingredientRows);
        }
      });

      _log('pullUserCocktails complete for $uid (${snapshot.docs.length} cocktails)');
    } catch (e, st) {
      _log('pullUserCocktails failed: $e\n$st');
    }
  }

  void _log(String message) {
    log('[UserSync] $message', name: 'UserSync');
  }
}
