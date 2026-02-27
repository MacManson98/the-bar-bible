# DB and Content Pipeline

## 1) Two Databases Explained

There are two phases of the same logical database file:

- Bundled asset DB: `assets/databases/cocktails.db` is shipped inside the app package (`pubspec.yaml` includes it).
- Runtime Drift DB: Drift opens `cocktails.db` from the app documents directory on-device.

In this repo, both point to the same filename (`cocktails.db`) and same documents directory path logic:

- Seed copy target: `lib/main.dart` -> `initDatabase()` writes to `getApplicationDocumentsDirectory()/cocktails.db`.
- Runtime open target: `lib/data/database.dart` -> `AppDatabase._openConnection()` opens `getApplicationDocumentsDirectory()/cocktails.db`.

After first install, the app uses the on-device runtime file. The asset file is only a source used for initial seeding.

## 2) Where the Asset DB is Seeded

Exact code path:

- Entry: `lib/main.dart` -> `main()` calls `initDatabase()` before `runApp(...)`.
- Seeding function: `lib/main.dart` -> `Future<AppDatabase> initDatabase()`.
- Copy logic in `initDatabase()`:
  - Build path: `final dbPath = p.join(dbFolder.path, 'cocktails.db');`
  - Check existence: `if (!await File(dbPath).exists()) { ... }`
  - Load asset: `rootBundle.load('assets/databases/cocktails.db')`
  - Write file: `File(dbPath).writeAsBytes(...)`

When it runs:

- `initDatabase()` runs every app launch.
- Actual copy/seed runs only when the target file does not exist (first launch on fresh install, or after uninstall/data wipe).
- There is no asset version check, hash check, or forced re-copy for existing users.

## 3) Drift Runtime DB Schema

Schema source files:

- Declarative schema: `lib/data/database.dart`
- Generated mapping/schema entities: `lib/data/database.g.dart` (`_$AppDatabase.allSchemaEntities`, table classes like `$CocktailsTable`)

Tables in `AppDatabase` (`@DriftDatabase(tables: [...])`):

- `cocktails`
- `ingredients`
- `cocktail_ingredients`
- `collections`
- `collection_cocktails`
- `saved_bars`
- `saved_bar_ingredients`
- `shopping_list`
- `favorites`

Version + migration:

- `schemaVersion`: `9` (`lib/data/database.dart`, `int get schemaVersion => 9`)
- `migration` (`MigrationStrategy`):
  - `onCreate`: `migrator.createAll()` + create unique index `idx_saved_bar_ingredients_unique`
  - `onUpgrade`: incremental blocks:
    - `from == 1`: add `cocktails.method_instructions`, `cocktails.history`
    - `from <= 2`: add `cocktails.image_path`
    - `from <= 4`: create `collections`, `collection_cocktails`
    - `from <= 5`: add `ingredients.category`; create `saved_bars`, `saved_bar_ingredients`, `shopping_list`
    - `from <= 6`: create `favorites`
    - `from <= 7`: add `cocktails.tasting_notes`
    - `from <= 8`: dedupe `saved_bar_ingredients`, then create unique index

Migration status confirmation:

- Yes, migrations exist and are active in `lib/data/database.dart`.
- Current migrations do not include a step that adds `cocktails.tiles_notes`.

## 4) Why 'no such column tiles_notes' happened

Failure mode:

- App code/gen code expects `cocktails.tiles_notes` (declared in `lib/data/database.dart` as `tilesNotes` mapped to `.named('tiles_notes')`, and emitted in `lib/data/database.g.dart` as part of `$CocktailsTable`).
- Older installed DBs that never got this column will fail when Drift queries `cocktails` including `tiles_notes`.
- SQLite then throws: `no such column: tiles_notes`.

Why migration allowed this:

- `schemaVersion` is currently `9`, but no `onUpgrade` branch adds `tiles_notes`.
- If a user is already at DB version 9 from older app state, no further migration runs, so missing column remains missing.

## 5) What happens when we update cocktails.db

What changing `assets/databases/cocktails.db` affects:

- New installs (or clean reinstalls/data wipes): yes, they seed from the new asset.

What it does not affect:

- Existing installs that already have `.../cocktails.db`: no automatic data refresh from updated asset.

Current repo behavior for existing users:

- The app does not re-copy or refresh asset DB content once the file exists.
- This is enforced by `if (!File(dbPath).exists())` in `initDatabase()`.

## 6) How to support content updates without reinstall/app update

High-level plan for this repo (no implementation details):

1. Add a local content version record.
- Add a tiny table in Drift, e.g. `content_metadata(key TEXT PRIMARY KEY, value TEXT)` or a dedicated `content_state` row.
- Store at least: `content_version` and `last_synced_at`.

2. Introduce a content sync service layer.
- Create a repository/service near `lib/data/` that fetches a remote JSON export (or DB snapshot transformed to JSON payload).
- Trigger sync on app start after DB open, plus manual retry path in Settings.

3. Use deterministic upserts for content tables only.
- Upsert into content tables: `cocktails`, `ingredients`, `cocktail_ingredients`.
- Prefer stable IDs from export so relations remain intact.
- For removed content, use soft-delete flags or controlled delete pass for content-owned rows.

4. Keep user-owned tables untouched.
- Do not wipe/replace: `favorites`, `collections`, `collection_cocktails`, `saved_bars`, `saved_bar_ingredients`, `shopping_list`.
- Preserve user state by only mutating content tables.

5. Wrap sync in one transaction.
- Validate payload version.
- Apply upserts in dependency order (`ingredients` -> `cocktails` -> `cocktail_ingredients`).
- Update local `content_version` only after successful commit.

6. Coordinate schema migrations with content sync.
- Schema changes (new columns/tables) still require Drift `schemaVersion` bump + `onUpgrade` migration.
- Content-only additions can flow through sync without app reinstall.

## 7) Checklist for future changes

- Adding a column/table:
  - Bump `schemaVersion` in `lib/data/database.dart`.
  - Add explicit `onUpgrade` migration for existing installs.
  - Regenerate Drift output (`database.g.dart`).
- Adding new cocktails/content only:
  - Use content sync pipeline (or accept that asset update only reaches new installs/app reinstalls).
- Testing upgrade paths:
  - Install old build with old DB state.
  - Upgrade to new build.
  - Verify migrations ran and critical queries succeed (including new columns like `tiles_notes`).
  - Verify user tables/data persist (`favorites`, collections, bars).

## Key Files Index

- `pubspec.yaml`
- `assets/databases/cocktails.db`
- `lib/main.dart`
- `lib/data/database.dart`
- `lib/data/database.g.dart`
- `lib/screens/settings_screen.dart` (natural place for manual "sync now" trigger if added)
