import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
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
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data()!;

      await _db.transaction(() async {
        await _pullFavourites(data);
        await _pullBars(data);
        await _pullCollections(data);
      });

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
        await _db.into(_db.collectionCocktails).insert(
          CollectionCocktailsCompanion.insert(
            collectionId: colId,
            firestoreId: fsId,
          ),
        );
      }
    }
  }

  // ── Push favourites ──────────────────────────────────────────────────────

  Future<void> pushFavourites(String uid) async {
    try {
      final favs = await _db.select(_db.favorites).get();
      final ids = favs.map((f) => f.firestoreId).toList();
      await _firestore.collection('users').doc(uid).update({
        'favourites': ids,
      });
    } catch (e) {
      _log('pushFavourites failed: $e');
    }
  }

  // ── Push bar inventory ───────────────────────────────────────────────────

  Future<void> pushBars(String uid) async {
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
    } catch (e) {
      _log('pushBars failed: $e');
    }
  }

  // ── Push collections ─────────────────────────────────────────────────────

  Future<void> pushCollections(String uid) async {
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
    } catch (e) {
      _log('pushCollections failed: $e');
    }
  }

  void _log(String message) {
    log('[UserSync] $message', name: 'UserSync');
  }
}
