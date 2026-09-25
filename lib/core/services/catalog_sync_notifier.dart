import 'package:flutter/foundation.dart';

/// Pings listeners whenever the shared cocktail/ingredient catalog has just
/// been refreshed from Firestore (FirestoreSyncService.sync()/syncIfNeeded()).
///
/// Why this exists: main.dart's IndexedStack keeps every tab's State alive
/// for the whole app session, and each catalog-reading screen (Browse's
/// CocktailsListScreen, each FinderScreen) loads its cocktail/ingredient
/// snapshot once and keeps it in memory — nothing naturally re-queries the
/// DB after a later sync completes. Without this, a cocktail added on one
/// device (or even Force Sync'd on the same device) wouldn't show up until
/// the app was fully restarted. Screens that show the shared catalog listen
/// here and reload when it fires; FirestoreSyncService calls
/// [notifyCatalogSynced] itself after a real sync (not on a throttled skip),
/// so every caller of sync()/syncIfNeeded() benefits without repeating this
/// at each call site.
class CatalogSyncNotifier extends ChangeNotifier {
  void notifyCatalogSynced() => notifyListeners();
}
