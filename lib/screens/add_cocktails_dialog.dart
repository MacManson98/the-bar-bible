import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../core/theme/app_theme.dart';
import '../data/database.dart';

// Add Cocktails Dialog with Filters
class AddCocktailsDialog extends StatefulWidget {
  final AppDatabase database;
  final Collection collection;
  final List<Cocktail> allCocktails;
  final Set<int> existingCocktailIds;
  final VoidCallback onClose;

  const AddCocktailsDialog({
    super.key,
    required this.database,
    required this.collection,
    required this.allCocktails,
    required this.existingCocktailIds,
    required this.onClose,
  });

  @override
  State<AddCocktailsDialog> createState() => _AddCocktailsDialogState();
}

class _AddCocktailsDialogState extends State<AddCocktailsDialog> {
  List<Cocktail> filteredCocktails = [];
  String searchQuery = '';
  Set<String> selectedSpirits = {};
  Set<String> selectedMethods = {};
  Set<int> selectedDifficulties = {};

  final List<String> spirits = ['Gin', 'Vodka', 'Rum', 'Bourbon', 'Whiskey', 'Brandy', 'Cognac', 'Other'];
  final List<String> methods = ['shake', 'stir', 'build'];

  @override
  void initState() {
    super.initState();
    filteredCocktails = widget.allCocktails;
  }

  void _applyFilters() {
    setState(() {
      filteredCocktails = widget.allCocktails.where((cocktail) {
        if (searchQuery.isNotEmpty &&
            !cocktail.name.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
        if (selectedSpirits.isNotEmpty && !selectedSpirits.contains(cocktail.baseSpirit)) {
          return false;
        }
        if (selectedMethods.isNotEmpty && !selectedMethods.contains(cocktail.method)) {
          return false;
        }
        if (selectedDifficulties.isNotEmpty && !selectedDifficulties.contains(cocktail.difficulty)) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _showFiltersSheet() {
    final tempSpirits = Set<String>.from(selectedSpirits);
    final tempMethods = Set<String>.from(selectedMethods);
    final tempDifficulties = Set<int>.from(selectedDifficulties);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'FILTERS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (tempSpirits.isNotEmpty || tempMethods.isNotEmpty || tempDifficulties.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempSpirits.clear();
                          tempMethods.clear();
                          tempDifficulties.clear();
                        });
                      },
                      child: const Text(
                        'CLEAR ALL',
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _FilterSection(
                label: 'SPIRIT',
                children: spirits.map((spirit) => _FilterChipMulti(
                  label: spirit,
                  isSelected: tempSpirits.contains(spirit),
                  onTap: () {
                    setModalState(() {
                      if (tempSpirits.contains(spirit)) {
                        tempSpirits.remove(spirit);
                      } else {
                        tempSpirits.add(spirit);
                      }
                    });
                  },
                )).toList(),
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'METHOD',
                children: methods.map((method) => _FilterChipMulti(
                  label: method.toUpperCase(),
                  isSelected: tempMethods.contains(method),
                  onTap: () {
                    setModalState(() {
                      if (tempMethods.contains(method)) {
                        tempMethods.remove(method);
                      } else {
                        tempMethods.add(method);
                      }
                    });
                  },
                )).toList(),
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'DIFFICULTY',
                children: [1, 2, 3, 4, 5].map((diff) => _FilterChipMulti(
                  label: '$diff★',
                  isSelected: tempDifficulties.contains(diff),
                  onTap: () {
                    setModalState(() {
                      if (tempDifficulties.contains(diff)) {
                        tempDifficulties.remove(diff);
                      } else {
                        tempDifficulties.add(diff);
                      }
                    });
                  },
                )).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedSpirits = tempSpirits;
                    selectedMethods = tempMethods;
                    selectedDifficulties = tempDifficulties;
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'APPLY FILTERS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = searchQuery.isNotEmpty ||
        selectedSpirits.isNotEmpty ||
        selectedMethods.isNotEmpty ||
        selectedDifficulties.isNotEmpty;

    return Dialog(
      backgroundColor: AppTheme.primaryDark,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.surfaceLight),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'ADD COCKTAILS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onClose();
                  },
                ),
              ],
            ),
          ),
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search cocktails...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    searchQuery = value;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _showFiltersSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasActiveFilters ? AppTheme.accentGold : AppTheme.surfaceDark,
                    foregroundColor: hasActiveFilters ? AppTheme.primaryDark : AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: hasActiveFilters ? AppTheme.accentGold : AppTheme.surfaceLight,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_list, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        hasActiveFilters
                            ? 'FILTERS (${selectedSpirits.length + selectedMethods.length + selectedDifficulties.length})'
                            : 'FILTERS',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Cocktail list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filteredCocktails.length,
              itemBuilder: (context, index) {
                final cocktail = filteredCocktails[index];
                final isInCollection = widget.existingCocktailIds.contains(cocktail.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        if (isInCollection) {
                          print('❌ Removing cocktail ${cocktail.id} from collection ${widget.collection.id}');
                          await (widget.database.delete(widget.database.collectionCocktails)
                            ..where((tbl) {
                              return tbl.collectionId.equals(widget.collection.id) &
                                  tbl.cocktailId.equals(cocktail.id);
                            })).go();
                          widget.existingCocktailIds.remove(cocktail.id);
                          print('✅ Removed successfully');
                        } else {
                          print('➕ Adding cocktail ${cocktail.id} (${cocktail.name}) to collection ${widget.collection.id}');
                          await widget.database.into(widget.database.collectionCocktails).insert(
                            CollectionCocktailsCompanion.insert(
                              collectionId: widget.collection.id,
                              cocktailId: cocktail.id,
                            ),
                          );
                          widget.existingCocktailIds.add(cocktail.id);
                          print('✅ Added successfully');
                        }
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isInCollection ? AppTheme.accentGold : AppTheme.surfaceLight,
                            width: isInCollection ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (cocktail.imagePath != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  cocktail.imagePath!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.local_bar,
                                        color: AppTheme.accentGold,
                                      ),
                                    );
                                  },
                                ),
                              )
                            else
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.local_bar,
                                  color: AppTheme.accentGold,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Container(
                              width: 4,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cocktail.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        cocktail.baseSpirit.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.accentGold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 8),
                                        width: 3,
                                        height: 3,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.textSecondary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        cocktail.method.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cocktail.glass,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isInCollection ? Icons.check_circle : Icons.circle_outlined,
                              color: isInCollection ? AppTheme.accentGold : AppTheme.textSecondary,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Done button at bottom
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.surfaceLight),
              ),
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onClose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'DONE',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _FilterSection({
    required this.label,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: AppTheme.accentGold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }
}

class _FilterChipMulti extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipMulti({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentGold : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accentGold : AppTheme.surfaceLight,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
