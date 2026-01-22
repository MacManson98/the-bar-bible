import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../core/theme/app_theme.dart';
import '../data/database.dart';
import 'add_cocktails_dialog.dart';
import 'cocktail_detail_screen.dart';

class CollectionsScreen extends StatefulWidget {
  final AppDatabase database;
  final void Function(int)? onSwitchToTab;

  const CollectionsScreen({super.key, required this.database, this.onSwitchToTab});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<Collection> collections = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final cols = await widget.database.select(widget.database.collections).get();
    setState(() {
      collections = cols;
      isLoading = false;
    });
  }

  Future<void> _createCollection() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'NEW COLLECTION',
          style: TextStyle(
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Collection Name',
                hintText: 'e.g., Summer Classics',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What\'s this collection about?',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: AppTheme.primaryDark,
            ),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await widget.database.into(widget.database.collections).insert(
        CollectionsCompanion.insert(
          name: nameController.text.trim(),
          description: descController.text.trim().isEmpty ? const Value.absent() : Value(descController.text.trim()),
        ),
      );
      _loadCollections();
    }
  }

  Future<void> _deleteCollection(Collection collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Collection?'),
        content: Text('Are you sure you want to delete "${collection.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete collection cocktails first
      await (widget.database.delete(widget.database.collectionCocktails)
        ..where((tbl) => tbl.collectionId.equals(collection.id))).go();
      // Delete collection
      await (widget.database.delete(widget.database.collections)
        ..where((tbl) => tbl.id.equals(collection.id))).go();
      _loadCollections();
    }
  }

  Future<int> _getCollectionCocktailCount(int collectionId) async {
    final result = await (widget.database.selectOnly(widget.database.collectionCocktails)
      ..addColumns([widget.database.collectionCocktails.id.count()])
      ..where(widget.database.collectionCocktails.collectionId.equals(collectionId))
    ).getSingle();
    
    return result.read(widget.database.collectionCocktails.id.count()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'COLLECTIONS',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : collections.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Add extra bottom padding
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    return _CollectionCard(
                      collection: collection,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CollectionDetailScreen(
                              database: widget.database,
                              collection: collection,
                            ),
                          ),
                        );
                        _loadCollections();
                        // If result is 0, switch to cocktails tab
                        if (result == 0 && mounted) {
                          widget.onSwitchToTab?.call(0);
                        }
                      },
                      onDelete: () => _deleteCollection(collection),
                      getCocktailCount: () => _getCollectionCocktailCount(collection.id),
                    );
                  },
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80), // Lift above bottom nav
        child: FloatingActionButton.extended(
          onPressed: _createCollection,
          backgroundColor: AppTheme.accentGold,
          foregroundColor: AppTheme.primaryDark,
          icon: const Icon(Icons.add),
          label: const Text(
            'NEW COLLECTION',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.collections_bookmark,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 24),
          const Text(
            'NO COLLECTIONS YET',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create collections to organize\nyour favorite cocktails',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createCollection,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'CREATE COLLECTION',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final Collection collection;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Future<int> Function() getCocktailCount;

  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.onDelete,
    required this.getCocktailCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.collections_bookmark,
                    color: AppTheme.accentGold,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      if (collection.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          collection.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      FutureBuilder<int>(
                        future: getCocktailCount(),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Text(
                            '$count ${count == 1 ? 'cocktail' : 'cocktails'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.accentGold,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Collection Detail Screen - shows cocktails in a collection
class CollectionDetailScreen extends StatefulWidget {
  final AppDatabase database;
  final Collection collection;

  const CollectionDetailScreen({
    super.key,
    required this.database,
    required this.collection,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  List<Cocktail> cocktails = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCocktails();
  }

  Future<void> _loadCocktails() async {
    print('🔍 Loading cocktails for collection ${widget.collection.id}');
    
    // First check what's in the junction table
    final junctionEntries = await widget.database.select(widget.database.collectionCocktails).get();
    print('📊 Total junction table entries: ${junctionEntries.length}');
    for (var entry in junctionEntries) {
      print('   - Collection ${entry.collectionId} -> Cocktail ${entry.cocktailId}');
    }
    
    // Join query to get cocktails in this collection
    final query = widget.database.select(widget.database.cocktails).join([
      innerJoin(
        widget.database.collectionCocktails,
        widget.database.collectionCocktails.cocktailId.equalsExp(widget.database.cocktails.id),
      ),
    ])..where(widget.database.collectionCocktails.collectionId.equals(widget.collection.id));

    final results = await query.get();
    print('🍸 Found ${results.length} cocktails in this collection');
    
    setState(() {
      cocktails = results.map((row) => row.readTable(widget.database.cocktails)).toList();
      isLoading = false;
    });
    
    print('✅ Loaded ${cocktails.length} cocktails');
  }

  Future<void> _removeCocktail(int cocktailId) async {
    await (widget.database.delete(widget.database.collectionCocktails)
      ..where((tbl) { 
        return tbl.collectionId.equals(widget.collection.id) & tbl.cocktailId.equals(cocktailId);
      })
    ).go();
    _loadCocktails();
  }

  Future<void> _showAddCocktailsDialog() async {
    // Get all cocktails
    final allCocktails = await widget.database.select(widget.database.cocktails).get();
    
    // Get cocktails already in this collection
    final existingCocktails = await (widget.database.select(widget.database.collectionCocktails)
      ..where((tbl) => tbl.collectionId.equals(widget.collection.id))
    ).get();
    
    final existingCocktailIds = existingCocktails.map((e) => e.cocktailId).toSet();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AddCocktailsDialog(
        database: widget.database,
        collection: widget.collection,
        allCocktails: allCocktails,
        existingCocktailIds: existingCocktailIds,
        onClose: _loadCocktails,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.collection.name.toUpperCase(),
          style: const TextStyle(
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cocktails.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Add extra bottom padding for nav bar
                  itemCount: cocktails.length,
                  itemBuilder: (context, index) {
                    final cocktail = cocktails[index];
                    return _buildCocktailCard(cocktail);
                  },
                ),
      floatingActionButton: cocktails.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80), // Lift above bottom nav
              child: FloatingActionButton.extended(
                onPressed: _showAddCocktailsDialog,
                backgroundColor: AppTheme.accentGold,
                foregroundColor: AppTheme.primaryDark,
                icon: const Icon(Icons.add),
                label: const Text(
                  'ADD COCKTAILS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCocktailCard(Cocktail cocktail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to cocktail detail
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CocktailDetailScreen(
                  database: widget.database,
                  cocktail: cocktail,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Row(
              children: [
                if (cocktail.imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      cocktail.imagePath!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_bar, color: AppTheme.accentGold),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_bar, color: AppTheme.accentGold),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cocktail.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cocktail.baseSpirit.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _removeCocktail(cocktail.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.local_bar,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'NO COCKTAILS YET',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add cocktails to this collection\nfrom the cocktail detail screen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddCocktailsDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            icon: const Icon(Icons.add),
            label: const Text(
              'ADD COCKTAILS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
