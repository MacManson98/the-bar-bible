import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../core/theme/app_theme.dart';
import '../data/database.dart';

// Add Cocktails Dialog with Filters
class AddCocktailsDialog extends StatefulWidget {
  final AppDatabase database;
  final Collection collection;
  final List<Cocktail> allCocktails;
  final Set<String> existingFirestoreIds;
  final VoidCallback onClose;

  const AddCocktailsDialog({
    super.key,
    required this.database,
    required this.collection,
    required this.allCocktails,
    required this.existingFirestoreIds,
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

  // Track newly selected cocktails this session (not existing ones)
  final Set<String> _pendingAdded = {};
  final Set<String> _pendingRemoved = {};

  final List<String> spirits = [
    'Gin',
    'Vodka',
    'Rum',
    'Bourbon',
    'Whiskey',
    'Brandy',
    'Cognac',
    'Other',
  ];
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
        if (selectedSpirits.isNotEmpty &&
            !selectedSpirits.contains(cocktail.baseSpirit)) {
          return false;
        }
        if (selectedMethods.isNotEmpty &&
            !selectedMethods.contains(cocktail.method)) {
          return false;
        }
        if (selectedDifficulties.isNotEmpty &&
            !selectedDifficulties.contains(cocktail.difficulty)) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  /// Count of net new additions this session
  int get _newSelectionCount => _pendingAdded.length;

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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (tempSpirits.isNotEmpty ||
                      tempMethods.isNotEmpty ||
                      tempDifficulties.isNotEmpty)
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
                children: spirits
                    .map(
                      (spirit) => _FilterChipMulti(
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
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'METHOD',
                children: methods
                    .map(
                      (method) => _FilterChipMulti(
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
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'DIFFICULTY',
                children: [1, 2, 3, 4, 5]
                    .map(
                      (diff) => _FilterChipMulti(
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
                      ),
                    )
                    .toList(),
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
    final hasActiveFilters =
        searchQuery.isNotEmpty ||
        selectedSpirits.isNotEmpty ||
        selectedMethods.isNotEmpty ||
        selectedDifficulties.isNotEmpty;

    final count = _newSelectionCount;
    final buttonLabel = count == 0
        ? 'Cancel'
        : 'Add $count Cocktail${count == 1 ? '' : 's'}';
    final buttonIsAction = count > 0;

    return Dialog(
      backgroundColor: AppTheme.primaryDark,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.accentGold.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add to ${widget.collection.name}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${filteredCocktails.length} cocktails',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onClose();
                  },
                ),
              ],
            ),
          ),

          // ── Search + Filter bar ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.surfaceLight.withValues(alpha: 0.8),
                      ),
                    ),
                    child: TextField(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search cocktails…',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 17,
                          color: AppTheme.textSecondary,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        searchQuery = value;
                        _applyFilters();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _showFiltersSheet,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: hasActiveFilters
                          ? AppTheme.accentGold.withValues(alpha: 0.15)
                          : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasActiveFilters
                            ? AppTheme.accentGold.withValues(alpha: 0.6)
                            : AppTheme.surfaceLight.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 16,
                          color: hasActiveFilters
                              ? AppTheme.accentGold
                              : AppTheme.textSecondary,
                        ),
                        if (hasActiveFilters) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${selectedSpirits.length + selectedMethods.length + selectedDifficulties.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentGold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Cocktail list ────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: filteredCocktails.length,
              itemBuilder: (context, index) {
                final cocktail = filteredCocktails[index];
                final cocktailFsId = cocktail.firestoreId ?? cocktail.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
                final isInCollection = widget.existingFirestoreIds.contains(
                  cocktailFsId,
                );

                return _PickerRow(
                  cocktail: cocktail,
                  isInCollection: isInCollection,
                  onTap: () async {
                    if (isInCollection) {
                      await (widget.database.delete(
                            widget.database.collectionCocktails,
                          )..where((tbl) {
                            return tbl.collectionId.equals(
                                  widget.collection.id,
                                ) &
                                tbl.firestoreId.equals(cocktailFsId);
                          }))
                          .go();
                      widget.existingFirestoreIds.remove(cocktailFsId);
                      _pendingAdded.remove(cocktailFsId);
                      _pendingRemoved.add(cocktailFsId);
                    } else {
                      await widget.database
                          .into(widget.database.collectionCocktails)
                          .insert(
                            CollectionCocktailsCompanion.insert(
                              collectionId: widget.collection.id,
                              firestoreId: cocktailFsId,
                            ),
                          );
                      widget.existingFirestoreIds.add(cocktailFsId);
                      _pendingAdded.add(cocktailFsId);
                      _pendingRemoved.remove(cocktailFsId);
                    }
                    setState(() {});
                  },
                );
              },
            ),
          ),

          // ── Dynamic bottom action ────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              border: Border(
                top: BorderSide(
                  color: AppTheme.accentGold.withValues(alpha: 0.14),
                ),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: SizedBox(
                key: ValueKey(buttonIsAction),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onClose();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonIsAction
                        ? AppTheme.accentGold
                        : AppTheme.surfaceDark,
                    foregroundColor: buttonIsAction
                        ? AppTheme.primaryDark
                        : AppTheme.textSecondary,
                    elevation: buttonIsAction ? 2 : 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: buttonIsAction
                          ? BorderSide.none
                          : BorderSide(
                              color: AppTheme.surfaceLight.withValues(
                                alpha: 0.6,
                              ),
                            ),
                    ),
                  ),
                  child: Text(
                    buttonLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: buttonIsAction
                          ? AppTheme.primaryDark
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Picker Row ─────────────────────────────────────────────────────────────────
// Compact, picker-friendly variant of VaultCocktailRow with premium selection state
class _PickerRow extends StatelessWidget {
  final Cocktail cocktail;
  final bool isInCollection;
  final VoidCallback onTap;

  const _PickerRow({
    required this.cocktail,
    required this.isInCollection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      cocktail.baseSpirit,
      cocktail.method,
    ].where((v) => v.trim().isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isInCollection
              ? AppTheme.accentGold.withValues(alpha: 0.06)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isInCollection
                ? AppTheme.accentGold.withValues(alpha: 0.55)
                : AppTheme.surfaceLight.withValues(alpha: 0.55),
            width: isInCollection ? 1.5 : 1.0,
          ),
          boxShadow: isInCollection
              ? [
                  BoxShadow(
                    color: AppTheme.accentGold.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Gold accent bar (matches VaultCocktailRow)
            Container(
              width: 3,
              height: 44,
              decoration: BoxDecoration(
                color: isInCollection
                    ? AppTheme.accentGold
                    : AppTheme.accentGold.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cocktail.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isInCollection
                          ? AppTheme.textPrimary
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isInCollection
                            ? AppTheme.accentGold.withValues(alpha: 0.75)
                            : AppTheme.textSecondary,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Premium selection badge
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: isInCollection
                  ? Container(
                      key: const ValueKey('checked'),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGold.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: AppTheme.primaryDark,
                      ),
                    )
                  : Container(
                      key: const ValueKey('unchecked'),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.surfaceLight,
                          width: 1.5,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter helpers ─────────────────────────────────────────────────────────────

class _FilterSection extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _FilterSection({required this.label, required this.children});

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
        Wrap(spacing: 8, runSpacing: 8, children: children),
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
