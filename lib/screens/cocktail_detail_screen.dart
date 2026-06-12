import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/database.dart' as db;
import '../core/theme/app_theme.dart';
import '../core/utils/image_utils.dart';
import '../services/auth_service.dart';
import '../widgets/favorite_button.dart';
import 'admin_cocktail_editor_screen.dart';

class CocktailDetailScreen extends StatefulWidget {
  final db.AppDatabase database;
  final db.Cocktail cocktail;

  const CocktailDetailScreen({
    super.key,
    required this.database,
    required this.cocktail,
  });

  @override
  State<CocktailDetailScreen> createState() => _CocktailDetailScreenState();
}

class _CocktailDetailScreenState extends State<CocktailDetailScreen> {
  List<_CocktailIngredientWithName> ingredients = [];
  bool isLoading = true;
  bool isHistoryExpanded = false;
  String? _resolvedImagePath;
  int _batchSize = 1;
  bool _useOz = false;
  Set<int> _barIngredientIds = {};
  final Set<int> _busyAddIngredientIds = <int>{};
  int? _activeBarId;
  String _activeBarName = '';
  bool _isMissingSectionExpanded = false;
  bool _isLoadingEdit = false;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
    _resolveImagePath();
    _trackRecentlyViewed();
    _loadPreferences();
    _loadBarContext();
  }

  Future<void> _loadBarContext() async {
    final bar = await widget.database.getDefaultSavedBar();
    if (bar == null || !mounted) return;
    final barIngredients = await widget.database.getSavedBarIngredients(bar.id);
    if (!mounted) return;
    setState(() {
      _activeBarId = bar.id;
      _barIngredientIds = barIngredients.map((i) => i.id).toSet();
      _activeBarName = bar.name;
    });
  }

  Set<int> _requiredIngredientIds() {
    return ingredients.map((i) => i.cocktailIngredient.ingredientId).toSet();
  }

  List<_CocktailIngredientWithName> _missingIngredients() {
    return ingredients
        .where((i) => !_barIngredientIds.contains(i.cocktailIngredient.ingredientId))
        .toList();
  }

  Future<void> _addMissingIngredientToActiveBar(int ingredientId) async {
    final barId = _activeBarId;
    if (barId == null || _barIngredientIds.contains(ingredientId)) return;
    if (_busyAddIngredientIds.contains(ingredientId)) return;

    setState(() => _busyAddIngredientIds.add(ingredientId));
    try {
      await widget.database.addIngredientToSavedBar(
        savedBarId: barId,
        ingredientId: ingredientId,
      );
      if (!mounted) return;
      setState(() {
        _barIngredientIds = {..._barIngredientIds, ingredientId};
        if (_missingIngredients().isEmpty) _isMissingSectionExpanded = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add ingredient. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyAddIngredientIds.remove(ingredientId));
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _useOz = prefs.getBool('use_oz') ?? false);
    } catch (_) {}
  }

  Future<void> _trackRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('recently_viewed_ids') ?? [];
    final idStr = widget.cocktail.id.toString();
    ids.remove(idStr);
    ids.insert(0, idStr);
    if (ids.length > 10) ids.removeRange(10, ids.length);
    await prefs.setStringList('recently_viewed_ids', ids);
  }

  Future<void> _resolveImagePath() async {
    if (widget.cocktail.imageUrl != null && widget.cocktail.imageUrl!.isNotEmpty) {
      if (mounted) setState(() => _resolvedImagePath = widget.cocktail.imageUrl);
      return;
    }
    final basePath = widget.cocktail.imagePath ??
        ImageUtils.generateBasePathFromName(widget.cocktail.name);
    final resolved = await ImageUtils.findCocktailImage(basePath);
    if (mounted) setState(() => _resolvedImagePath = resolved);
  }

  Future<void> _openEditor() async {
    final firestoreId = widget.cocktail.firestoreId;
    if (firestoreId == null || firestoreId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Firestore ID — cannot edit this cocktail.')),
      );
      return;
    }
    setState(() => _isLoadingEdit = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('cocktails')
          .doc(firestoreId)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cocktail not found in Firestore.')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminCocktailEditorScreen(
            database: widget.database,
            stagingDocId: firestoreId,
            initialData: doc.data()!,
            saveLive: true,
          ),
        ),
      );
      if (mounted) {
        setState(() => isLoading = true);
        await _loadIngredients();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cocktail: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingEdit = false);
    }
  }

  Future<void> _showAddToCollectionDialog() async {
    final collections = await widget.database.select(widget.database.collections).get();
    if (!mounted) return;

    if (collections.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('No Collections'),
          content: const Text('Create a collection first to save cocktails.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final cocktailFsId = widget.cocktail.firestoreId ??
        widget.cocktail.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

    final existingCollections = await (widget.database.select(widget.database.collectionCocktails)
      ..where((tbl) => tbl.firestoreId.equals(cocktailFsId))).get();
    if (!mounted) return;

    final existingCollectionIds = existingCollections.map((e) => e.collectionId).toSet();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'ADD TO COLLECTION',
          style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              final isInCollection = existingCollectionIds.contains(collection.id);
              return ListTile(
                leading: Icon(
                  isInCollection ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isInCollection ? AppTheme.accentGold : AppTheme.textSecondary,
                ),
                title: Text(collection.name),
                subtitle: collection.description != null ? Text(collection.description!) : null,
                onTap: () async {
                  if (isInCollection) {
                    await (widget.database.delete(widget.database.collectionCocktails)
                      ..where((tbl) =>
                          tbl.collectionId.equals(collection.id) &
                          tbl.firestoreId.equals(cocktailFsId))).go();
                  } else {
                    await widget.database.into(widget.database.collectionCocktails).insert(
                      db.CollectionCocktailsCompanion.insert(
                        collectionId: collection.id,
                        firestoreId: cocktailFsId,
                      ),
                    );
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showAddToCollectionDialog();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('DONE')),
        ],
      ),
    );
  }

  Future<void> _loadIngredients() async {
    final query = widget.database.select(widget.database.cocktailIngredients).join([
      innerJoin(
        widget.database.ingredients,
        widget.database.ingredients.id
            .equalsExp(widget.database.cocktailIngredients.ingredientId),
      ),
    ])..where(widget.database.cocktailIngredients.cocktailId.equals(widget.cocktail.id));

    final results = await query.get();
    final Map<int, _CocktailIngredientWithName> uniqueIngredients = {};

    for (final row in results) {
      final cocktailIngredient = row.readTable(widget.database.cocktailIngredients);
      final ingredient = row.readTable(widget.database.ingredients);
      if (cocktailIngredient.unit == 'ml') {
        uniqueIngredients[ingredient.id] = _CocktailIngredientWithName(
          cocktailIngredient: cocktailIngredient,
          ingredientName: ingredient.name,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      ingredients = uniqueIngredients.values.toList();
      isLoading = false;
    });
  }

  String _getScaledAmount(_CocktailIngredientWithName ing) {
    final hasTextAmount = ing.cocktailIngredient.amount < 0.1 &&
        ing.cocktailIngredient.prepNote != null &&
        ing.cocktailIngredient.prepNote!.isNotEmpty;

    if (hasTextAmount) {
      final prepNote = ing.cocktailIngredient.prepNote!;
      final numericMatch = RegExp(r'[\d.]+').firstMatch(prepNote);
      if (numericMatch != null && _batchSize > 1) {
        final originalAmount = double.tryParse(numericMatch.group(0)!);
        if (originalAmount != null) {
          final scaledAmount = originalAmount * _batchSize;
          final formatted = scaledAmount % 1 == 0
              ? scaledAmount.toInt().toString()
              : scaledAmount.toStringAsFixed(1);
          return prepNote.replaceFirst(numericMatch.group(0)!, formatted);
        }
      }
      return prepNote;
    } else {
      final scaledAmount = ing.cocktailIngredient.amount * _batchSize;
      if (_useOz && ing.cocktailIngredient.unit.toLowerCase() == 'ml') {
        final ozAmount = scaledAmount * 0.033814;
        final formatted = ozAmount < 0.1 ? ozAmount.toStringAsFixed(2) : ozAmount.toStringAsFixed(1);
        return '${formatted}oz';
      }
      final formatted = scaledAmount % 1 == 0
          ? scaledAmount.toInt().toString()
          : scaledAmount.toStringAsFixed(1);
      return '$formatted${ing.cocktailIngredient.unit}';
    }
  }

  String _getTotalVolume() {
    double totalMl = 0;
    for (var ingredient in ingredients) {
      if (ingredient.cocktailIngredient.unit.toLowerCase() == 'ml') {
        totalMl += ingredient.cocktailIngredient.amount;
      }
    }
    final batchedTotal = totalMl * _batchSize;
    if (batchedTotal == 0) return '';
    if (_useOz) return '${(batchedTotal * 0.033814).toStringAsFixed(1)}oz total volume';
    if (batchedTotal >= 1000) return '${(batchedTotal / 1000).toStringAsFixed(2)}L total volume';
    return '${batchedTotal.toStringAsFixed(0)}ml total volume';
  }

  List<String> _getMethodSteps() {
    if (widget.cocktail.methodInstructions == null) return [];
    final text = widget.cocktail.methodInstructions!;
    List<String> steps = [];
    final sentences = text.split(RegExp(r'(?<=\.) (?=[A-Z])'));
    for (var sentence in sentences) {
      var cleaned = sentence.trim();
      if (cleaned.isEmpty) continue;
      if (cleaned.contains(RegExp(
          r', (shake|stir|strain|pour|add|muddle|top|garnish|serve)',
          caseSensitive: false))) {
        final parts = cleaned.split(RegExp(
            r', (?=shake|stir|strain|pour|add|muddle|top|garnish|serve)',
            caseSensitive: false));
        steps.addAll(parts.where((s) => s.trim().isNotEmpty));
      } else {
        steps.add(cleaned);
      }
    }
    return steps.map((step) {
      var s = step.trim();
      if (!s.endsWith('.') && !s.endsWith('!') && !s.endsWith('?')) s += '.';
      if (s.isNotEmpty) s = s[0].toUpperCase() + s.substring(1);
      return s;
    }).where((s) => s.length > 3).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = context.watch<AuthService>().isAdmin;
    final methodSteps = _getMethodSteps();
    final totalVolume = _getTotalVolume();
    final firestoreId = widget.cocktail.firestoreId ??
        widget.cocktail.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Image header ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            collapsedHeight: 60,
            actions: const [],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final settings =
                    context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
                final deltaExtent =
                    settings?.maxExtent ?? 280 - (settings?.minExtent ?? 60);
                (1.0 -
                        (settings?.currentExtent ??
                                280 - (settings?.minExtent ?? 60)) /
                            deltaExtent)
                    .clamp(0.0, 1.0);

                return FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                  title: Text(
                    widget.cocktail.name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_resolvedImagePath != null)
                        _resolvedImagePath!.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: _resolvedImagePath!,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorWidget: (c, u, e) =>
                                    Container(color: AppTheme.surfaceDark),
                              )
                            : Image.asset(
                                _resolvedImagePath!,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(color: AppTheme.surfaceDark),
                              )
                      else
                        Container(color: AppTheme.surfaceDark),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 150,
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
                );
              },
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Metadata + actions block ──────────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.surfaceLight)),
                  ),
                  child: Column(
                    children: [
                      // Row 1: chips + difficulty
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          children: [
                            _MetadataChip(
                              icon: Icons.local_bar,
                              label: widget.cocktail.baseSpirit,
                            ),
                            const SizedBox(width: 12),
                            _MetadataChip(
                              icon: _getMethodIcon(widget.cocktail.method),
                              label: widget.cocktail.method.toUpperCase(),
                            ),
                            const SizedBox(width: 12),
                            _MetadataChip(
                              icon: Icons.wine_bar,
                              label: widget.cocktail.glass,
                            ),
                            const Spacer(),
                            Text(
                              '★' * widget.cocktail.difficulty,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.accentGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Thin divider between rows
                      const Divider(height: 1, color: AppTheme.surfaceLight),
                      // Row 2: action buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Row(
                          children: [
                            // Favourite — wraps existing FavoriteButton widget
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FavoriteButton(
                                      database: widget.database,
                                      firestoreId: firestoreId,
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
                            // Divider
                            Container(
                              width: 1,
                              height: 28,
                              color: AppTheme.surfaceLight,
                            ),
                            // Collection
                            Expanded(
                              child: InkWell(
                                onTap: _showAddToCollectionDialog,
                                borderRadius: BorderRadius.circular(8),
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
                            // Edit — admin only
                            if (isAdmin) ...[
                              Container(
                                width: 1,
                                height: 28,
                                color: AppTheme.surfaceLight,
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: _isLoadingEdit ? null : _openEditor,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: _isLoadingEdit
                                        ? const Center(
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppTheme.accentGold,
                                              ),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.edit_outlined,
                                                  size: 20, color: AppTheme.accentGold),
                                              SizedBox(width: 6),
                                              Text(
                                                'Edit',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.accentGold,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Ingredients ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.format_list_bulleted,
                              size: 20, color: AppTheme.accentGold),
                          SizedBox(width: 8),
                          Text(
                            'INGREDIENTS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: AppTheme.accentGold,
                            ),
                          ),
                        ],
                      ),
                      if (_activeBarName.isNotEmpty && ingredients.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Builder(builder: (_) {
                            final requiredIds = _requiredIngredientIds();
                            final missing = _missingIngredients();
                            final missingCount = missing.length;
                            final allHave = requiredIds.isNotEmpty && missingCount == 0;

                            if (allHave) {
                              return Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 13, color: AppTheme.accentGold),
                                  const SizedBox(width: 6),
                                  Text(
                                    'You have everything for this ($_activeBarName) ✓',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentGold,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() =>
                                      _isMissingSectionExpanded = !_isMissingSectionExpanded),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Missing $missingCount ingredient(s) ($_activeBarName)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textSecondary.withValues(alpha: 0.9),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          _isMissingSectionExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  child: _isMissingSectionExpanded
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Column(
                                            children: missing.map((ing) {
                                              final ingredientId =
                                                  ing.cocktailIngredient.ingredientId;
                                              final inBar =
                                                  _barIngredientIds.contains(ingredientId);
                                              final isBusy =
                                                  _busyAddIngredientIds.contains(ingredientId);
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(vertical: 3),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        ing.ingredientName,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: AppTheme.textSecondary
                                                              .withValues(alpha: 0.95),
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      visualDensity: VisualDensity.compact,
                                                      splashRadius: 16,
                                                      iconSize: 16,
                                                      color: inBar
                                                          ? AppTheme.accentGold
                                                          : AppTheme.textSecondary,
                                                      icon: isBusy
                                                          ? const SizedBox(
                                                              width: 14,
                                                              height: 14,
                                                              child: CircularProgressIndicator(
                                                                  strokeWidth: 1.8),
                                                            )
                                                          : Icon(inBar
                                                              ? Icons.check_rounded
                                                              : Icons.add_rounded),
                                                      onPressed: (inBar || isBusy)
                                                          ? null
                                                          : () => _addMissingIngredientToActiveBar(
                                                              ingredientId),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            );
                          }),
                        ),
                      const SizedBox(height: 16),

                      // Batch calculator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _batchSize > 1
                                ? AppTheme.accentGold.withValues(alpha: 0.3)
                                : AppTheme.surfaceLight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Batch Size',
                                  style: TextStyle(
                                    color: AppTheme.accentGold,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      color: _batchSize > 1
                                          ? AppTheme.accentGold
                                          : AppTheme.textSecondary,
                                      onPressed: _batchSize > 1
                                          ? () => setState(() => _batchSize--)
                                          : null,
                                      iconSize: 28,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$_batchSize',
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      color: _batchSize < 99
                                          ? AppTheme.accentGold
                                          : AppTheme.textSecondary,
                                      onPressed: _batchSize < 99
                                          ? () => setState(() => _batchSize++)
                                          : null,
                                      iconSize: 28,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (totalVolume.isNotEmpty && _batchSize > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  totalVolume,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Ingredients list
                      ...ingredients.map((ing) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 100,
                                child: Text(
                                  _getScaledAmount(ing),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _batchSize > 1
                                        ? AppTheme.accentGold
                                        : AppTheme.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  ing.ingredientName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // ── Method ───────────────────────────────────────────────
                if (methodSteps.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppTheme.surfaceLight)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.restaurant, size: 20, color: AppTheme.accentGold),
                            SizedBox(width: 8),
                            Text(
                              'METHOD',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: AppTheme.accentGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...methodSteps.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentGold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                // ── Garnish ──────────────────────────────────────────────
                if (widget.cocktail.garnish != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppTheme.surfaceLight)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.eco, size: 18, color: AppTheme.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.cocktail.garnish!,
                            style: const TextStyle(
                                fontSize: 14, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── History ──────────────────────────────────────────────
                if (widget.cocktail.history != null)
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppTheme.surfaceLight)),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () =>
                              setState(() => isHistoryExpanded = !isHistoryExpanded),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.history,
                                    size: 18, color: AppTheme.textSecondary),
                                const SizedBox(width: 12),
                                const Text(
                                  'History',
                                  style: TextStyle(
                                      fontSize: 13, color: AppTheme.textSecondary),
                                ),
                                const Spacer(),
                                Icon(
                                  isHistoryExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isHistoryExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Text(
                              widget.cocktail.history!,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'shake':
        return Icons.liquor;
      case 'stir':
        return Icons.refresh;
      case 'build':
        return Icons.layers;
      default:
        return Icons.local_bar;
    }
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
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

class _CocktailIngredientWithName {
  final db.CocktailIngredient cocktailIngredient;
  final String ingredientName;

  _CocktailIngredientWithName({
    required this.cocktailIngredient,
    required this.ingredientName,
  });
}
