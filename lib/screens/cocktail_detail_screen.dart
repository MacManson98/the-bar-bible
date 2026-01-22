import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../data/database.dart' as db;
import '../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadIngredients();
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
    final query = widget.database.select(widget.database.cocktailIngredients).join([
      innerJoin(
        widget.database.ingredients,
        widget.database.ingredients.id.equalsExp(
          widget.database.cocktailIngredients.ingredientId,
        ),
      ),
    ])..where(widget.database.cocktailIngredients.cocktailId.equals(widget.cocktail.id));

    final results = await query.get();

    setState(() {
      ingredients = results.map((row) {
        final cocktailIngredient = row.readTable(widget.database.cocktailIngredients);
        final ingredient = row.readTable(widget.database.ingredients);
        return _CocktailIngredientWithName(
          cocktailIngredient: cocktailIngredient,
          ingredientName: ingredient.name,
        );
      }).toList();
      isLoading = false;
    });
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image header with fade
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            collapsedHeight: 60,
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
                      if (widget.cocktail.imagePath != null)
                        Image.asset(
                          widget.cocktail.imagePath!,
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
                      ...ingredients.map((ing) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                '${ing.cocktailIngredient.amount.toStringAsFixed(0)}${ing.cocktailIngredient.unit}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                ing.ingredientName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
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
