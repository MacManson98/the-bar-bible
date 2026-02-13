import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart' as db;
import '../core/theme/app_theme.dart';
import '../core/utils/image_utils.dart';
import '../widgets/favorite_button.dart';

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
  int _batchSize = 1; // Batch calculator: default to single serving

  @override
  void initState() {
    super.initState();
    _loadIngredients();
    _resolveImagePath();
    _trackRecentlyViewed();
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
    // Use imagePath from database, or generate from name if not set
    final basePath = widget.cocktail.imagePath ?? 
        ImageUtils.generateBasePathFromName(widget.cocktail.name);
    
    final resolved = await ImageUtils.findCocktailImage(basePath);
    if (mounted) {
      setState(() {
        _resolvedImagePath = resolved;
      });
    }
  }

  Future<void> _showAddToCollectionDialog() async {
    final collections = await widget.database.select(widget.database.collections).get();

    if (!mounted) return;

    if (collections.isEmpty) {
      // No collections exist, prompt to create one
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('No Collections'),
          content: const Text('Create a collection first to save cocktails.'),
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

    // Check which collections already have this cocktail
    final existingCollections = await (widget.database.select(widget.database.collectionCocktails)
      ..where((tbl) => tbl.cocktailId.equals(widget.cocktail.id))
    ).get();

    final existingCollectionIds = existingCollections.map((e) => e.collectionId).toSet();

    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'ADD TO COLLECTION',
          style: TextStyle(
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
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
                    // Remove from collection
                    await (widget.database.delete(widget.database.collectionCocktails)
                      ..where((tbl) => 
                        tbl.collectionId.equals(collection.id) &
                        tbl.cocktailId.equals(widget.cocktail.id)
                      )
                    ).go();
                  } else {
                    // Add to collection
                    await widget.database.into(widget.database.collectionCocktails).insert(
                      db.CollectionCocktailsCompanion.insert(
                        collectionId: collection.id,
                        cocktailId: widget.cocktail.id,
                      ),
                    );
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showAddToCollectionDialog(); // Refresh the dialog
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadIngredients() async {
    print('🔍 Loading ingredients for cocktail ID: ${widget.cocktail.id}');
    
    final query = widget.database.select(widget.database.cocktailIngredients).join([
      innerJoin(
        widget.database.ingredients,
        widget.database.ingredients.id.equalsExp(
          widget.database.cocktailIngredients.ingredientId,
        ),
      ),
    ])..where(widget.database.cocktailIngredients.cocktailId.equals(widget.cocktail.id));

    final results = await query.get();
    print('📊 Query returned ${results.length} results');

    // Group by ingredient ID and take only ml versions (filter out oz duplicates)
    final Map<int, _CocktailIngredientWithName> uniqueIngredients = {};
    
    for (final row in results) {
      final cocktailIngredient = row.readTable(widget.database.cocktailIngredients);
      final ingredient = row.readTable(widget.database.ingredients);
      
      print('  Found: ${ingredient.name} - ${cocktailIngredient.amount}${cocktailIngredient.unit}');
      
      // Only keep ml entries (skip oz duplicates)
      if (cocktailIngredient.unit == 'ml') {
        uniqueIngredients[ingredient.id] = _CocktailIngredientWithName(
          cocktailIngredient: cocktailIngredient,
          ingredientName: ingredient.name,
        );
      }
    }
    
    print('✅ Final ingredient count: ${uniqueIngredients.length}');

    setState(() {
      ingredients = uniqueIngredients.values.toList();
      isLoading = false;
    });
  }

  // Batch calculator: Scale ingredient amount based on batch size
  String _getScaledAmount(_CocktailIngredientWithName ing) {
    // If amount is 0 or very small, use prep_note as the amount display (text-based amounts)
    final hasTextAmount = ing.cocktailIngredient.amount < 0.1 && 
                        ing.cocktailIngredient.prepNote != null && 
                        ing.cocktailIngredient.prepNote!.isNotEmpty;
    
    if (hasTextAmount) {
      // For text amounts like "4 Dashes", try to scale the number
      final prepNote = ing.cocktailIngredient.prepNote!;
      final numericMatch = RegExp(r'[\d.]+').firstMatch(prepNote);
      
      if (numericMatch != null && _batchSize > 1) {
        final originalAmount = double.tryParse(numericMatch.group(0)!);
        if (originalAmount != null) {
          final scaledAmount = originalAmount * _batchSize;
          final formattedAmount = scaledAmount % 1 == 0
              ? scaledAmount.toInt().toString()
              : scaledAmount.toStringAsFixed(1);
          
          // Replace the number in the text
          return prepNote.replaceFirst(numericMatch.group(0)!, formattedAmount);
        }
      }
      return prepNote; // Return as-is if can't scale
    } else {
      // For numeric amounts like "30ml"
      final scaledAmount = ing.cocktailIngredient.amount * _batchSize;
      final formattedAmount = scaledAmount % 1 == 0
          ? scaledAmount.toInt().toString()
          : scaledAmount.toStringAsFixed(1);
      
      return '$formattedAmount${ing.cocktailIngredient.unit}';
    }
  }

  // Batch calculator: Calculate total volume for the batch
  String _getTotalVolume() {
    double totalMl = 0;
    
    for (var ingredient in ingredients) {
      if (ingredient.cocktailIngredient.unit.toLowerCase() == 'ml') {
        totalMl += ingredient.cocktailIngredient.amount;
      }
    }
    
    final batchedTotal = totalMl * _batchSize;
    
    if (batchedTotal == 0) return '';
    
    // Show in ml or convert to liters for large batches
    if (batchedTotal >= 1000) {
      final liters = batchedTotal / 1000;
      return '${liters.toStringAsFixed(2)}L total volume';
    } else {
      return '${batchedTotal.toStringAsFixed(0)}ml total volume';
    }
  }

  List<String> _getMethodSteps() {
    if (widget.cocktail.methodInstructions == null) return [];
    
    final text = widget.cocktail.methodInstructions!;
    
    // Split by common step indicators
    List<String> steps = [];
    
    // First, try splitting by sentence boundaries
    final sentences = text.split(RegExp(r'(?<=\.) (?=[A-Z])'));
    
    for (var sentence in sentences) {
      var cleaned = sentence.trim();
      if (cleaned.isEmpty) continue;
      
      // Split on comma + verb patterns (e.g., "shake well, strain into")
      if (cleaned.contains(RegExp(r', (shake|stir|strain|pour|add|muddle|top|garnish|serve)', caseSensitive: false))) {
        final parts = cleaned.split(RegExp(r', (?=shake|stir|strain|pour|add|muddle|top|garnish|serve)', caseSensitive: false));
        steps.addAll(parts.where((s) => s.trim().isNotEmpty));
      } else {
        steps.add(cleaned);
      }
    }
    
    // Clean up and format steps
    return steps.map((step) {
      var s = step.trim();
      // Ensure it ends with a period
      if (!s.endsWith('.') && !s.endsWith('!') && !s.endsWith('?')) {
        s += '.';
      }
      // Capitalize first letter
      if (s.isNotEmpty) {
        s = s[0].toUpperCase() + s.substring(1);
      }
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

    final methodSteps = _getMethodSteps();
    final totalVolume = _getTotalVolume();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image header with fade
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            collapsedHeight: 60,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FavoriteButton(
                  database: widget.database,
                  cocktailId: widget.cocktail.id,
                  showSnackbar: true,
                  size: 26,
                ),
              ),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final settings = context
                    .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
                final deltaExtent = settings?.maxExtent ?? 280 - (settings?.minExtent ?? 60);
                (1.0 - (settings?.currentExtent ?? 280 - (settings?.minExtent ?? 60)) / deltaExtent)
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
                        Image.asset(
                          _resolvedImagePath!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: AppTheme.surfaceDark);
                          },
                        )
                      else
                        Container(color: AppTheme.surfaceDark),
                      
                      // Gradient fade - only at bottom
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
                              colors: [
                                Colors.transparent,
                                AppTheme.primaryDark,
                              ],
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

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata row
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.surfaceLight),
                    ),
                  ),
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

                // Ingredients section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.format_list_bulleted, size: 20, color: AppTheme.accentGold),
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
                      const SizedBox(height: 16),
                      
                      // BATCH CALCULATOR UI
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _batchSize > 1 ? AppTheme.accentGold.withValues(alpha: 0.3) : AppTheme.surfaceLight,
                            width: 1,
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
                                      color: _batchSize > 1 ? AppTheme.accentGold : AppTheme.textSecondary,
                                      onPressed: _batchSize > 1
                                          ? () => setState(() => _batchSize--)
                                          : null,
                                      iconSize: 28,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                                      color: _batchSize < 99 ? AppTheme.accentGold : AppTheme.textSecondary,
                                      onPressed: _batchSize < 99
                                          ? () => setState(() => _batchSize++)
                                          : null,
                                      iconSize: 28,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            
                            // Total volume indicator
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
                      
                      // Ingredients list with scaled amounts
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

                // Method section
                if (methodSteps.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppTheme.surfaceLight),
                      ),
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

                // Garnish (single line)
                if (widget.cocktail.garnish != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppTheme.surfaceLight),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.eco, size: 18, color: AppTheme.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.cocktail.garnish!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // History (collapsible)
                if (widget.cocktail.history != null)
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppTheme.surfaceLight),
                      ),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              isHistoryExpanded = !isHistoryExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.history,
                                  size: 18,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'History',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddToCollectionDialog,
        backgroundColor: AppTheme.accentGold,
        foregroundColor: AppTheme.primaryDark,
        child: const Icon(Icons.bookmark_add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({
    required this.icon,
    required this.label,
  });

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
