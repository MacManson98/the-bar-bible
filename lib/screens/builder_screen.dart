import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../data/database.dart';
import '../core/theme/app_theme.dart';
import '../data/ingredient_data.dart';
import 'cocktail_detail_screen.dart';

class BuilderScreen extends StatefulWidget {
  final AppDatabase database;

  const BuilderScreen({super.key, required this.database});

  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  // Selected ingredients
  Set<int> selectedIngredientIds = {};
  
  // All available ingredients
  List<Ingredient> allIngredients = [];
  List<Ingredient> filteredIngredients = [];
  
  // Matched cocktails
  List<CocktailMatch> matchedCocktails = [];
  
  // Saved bars
  List<SavedBar> savedBars = [];
  SavedBar? currentBar;
  
  // Shopping list (not using for now, but table exists)
  // List<ShoppingListEntry> shoppingList = [];
  
  // UI state
  bool isLoading = true;
  String ingredientSearchQuery = '';
  bool showIngredientDropdown = false;
  String sortBy = 'best';
  String selectedCategory = 'All';
  bool showSubstitutions = true; // Toggle for substitution feature
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadIngredients();
    await _loadSavedBars();
    await _loadDefaultBar();
    // Shopping list not implemented yet
    // await _loadShoppingList();
  }

  Future<void> _loadIngredients() async {
    final ingredients = await widget.database.select(widget.database.ingredients).get();
    setState(() {
      allIngredients = ingredients;
      filteredIngredients = ingredients;
      isLoading = false;
    });
  }

  Future<void> _loadSavedBars() async {
    final bars = await widget.database.select(widget.database.savedBars).get();
    setState(() {
      savedBars = bars;
    });
  }

  Future<void> _loadDefaultBar() async {
    // Load the default bar or the last used bar
    final defaultBar = await (widget.database.select(widget.database.savedBars)
      ..where((bar) => bar.isDefault.equals(true))
      ..limit(1)
    ).getSingleOrNull();

    if (defaultBar != null) {
      await _loadBar(defaultBar);
    }
  }

  Future<void> _loadBar(SavedBar bar) async {
    // Load ingredients from this bar
    final barIngredients = await (widget.database.select(widget.database.savedBarIngredients)
      ..where((bi) => bi.savedBarId.equals(bar.id))
    ).get();

    setState(() {
      currentBar = bar;
      selectedIngredientIds = barIngredients.map((bi) => bi.ingredientId).toSet();
    });

    await _findMatchingCocktails();
  }

  // Shopping list loading (not implemented yet)
  // Future<void> _loadShoppingList() async {
  //   final items = await widget.database.select(widget.database.shoppingList).get();
  //   setState(() {
  //     shoppingList = items;
  //   });
  // }

  Future<void> _findMatchingCocktails() async {
    if (selectedIngredientIds.isEmpty) {
      setState(() {
        matchedCocktails = [];
      });
      return;
    }

    final allCocktails = await widget.database.select(widget.database.cocktails).get();
    List<CocktailMatch> matches = [];

    for (final cocktail in allCocktails) {
      final cocktailIngredients = await (widget.database.select(widget.database.cocktailIngredients)
        ..where((ci) => ci.cocktailId.equals(cocktail.id))
      ).get();

      final requiredIngredientIds = cocktailIngredients.map((ci) => ci.ingredientId).toSet();
      Set<int> matchingIngredients = requiredIngredientIds.intersection(selectedIngredientIds);
      Set<int> missingIngredients = requiredIngredientIds.difference(selectedIngredientIds);

      // Check for substitutions if enabled
      List<String> substitutionsUsed = [];
      if (showSubstitutions && missingIngredients.isNotEmpty) {
        final selectedIngredientNames = await _getIngredientNames(selectedIngredientIds);
        final missingIngredientNames = await _getIngredientNames(missingIngredients);
        
        Set<int> substitutableMissing = {};
        for (final missingId in missingIngredients) {
          final missingIngredient = missingIngredientNames.where((i) => i.id == missingId).firstOrNull;
          if (missingIngredient == null) continue; // Skip if ingredient not found
          
          for (final selectedId in selectedIngredientIds) {
            final selectedIngredient = selectedIngredientNames.where((i) => i.id == selectedId).firstOrNull;
            if (selectedIngredient == null) continue; // Skip if ingredient not found
            
            if (IngredientSubstitutions.canSubstitute(selectedIngredient.name, missingIngredient.name)) {
              substitutableMissing.add(missingId);
              substitutionsUsed.add('${selectedIngredient.name} for ${missingIngredient.name}');
              matchingIngredients.add(selectedId);
              break;
            }
          }
        }
        
        missingIngredients = missingIngredients.difference(substitutableMissing);
      }

      final missingCount = missingIngredients.length;

      // Smart filtering logic
      final showThisCocktail = selectedIngredientIds.length == 1
          ? matchingIngredients.isNotEmpty
          : (missingCount == 0 || (missingCount <= 3 && matchingIngredients.isNotEmpty));
      
      if (showThisCocktail) {
        List<String> missingNames = [];
        if (missingIngredients.isNotEmpty) {
          final missingIngredientRecords = await (widget.database.select(widget.database.ingredients)
            ..where((i) => i.id.isIn(missingIngredients.toList()))
          ).get();
          missingNames = missingIngredientRecords.map((i) => i.name).toList();
        }

        matches.add(CocktailMatch(
          cocktail: cocktail,
          totalIngredients: requiredIngredientIds.length,
          matchingIngredients: matchingIngredients.length,
          missingIngredients: missingNames,
          missingCount: missingCount,
          substitutionsUsed: substitutionsUsed,
          matchPercentage: requiredIngredientIds.isEmpty ? 0.0 : matchingIngredients.length / requiredIngredientIds.length,
        ));
      }
    }

    _sortMatches(matches);
    setState(() {
      matchedCocktails = matches;
    });

    // Calculate unlock potential for smart suggestions
    if (matches.isNotEmpty) {
      await _calculateUnlockPotential();
    }
  }

  Future<List<Ingredient>> _getIngredientNames(Set<int> ids) async {
    return await (widget.database.select(widget.database.ingredients)
      ..where((i) => i.id.isIn(ids.toList()))
    ).get();
  }

  Future<void> _calculateUnlockPotential() async {
    // Find which ingredients would unlock the most new cocktails
    // This will be used for smart suggestions
  }

  void _sortMatches(List<CocktailMatch> matches) {
    if (sortBy == 'best') {
      matches.sort((a, b) {
        if (a.missingCount != b.missingCount) {
          return a.missingCount.compareTo(b.missingCount);
        }
        if (a.cocktail.difficulty != b.cocktail.difficulty) {
          return a.cocktail.difficulty.compareTo(b.cocktail.difficulty);
        }
        return a.cocktail.name.compareTo(b.cocktail.name);
      });
    } else {
      matches.sort((a, b) => a.cocktail.name.compareTo(b.cocktail.name));
    }
  }

  void _toggleIngredient(int ingredientId) {
    setState(() {
      if (selectedIngredientIds.contains(ingredientId)) {
        selectedIngredientIds.remove(ingredientId);
      } else {
        selectedIngredientIds.add(ingredientId);
      }
      showIngredientDropdown = false;
      ingredientSearchQuery = '';
      currentBar = null; // Mark as custom when manually edited
    });
    _findMatchingCocktails();
  }

  void _filterIngredients(String query) {
    setState(() {
      ingredientSearchQuery = query;
      if (query.isEmpty) {
        filteredIngredients = selectedCategory == 'All'
            ? allIngredients
            : allIngredients.where((i) => i.category == selectedCategory).toList();
      } else {
        final baseList = selectedCategory == 'All'
            ? allIngredients
            : allIngredients.where((i) => i.category == selectedCategory).toList();
        filteredIngredients = baseList
            .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      showIngredientDropdown = query.isNotEmpty;
    });
  }

  void _clearAll() {
    setState(() {
      selectedIngredientIds.clear();
      matchedCocktails = [];
      ingredientSearchQuery = '';
      showIngredientDropdown = false;
      currentBar = null;
    });
  }

  Future<void> _saveCurrentBar() async {
    if (selectedIngredientIds.isEmpty) return;

    final name = await _showSaveBarDialog();
    if (name == null || name.isEmpty) return;

    // Create new saved bar
    final barId = await widget.database.into(widget.database.savedBars).insert(
      SavedBarsCompanion.insert(
        name: name,
        isDefault: drift.Value(savedBars.isEmpty), // First bar is default
      ),
    );

    // Save ingredients
    for (final ingredientId in selectedIngredientIds) {
      await widget.database.into(widget.database.savedBarIngredients).insert(
        SavedBarIngredientsCompanion.insert(
          savedBarId: barId,
          ingredientId: ingredientId,
        ),
      );
    }

    await _loadSavedBars();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Saved as "$name"'),
          backgroundColor: AppTheme.accentGold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _showSaveBarDialog() async {
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Save Bar Setup', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g., Home Bar, Work - Friday',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
          onChanged: (value) => name = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, name),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold),
            child: const Text('Save', style: TextStyle(color: AppTheme.primaryDark)),
          ),
        ],
      ),
    );
  }

  void _showLoadBarDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LOAD BAR SETUP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (savedBars.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No saved bars yet.\nCreate your first setup!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ...savedBars.map((bar) => ListTile(
                leading: Icon(
                  bar.isDefault ? Icons.star : Icons.liquor,
                  color: AppTheme.accentGold,
                ),
                title: Text(bar.name, style: const TextStyle(color: AppTheme.textPrimary)),
                trailing: currentBar?.id == bar.id
                    ? const Icon(Icons.check_circle, color: AppTheme.accentGold)
                    : null,
                onTap: () {
                  _loadBar(bar);
                  Navigator.pop(context);
                },
              )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentGold),
        ),
      );
    }

    final selectedIngredients = allIngredients
        .where((i) => selectedIngredientIds.contains(i.id))
        .toList();

    final perfectMatches = matchedCocktails.where((m) => m.missingCount == 0).toList();
    final closeMatches = matchedCocktails.where((m) => m.missingCount > 0).toList();

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header with actions
            _buildHeader(),

            // Search bar
            _buildSearchBar(),

            const SizedBox(height: 12),

            // Selected ingredients or quick add section
            if (selectedIngredients.isNotEmpty)
              _buildSelectedIngredientsChips(selectedIngredients)
            else
              _buildQuickAddSection(),

            // Results header
            if (selectedIngredientIds.isNotEmpty)
              _buildResultsHeader(),

            // Results list
            Expanded(
              child: _buildResultsList(perfectMatches, closeMatches),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science, color: AppTheme.accentGold, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INGREDIENT FINDER',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (currentBar != null)
                      Text(
                        '📍 ${currentBar!.name}',
                        style: const TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              // Menu button
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.accentGold, size: 24),
                color: AppTheme.surfaceDark,
                onSelected: (value) {
                  switch (value) {
                    case 'save':
                      _saveCurrentBar();
                      break;
                    case 'load':
                      _showLoadBarDialog();
                      break;
                    case 'clear':
                      _clearAll();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (selectedIngredientIds.isNotEmpty && currentBar == null)
                    const PopupMenuItem(
                      value: 'save',
                      child: Row(
                        children: [
                          Icon(Icons.save, color: AppTheme.accentGold, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Save Bar Setup',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'load',
                    child: Row(
                      children: [
                        Icon(Icons.folder_open, color: AppTheme.accentGold, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Load Bar Setup',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  if (selectedIngredientIds.isNotEmpty)
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, color: AppTheme.textSecondary, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Clear All',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedIngredientIds.isEmpty
                      ? 'Add ingredients to see what you can make'
                      : '${matchedCocktails.length} cocktails available',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              // Substitutions toggle
              InkWell(
                onTap: () {
                  setState(() {
                    showSubstitutions = !showSubstitutions;
                  });
                  _findMatchingCocktails();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showSubstitutions ? Icons.swap_horiz : Icons.block,
                      size: 14,
                      color: showSubstitutions ? AppTheme.accentGold : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Subs',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: showSubstitutions ? AppTheme.accentGold : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            onChanged: _filterIngredients,
            onTap: () {
              setState(() {
                showIngredientDropdown = true;
              });
            },
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Add an ingredient (e.g., Amaretto)',
              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppTheme.accentGold, size: 22),
              suffixIcon: ingredientSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 20),
                      onPressed: () {
                        setState(() {
                          ingredientSearchQuery = '';
                          filteredIngredients = allIngredients;
                          showIngredientDropdown = false;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          
          // Category filtered dropdown with icons
          if (showIngredientDropdown && filteredIngredients.isNotEmpty)
            _buildCategorizedDropdown(),
        ],
      ),
    );
  }

  Widget _buildCategorizedDropdown() {
    // Group ingredients by category
    final Map<String, List<Ingredient>> grouped = {};
    for (final ingredient in filteredIngredients) {
      final category = ingredient.category;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(ingredient);
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: ListView(
        shrinkWrap: true,
        children: grouped.entries.map((entry) {
          final category = entry.key;
          final ingredients = entry.value;
          final icon = IngredientCategory.categoryIcons[category] ?? '📦';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '$icon ${category.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentGold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ...ingredients.map((ingredient) {
                final isSelected = selectedIngredientIds.contains(ingredient.id);
                return ListTile(
                  dense: true,
                  onTap: () => _toggleIngredient(ingredient.id),
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.add_circle_outline,
                    color: isSelected ? AppTheme.accentGold : AppTheme.textSecondary,
                    size: 18,
                  ),
                  title: Text(
                    ingredient.name,
                    style: TextStyle(
                      color: isSelected ? AppTheme.accentGold : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedIngredientsChips(List<Ingredient> selectedIngredients) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          top: BorderSide(color: AppTheme.surfaceLight, width: 1),
          bottom: BorderSide(color: AppTheme.surfaceLight, width: 1),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: selectedIngredients.map((ingredient) => Chip(
          label: Text(ingredient.name),
          labelStyle: const TextStyle(
            color: AppTheme.primaryDark,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: AppTheme.accentGold,
          deleteIconColor: AppTheme.primaryDark,
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () => _toggleIngredient(ingredient.id),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )).toList(),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceLight, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'RESULTS (${matchedCocktails.length})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppTheme.accentGold,
            ),
          ),
          DropdownButton<String>(
            value: sortBy,
            dropdownColor: AppTheme.surfaceDark,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
            underline: Container(),
            icon: const Icon(Icons.sort, color: AppTheme.textSecondary, size: 14),
            items: const [
              DropdownMenuItem(value: 'best', child: Text('Best Match')),
              DropdownMenuItem(value: 'alphabetical', child: Text('A-Z')),
            ],
            onChanged: (value) {
              setState(() {
                sortBy = value!;
              });
              _sortMatches(matchedCocktails);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceLight, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💡 QUICK ADD COMMON INGREDIENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showQuickAddDialog,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('SELECT MULTIPLE INGREDIENTS'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentGold,
              side: const BorderSide(color: AppTheme.accentGold, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickAddDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _QuickAddBottomSheet(
        allIngredients: allIngredients,
        selectedIngredientIds: selectedIngredientIds,
        onIngredientsSelected: (Set<int> newSelectedIds) {
          setState(() {
            selectedIngredientIds = newSelectedIds;
            currentBar = null; // Mark as custom when manually edited
          });
          _findMatchingCocktails();
        },
      ),
    );
  }

  Widget _buildResultsList(List<CocktailMatch> perfectMatches, List<CocktailMatch> closeMatches) {
    if (selectedIngredientIds.isEmpty) {
      // Empty state - just show a simple message since we have quick-add section above
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'Add ingredients above to see results',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (matchedCocktails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'No cocktails found',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try different ingredients or remove some',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (perfectMatches.isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.accentGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'YOU CAN MAKE (${perfectMatches.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.9,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...perfectMatches.map((match) => _buildCocktailMatchCard(match, true)),
          if (closeMatches.isNotEmpty) const SizedBox(height: 20),
        ],
        if (closeMatches.isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CLOSE MATCHES (${closeMatches.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.9,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...closeMatches.map((match) => _buildCocktailMatchCard(match, false)),
        ],
      ],
    );
  }

  Widget _buildCocktailMatchCard(CocktailMatch match, bool isPerfect) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPerfect ? AppTheme.accentGold : AppTheme.surfaceLight,
          width: isPerfect ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CocktailDetailScreen(
                cocktail: match.cocktail,
                database: widget.database,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status icon with match percentage
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isPerfect 
                      ? AppTheme.accentGold.withValues(alpha: 0.2) 
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPerfect ? Icons.check_circle : Icons.info_outline,
                      color: isPerfect ? AppTheme.accentGold : Colors.orange,
                      size: 18,
                    ),
                    if (!isPerfect)
                      Text(
                        '${(match.matchPercentage * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              
              // Cocktail info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.cocktail.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (isPerfect)
                      Row(
                        children: [
                          const Text(
                            'Can make now',
                            style: TextStyle(
                              color: AppTheme.accentGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (match.substitutionsUsed.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
                            const Icon(Icons.swap_horiz, size: 11, color: AppTheme.accentGold),
                            const SizedBox(width: 2),
                            const Text(
                              'Using subs',
                              style: TextStyle(
                                color: AppTheme.accentGold,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Text(
                        'Missing: ${match.missingIngredients.take(2).join(", ")}${match.missingIngredients.length > 2 ? "..." : ""}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          match.cocktail.baseSpirit,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: AppTheme.textSecondary)),
                        Text(
                          match.cocktail.glass,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '★' * match.cocktail.difficulty,
                          style: const TextStyle(
                            color: AppTheme.accentGold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow
              const Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.textSecondary,
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper class
class CocktailMatch {
  final Cocktail cocktail;
  final int totalIngredients;
  final int matchingIngredients;
  final List<String> missingIngredients;
  final int missingCount;
  final List<String> substitutionsUsed;
  final double matchPercentage;

  CocktailMatch({
    required this.cocktail,
    required this.totalIngredients,
    required this.matchingIngredients,
    required this.missingIngredients,
    required this.missingCount,
    required this.substitutionsUsed,
    required this.matchPercentage,
  });
}

// Quick Add Bottom Sheet Widget
class _QuickAddBottomSheet extends StatefulWidget {
  final List<Ingredient> allIngredients;
  final Set<int> selectedIngredientIds;
  final Function(Set<int>) onIngredientsSelected;

  const _QuickAddBottomSheet({
    required this.allIngredients,
    required this.selectedIngredientIds,
    required this.onIngredientsSelected,
  });

  @override
  State<_QuickAddBottomSheet> createState() => _QuickAddBottomSheetState();
}

class _QuickAddBottomSheetState extends State<_QuickAddBottomSheet> {
  late Set<int> tempSelectedIds;
  String searchQuery = '';
  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    tempSelectedIds = Set.from(widget.selectedIngredientIds);
  }

  List<Ingredient> get filteredIngredients {
    var ingredients = widget.allIngredients;
    
    // Filter by category
    if (selectedCategory != 'All') {
      ingredients = ingredients.where((i) => i.category == selectedCategory).toList();
    }
    
    // Filter by search query
    if (searchQuery.isNotEmpty) {
      ingredients = ingredients
          .where((i) => i.name.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
    
    return ingredients;
  }

  @override
  Widget build(BuildContext context) {
    // Group ingredients by category for the filtered list
    final Map<String, List<Ingredient>> grouped = {};
    for (final ingredient in filteredIngredients) {
      final category = ingredient.category;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(ingredient);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT INGREDIENTS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap ingredients to add or remove',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${tempSelectedIds.length} selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentGold,
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search ingredients...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.accentGold, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                          onPressed: () => setState(() => searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.primaryDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Category filter chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildCategoryChip('All', '📋'),
                  ...IngredientCategory.allCategories.map((category) {
                    final icon = IngredientCategory.categoryIcons[category] ?? '📦';
                    return _buildCategoryChip(category, icon);
                  }),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Divider
            const Divider(color: AppTheme.surfaceLight, height: 1),

            // Ingredients list
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: grouped.entries.map((entry) {
                  final category = entry.key;
                  final ingredients = entry.value;
                  final icon = IngredientCategory.categoryIcons[category] ?? '📦';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Text(
                          '$icon ${category.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentGold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ...ingredients.map((ingredient) {
                        final isSelected = tempSelectedIds.contains(ingredient.id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                tempSelectedIds.add(ingredient.id);
                              } else {
                                tempSelectedIds.remove(ingredient.id);
                              }
                            });
                          },
                          title: Text(
                            ingredient.name,
                            style: TextStyle(
                              color: isSelected ? AppTheme.accentGold : AppTheme.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          activeColor: AppTheme.accentGold,
                          checkColor: AppTheme.primaryDark,
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),

            // Bottom action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.primaryDark,
                border: Border(
                  top: BorderSide(color: AppTheme.surfaceLight, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.textSecondary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onIngredientsSelected(tempSelectedIds);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'ADD ${tempSelectedIds.length} INGREDIENT${tempSelectedIds.length != 1 ? 'S' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category, String icon) {
    final isSelected = selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$icon $category'),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedCategory = selected ? category : 'All';
          });
        },
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: AppTheme.primaryDark,
        selectedColor: AppTheme.accentGold,
        checkmarkColor: AppTheme.primaryDark,
        side: BorderSide(
          color: isSelected ? AppTheme.accentGold : AppTheme.surfaceLight,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
