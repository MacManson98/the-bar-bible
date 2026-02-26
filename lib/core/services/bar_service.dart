import 'package:drift/drift.dart';
import '../../data/database.dart';

class BarService {
  final AppDatabase db;
  BarService(this.db);

  /// Marks [barId] as default and clears all other defaults.
  Future<void> setDefaultBar(int barId) async {
    await (db.update(db.savedBars)
          ..where((b) => b.isDefault.equals(true)))
        .write(const SavedBarsCompanion(isDefault: Value(false)));
    await (db.update(db.savedBars)
          ..where((b) => b.id.equals(barId)))
        .write(SavedBarsCompanion(
          isDefault: const Value(true),
          lastUsed: Value(DateTime.now()),
        ));
  }

  Future<SavedBar?> getDefaultBar() => db.getDefaultSavedBar();

  Future<List<SavedBar>> getBarsOrderedByRecent() =>
      (db.select(db.savedBars)
        ..orderBy([(b) => OrderingTerm.desc(b.lastUsed)]))
          .get();
}
