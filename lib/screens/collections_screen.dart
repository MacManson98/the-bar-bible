import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/image_utils.dart';
import '../data/database.dart';
import '../services/auth_service.dart';
import '../services/user_sync_service.dart';
import '../widgets/vault/vault_widgets.dart';
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
  Map<int, CollectionMeta> collectionMetaById = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _pushCollectionsToCloud() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    final synced = await UserSyncService(widget.database).pushCollections(uid);
    if (!synced && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t sync to cloud — will retry later')),
      );
    }
  }

  Future<void> _loadCollections() async {
    final cols = await widget.database.select(widget.database.collections).get();

    final collectionCocktails = widget.database.collectionCocktails;
    final countExpression = collectionCocktails.id.count();
    final countRows = await (widget.database.selectOnly(collectionCocktails)
          ..addColumns([collectionCocktails.collectionId, countExpression])
          ..groupBy([collectionCocktails.collectionId]))
        .get();

    final cocktails = widget.database.cocktails;
    final previewRows = await widget.database
        .select(collectionCocktails)
        .join([
          innerJoin(
            cocktails,
            cocktails.firestoreId.equalsExp(collectionCocktails.firestoreId),
          ),
        ])
        .get();

    final previewCandidatesByCollectionId = <int, List<_PreviewCandidate>>{};
    for (final row in previewRows) {
      final relation = row.readTable(collectionCocktails);
      final cocktail = row.readTable(cocktails);
      final list = previewCandidatesByCollectionId.putIfAbsent(relation.collectionId, () => []);
      if (list.length < 3) {
        list.add(_PreviewCandidate(
          imagePath: cocktail.imagePath,
          cocktailName: cocktail.name,
        ));
      }
    }

    final uniqueBasePaths = <String>{};
    for (final candidates in previewCandidatesByCollectionId.values) {
      for (final candidate in candidates) {
        uniqueBasePaths.add(_cocktailImageBasePath(candidate.imagePath, candidate.cocktailName));
      }
    }

    final resolvedByBasePath = <String, String?>{};
    await Future.wait(uniqueBasePaths.map((basePath) async {
      resolvedByBasePath[basePath] = await ImageUtils.findCocktailImage(basePath);
    }));

    final metaById = <int, CollectionMeta>{};
    final countById = <int, int>{};
    for (final row in countRows) {
      final collectionId = row.read(collectionCocktails.collectionId);
      if (collectionId != null) {
        countById[collectionId] = row.read(countExpression) ?? 0;
      }
    }

    for (final collection in cols) {
      final candidates = previewCandidatesByCollectionId[collection.id] ?? const <_PreviewCandidate>[];
      final previews = <String>[];
      for (final candidate in candidates) {
        if (previews.length >= 3) break;
        final basePath = _cocktailImageBasePath(candidate.imagePath, candidate.cocktailName);
        final resolvedPath = resolvedByBasePath[basePath];
        if (resolvedPath != null) {
          previews.add(resolvedPath);
        }
      }
      metaById[collection.id] = CollectionMeta(
        count: countById[collection.id] ?? 0,
        previewImagePaths: previews,
      );
    }

    if (!mounted) return;
    setState(() {
      collections = cols;
      collectionMetaById = metaById;
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
      _pushCollectionsToCloud();
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
      _pushCollectionsToCloud();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPushedRoute = Navigator.of(context).canPop();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            VaultScreenHeader(
              title: 'My Collections',
              subtitle:
                  '${collections.length} vault${collections.length == 1 ? '' : 's'}',
              showBack: isPushedRoute,
              ctaLabel: 'NEW',
              onCta: _createCollection,
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : collections.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.85,
                          ),
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
                              meta: collectionMetaById[collection.id] ??
                                  const CollectionMeta(
                                    count: 0,
                                    previewImagePaths: [],
                                  ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return VaultEmptyState(
      icon: Icons.collections_bookmark,
      title: 'No Collections Yet',
      body: 'Group cocktails into themed vaults. Build a menu for tonight, save classics by spirit, or organise your training list.',
      ctaLabel: 'Create Collection',
      onCta: _createCollection,
      useCases: const [
        VaultUseCaseHint(icon: Icons.local_bar, label: "Tonight's menu"),
        VaultUseCaseHint(icon: Icons.school_outlined, label: 'Training lists'),
        VaultUseCaseHint(icon: Icons.wb_sunny_outlined, label: 'Seasonal specials'),
      ],
    );
  }
}

class _CollectionCard extends StatefulWidget {
  final Collection collection;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final CollectionMeta meta;

  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.onDelete,
    required this.meta,
  });

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool _isPressed = false;

  String _toTitleCase(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: _showCollectionActions,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _isPressed ? 0.97 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.surfaceLight.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Container(
                  height: 88,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight.withValues(alpha: 0.35),
                  ),
                  child: _buildPreviewArea(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _toTitleCase(widget.collection.name),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${widget.meta.count} ${widget.meta.count == 1 ? 'cocktail' : 'cocktails'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCollectionActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete Collection'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == 'delete' && mounted) {
      widget.onDelete();
    }
  }

  Widget _buildPreviewArea() {
    final previews = widget.meta.previewImagePaths.take(3).toList();
    if (previews.isEmpty) {
      // Pick a cocktail icon deterministically based on collection name
      const icons = [
        Icons.local_bar,
        Icons.wine_bar,
        Icons.sports_bar,
        Icons.emoji_food_beverage,
        Icons.coffee,
        Icons.liquor,
        Icons.nightlife,
      ];
      final iconIndex = widget.collection.name.codeUnits.fold(0, (a, b) => a + b) % icons.length;
      final icon = icons[iconIndex];
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xFF1a1a14),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DotGridPainter(),
                  ),
                ),
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentGold.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: AppTheme.accentGold.withValues(alpha: 0.6),
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildPreviewFade(),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          children: List.generate(previews.length, (index) {
            final path = previews[index];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 2),
                child: Image.asset(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.surfaceLight.withValues(alpha: 0.45),
                  ),
                ),
              ),
            );
          }),
        ),
        _buildPreviewFade(),
      ],
    );
  }

  Widget _buildPreviewFade() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surfaceDark.withValues(alpha: 0),
              AppTheme.surfaceDark.withValues(alpha: 0.92),
            ],
          ),
        ),
      ),
    );
  }
}

class CollectionMeta {
  final int count;
  final List<String> previewImagePaths;

  const CollectionMeta({
    required this.count,
    required this.previewImagePaths,
  });
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
  Map<int, String?> resolvedImagePathByCocktailId = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCocktails();
  }

  Future<void> _loadCocktails() async {
    // Join query to get cocktails in this collection
    final query = widget.database.select(widget.database.cocktails).join([
      innerJoin(
        widget.database.collectionCocktails,
        widget.database.collectionCocktails.firestoreId.equalsExp(widget.database.cocktails.firestoreId),
      ),
    ])..where(widget.database.collectionCocktails.collectionId.equals(widget.collection.id));

    final results = await query.get();
    final loadedCocktails = results.map((row) => row.readTable(widget.database.cocktails)).toList();
    final uniqueBasePaths = <String>{};
    for (final cocktail in loadedCocktails) {
      uniqueBasePaths.add(_cocktailImageBasePath(cocktail.imagePath, cocktail.name));
    }

    final resolvedByBasePath = <String, String?>{};
    await Future.wait(uniqueBasePaths.map((basePath) async {
      resolvedByBasePath[basePath] = await ImageUtils.findCocktailImage(basePath);
    }));

    final imageByCocktailId = <int, String?>{};
    for (final cocktail in loadedCocktails) {
      final basePath = _cocktailImageBasePath(cocktail.imagePath, cocktail.name);
      imageByCocktailId[cocktail.id] = resolvedByBasePath[basePath];
    }

    if (!mounted) return;
    setState(() {
      cocktails = loadedCocktails;
      resolvedImagePathByCocktailId = imageByCocktailId;
      isLoading = false;
    });
  }

  Future<void> _removeCocktail(String firestoreId) async {
    await (widget.database.delete(widget.database.collectionCocktails)
      ..where((tbl) { 
        return tbl.collectionId.equals(widget.collection.id) & tbl.firestoreId.equals(firestoreId);
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
    
    final existingFirestoreIds = existingCocktails.map((e) => e.firestoreId).toSet();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AddCocktailsDialog(
        database: widget.database,
        collection: widget.collection,
        allCocktails: allCocktails,
        existingFirestoreIds: existingFirestoreIds,
        onClose: _loadCocktails,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            VaultScreenHeader(
              title: widget.collection.name,
              subtitle:
                  '${cocktails.length} ${cocktails.length == 1 ? 'cocktail' : 'cocktails'}',
              showBack: true,
              ctaLabel: 'ADD',
              onCta: _showAddCocktailsDialog,
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : cocktails.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                          itemCount: cocktails.length,
                          itemBuilder: (context, index) {
                            final cocktail = cocktails[index];
                            return _buildCocktailCard(cocktail);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCocktailCard(Cocktail cocktail) {
    final resolvedPath = resolvedImagePathByCocktailId[cocktail.id];
    return VaultCocktailRow(
      cocktail: cocktail,
      resolvedImagePath: resolvedPath,
      onTap: () {
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
      onLongPress: () => _showCocktailActions(cocktail),
    );
  }

  Future<void> _showCocktailActions(Cocktail cocktail) async {
    await showVaultDestructiveSheet(
      context,
      itemName: cocktail.name,
      destructiveLabel: 'Remove From Collection',
      destructiveIcon: Icons.remove_circle_outline,
      onConfirm: () => _removeCocktail(cocktail.firestoreId ?? cocktail.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')),
    );
  }

  Widget _buildEmptyState() {
    return VaultEmptyState(
      icon: Icons.local_bar,
      title: 'NO COCKTAILS YET',
      body: 'Add cocktails to this collection\nfrom the cocktail detail screen',
      ctaLabel: 'ADD COCKTAILS',
      onCta: _showAddCocktailsDialog,
    );
  }
}

String _cocktailImageBasePath(String? imagePath, String cocktailName) {
  final raw = imagePath?.trim();
  if (raw != null && raw.isNotEmpty) {
    if (raw.contains('.')) {
      return raw.substring(0, raw.lastIndexOf('.'));
    }
    return raw;
  }
  return ImageUtils.generateBasePathFromName(cocktailName);
}

class _PreviewCandidate {
  final String? imagePath;
  final String cocktailName;

  const _PreviewCandidate({
    required this.imagePath,
    required this.cocktailName,
  });
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFd4af37).withValues(alpha: 0.07)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const spacing = 16.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
