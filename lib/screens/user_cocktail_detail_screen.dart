import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Expression;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../data/database.dart';
import '../services/auth_service.dart';
import '../services/user_sync_service.dart';
import '../widgets/favorite_button.dart';
import 'cocktail_creator_screen.dart';

class UserCocktailDetailScreen extends StatefulWidget {
  final AppDatabase database;
  final UserCocktail cocktail;

  const UserCocktailDetailScreen({
    super.key,
    required this.database,
    required this.cocktail,
  });

  @override
  State<UserCocktailDetailScreen> createState() => _UserCocktailDetailScreenState();
}

class _UserCocktailDetailScreenState extends State<UserCocktailDetailScreen> {
  List<UserCocktailIngredient> _ingredients = [];
  bool _isLoading = true;
  late UserCocktail _cocktail;

  @override
  void initState() {
    super.initState();
    _cocktail = widget.cocktail;
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    final rows = await widget.database.getUserCocktailIngredients(_cocktail.id);
    if (!mounted) return;
    setState(() {
      _ingredients = rows;
      _isLoading = false;
    });
  }

  String get _syntheticKey => AppDatabase.userCocktailKey(_cocktail.id);

  Future<void> _openEdit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CocktailCreatorScreen(
          database: widget.database,
          existing: _cocktail,
        ),
      ),
    );
    if (result == true && mounted) {
      // Reload updated cocktail from DB
      final updated = await (widget.database.select(widget.database.userCocktails)
            ..where((u) => u.id.equals(_cocktail.id)))
          .getSingleOrNull();
      if (updated != null && mounted) {
        setState(() => _cocktail = updated);
        _loadIngredients();
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Delete Cocktail?',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently delete "${_cocktail.name}" and remove it from any favourites or collections.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.database.deleteUserCocktail(_cocktail.id);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _showAddToCollectionDialog() async {
    final collections =
        await widget.database.select(widget.database.collections).get();
    if (!mounted) return;

    if (collections.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('No Collections',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: const Text('Create a collection first to save cocktails.',
              style: TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final key = _syntheticKey;
    final existingEntries = await (widget.database
            .select(widget.database.collectionCocktails)
          ..where((tbl) => tbl.firestoreId.equals(key)))
        .get();
    if (!mounted) return;
    final existingIds = existingEntries.map((e) => e.collectionId).toSet();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'ADD TO COLLECTION',
          style: TextStyle(
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final col = collections[index];
              final isIn = existingIds.contains(col.id);
              return ListTile(
                leading: Icon(
                  isIn ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isIn ? AppTheme.accentGold : AppTheme.textSecondary,
                ),
                title: Text(col.name,
                    style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () async {
                  if (isIn) {
                    final q = widget.database
                        .delete(widget.database.collectionCocktails);
                    q.where((tbl) => Expression.and([
                      tbl.collectionId.equals(col.id),
                      tbl.firestoreId.equals(key),
                    ]));
                    await q.go();
                  } else {
                    await widget.database
                        .into(widget.database.collectionCocktails)
                        .insert(CollectionCocktailsCompanion.insert(
                          collectionId: col.id,
                          firestoreId: key,
                        ));
                  }
                  if (context.mounted) {
                    final uid =
                        context.read<AuthService>().currentUser?.uid;
                    if (uid != null) {
                      UserSyncService(widget.database).pushCollections(uid);
                    }
                    Navigator.pop(context);
                    _showAddToCollectionDialog();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DONE',
                style: TextStyle(color: AppTheme.accentGold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: CustomScrollView(
        slivers: [
          // ── Header ───────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: _cocktail.imageUrl != null ? 260 : 0,
            pinned: true,
            collapsedHeight: 60,
            backgroundColor: AppTheme.primaryDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppTheme.accentGold),
                onPressed: _openEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _confirmDelete,
              ),
            ],
            flexibleSpace: _cocktail.imageUrl != null
                ? FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                    title: Text(
                      _cocktail.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: _cocktail.imageUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorWidget: (c, u, e) =>
                              Container(color: AppTheme.surfaceDark),
                        ),
                        Positioned(
                          left: 0, right: 0, bottom: 0, height: 120,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, AppTheme.primaryDark],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name (when no image)
                if (_cocktail.imageUrl == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      _cocktail.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                // ── Metadata chips ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _Chip(icon: Icons.local_bar, label: _cocktail.baseSpirit),
                      _Chip(
                        icon: Icons.liquor,
                        label: _cocktail.method[0].toUpperCase() +
                            _cocktail.method.substring(1),
                      ),
                      _Chip(icon: Icons.wine_bar, label: _cocktail.glass),
                      if (_cocktail.isAiGenerated)
                        const _Chip(icon: Icons.auto_awesome, label: 'AI Generated'),
                    ],
                  ),
                ),

                // Difficulty
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Text(
                    '★' * _cocktail.difficulty,
                    style: const TextStyle(fontSize: 16, color: AppTheme.accentGold),
                  ),
                ),

                // ── Action row ──────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppTheme.surfaceLight),
                      bottom: BorderSide(color: AppTheme.surfaceLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Favourite
                      Expanded(
                        child: InkWell(
                          onTap: () {}, // handled by FavoriteButton internally
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FavoriteButton(
                                  database: widget.database,
                                  firestoreId: _syntheticKey,
                                  showSnackbar: true,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Favourite',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, height: 28, color: AppTheme.surfaceLight),
                      // Collection
                      Expanded(
                        child: InkWell(
                          onTap: _showAddToCollectionDialog,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bookmark_add_outlined,
                                    size: 20, color: AppTheme.textSecondary),
                                SizedBox(width: 6),
                                Text(
                                  'Collection',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Ingredients ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.format_list_bulleted,
                              size: 18, color: AppTheme.accentGold),
                          SizedBox(width: 8),
                          Text(
                            'INGREDIENTS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: AppTheme.accentGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.accentGold),
                        )
                      else
                        ..._ingredients.map((ing) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      _formatAmount(ing),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ing.ingredientName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            color: AppTheme.textPrimary,
                                            height: 1.4,
                                          ),
                                        ),
                                        if (ing.prepNote != null &&
                                            ing.prepNote!.isNotEmpty)
                                          Text(
                                            ing.prepNote!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary
                                                  .withValues(alpha: 0.7),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),

                // ── Garnish ─────────────────────────────────────────────────
                if (_cocktail.garnish != null && _cocktail.garnish!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppTheme.surfaceLight)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.eco,
                            size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _cocktail.garnish!,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Notes ───────────────────────────────────────────────────
                if (_cocktail.notes != null && _cocktail.notes!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppTheme.surfaceLight)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.notes,
                                size: 18, color: AppTheme.accentGold),
                            SizedBox(width: 8),
                            Text(
                              'NOTES',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: AppTheme.accentGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _cocktail.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AppTheme.textSecondary
                                .withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Tags ────────────────────────────────────────────────────
                if (_cocktail.tags != null && _cocktail.tags!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _cocktail.tags!
                          .split(',')
                          .map((t) => t.trim())
                          .where((t) => t.isNotEmpty)
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceDark,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppTheme.surfaceLight
                                          .withValues(alpha: 0.6)),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(UserCocktailIngredient ing) {
    final amt = ing.amount;
    final formatted =
        amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(1);
    return '$formatted ${ing.unit}';
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
