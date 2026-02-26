// lib/screens/cocktails_list_screen.dart
//
// Redesigned Browse tab for The Bar Bible.
// Drop-in replacement for the inline CocktailsListScreen in main.dart.
//
// WHAT CHANGED (UI only — zero business logic changes):
//   • Header: removed hard border, softer gold rule + live count
//   • Search: styled to match Finder's search row
//   • Filter/Sort: pill chips consistent with Finder
//   • Card: spirit-accented left border, depth shadow, title case name,
//     larger thumbnail, press-scale animation
//   • Empty state: on-brand icon container + sentence case copy
//
// DO NOT CHANGE: filter logic, sort logic, navigation, database calls.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/image_utils.dart';
import '../data/database.dart';
import 'cocktail_detail_screen.dart';

// ─── Spirit colour map ────────────────────────────────────────────────────────

const _kSpiritColors = <String, Color>{
  'gin':     Color(0xFF6B8FBF),
  'vodka':   Color(0xFF9B9B9B),
  'rum':     Color(0xFF8B5E3C),
  'bourbon': Color(0xFFBF8C3A),
  'whiskey': Color(0xFFBF8C3A),
  'whisky':  Color(0xFFBF8C3A),
  'tequila': Color(0xFF7A9B5A),
  'brandy':  Color(0xFFAB6B4B),
  'cognac':  Color(0xFFAB6B4B),
  'mezcal':  Color(0xFF8B7355),
  'other':   Color(0xFF8B6B9B),
};

Color _spiritColor(String spirit) {
  final key = spirit.trim().toLowerCase();
  for (final entry in _kSpiritColors.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return _kSpiritColors['other']!;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CocktailsListScreen extends StatefulWidget {
  final AppDatabase database;

  const CocktailsListScreen({super.key, required this.database});

  @override
  State<CocktailsListScreen> createState() => _CocktailsListScreenState();
}

class _CocktailsListScreenState extends State<CocktailsListScreen> {
  List<Cocktail> allCocktails = [];
  List<Cocktail> filteredCocktails = [];
  bool isLoading = true;

  // ── Filter state (unchanged logic) ──
  String searchQuery = '';
  Set<String> selectedSpirits = {};
  Set<String> selectedMethods = {};
  Set<int> selectedDifficulties = {};
  String sortBy = 'alphabetical';

  final List<String> spirits = [
    'Gin', 'Vodka', 'Rum', 'Bourbon', 'Whiskey', 'Brandy', 'Cognac', 'Other',
  ];
  final List<String> methods = ['shake', 'stir', 'build'];

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCocktails();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading (unchanged) ──────────────────────────────────────────────

  Future<void> _loadCocktails() async {
    final cocktails =
        await widget.database.select(widget.database.cocktails).get();
    setState(() {
      allCocktails = cocktails;
      filteredCocktails = cocktails;
      isLoading = false;
    });
    _applyFilters();
  }

  // ── Filter logic (unchanged) ──────────────────────────────────────────────

  void _applyFilters() {
    setState(() {
      filteredCocktails = allCocktails.where((cocktail) {
        if (searchQuery.isNotEmpty &&
            !cocktail.name
                .toLowerCase()
                .contains(searchQuery.toLowerCase())) {
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

      switch (sortBy) {
        case 'alphabetical':
          filteredCocktails.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'difficulty':
          filteredCocktails
              .sort((a, b) => a.difficulty.compareTo(b.difficulty));
          break;
      }
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      searchQuery = '';
      selectedSpirits.clear();
      selectedMethods.clear();
      selectedDifficulties.clear();
    });
    _applyFilters();
  }

  bool get hasActiveFilters =>
      selectedSpirits.isNotEmpty ||
      selectedMethods.isNotEmpty ||
      selectedDifficulties.isNotEmpty;

  int get _activeFilterCount =>
      selectedSpirits.length + selectedMethods.length + selectedDifficulties.length;

  // ── Filter sheet (same logic, restyled) ───────────────────────────────────

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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'FILTERS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: AppTheme.accentGold,
                    ),
                  ),
                  const Spacer(),
                  if (tempSpirits.isNotEmpty ||
                      tempMethods.isNotEmpty ||
                      tempDifficulties.isNotEmpty)
                    GestureDetector(
                      onTap: () => setModalState(() {
                        tempSpirits.clear();
                        tempMethods.clear();
                        tempDifficulties.clear();
                      }),
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.accentGold.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _SheetFilterSection(
                label: 'SPIRIT',
                children: spirits
                    .map((s) => _SheetChip(
                          label: s,
                          isSelected: tempSpirits.contains(s),
                          accentColor: _spiritColor(s),
                          onTap: () => setModalState(() =>
                              tempSpirits.contains(s)
                                  ? tempSpirits.remove(s)
                                  : tempSpirits.add(s)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              _SheetFilterSection(
                label: 'METHOD',
                children: methods
                    .map((m) => _SheetChip(
                          label: m[0].toUpperCase() + m.substring(1),
                          isSelected: tempMethods.contains(m),
                          onTap: () => setModalState(() =>
                              tempMethods.contains(m)
                                  ? tempMethods.remove(m)
                                  : tempMethods.add(m)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              _SheetFilterSection(
                label: 'DIFFICULTY',
                children: [1, 2, 3, 4, 5]
                    .map((d) => _SheetChip(
                          label: '★' * d,
                          isSelected: tempDifficulties.contains(d),
                          onTap: () => setModalState(() =>
                              tempDifficulties.contains(d)
                                  ? tempDifficulties.remove(d)
                                  : tempDifficulties.add(d)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedSpirits = tempSpirits;
                    selectedMethods = tempMethods;
                    selectedDifficulties = tempDifficulties;
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Apply filters',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchRow(),
            if (hasActiveFilters) _buildActivePills(),
            _buildCountRow(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'BROWSE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 13),
                child: Text(
                  'Cocktail Reference Library',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Search + filter row ───────────────────────────────────────────────────

  Widget _buildSearchRow() {
    final hasFilter = hasActiveFilters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  searchQuery = v;
                  _applyFilters();
                },
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search cocktails...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.textSecondary,
                    size: 19,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppTheme.textSecondary,
                            size: 17,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => searchQuery = '');
                            _applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter pill — matches Finder's _buildFilterButton() style
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showFiltersSheet();
            },
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: hasFilter ? AppTheme.accentGold : AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(11),
                border: hasFilter
                    ? null
                    : Border.all(
                        color: AppTheme.surfaceLight.withValues(alpha: 0.8),
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: hasFilter
                        ? AppTheme.primaryDark
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasFilter ? 'Filters ($_activeFilterCount)' : 'Filters',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasFilter
                          ? AppTheme.primaryDark
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Sort popup — matches Finder's sort popup style
          PopupMenuButton<String>(
            icon: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.8),
                ),
              ),
              child: const Icon(
                Icons.sort,
                color: AppTheme.textSecondary,
                size: 18,
              ),
            ),
            color: AppTheme.surfaceDark,
            onSelected: (v) {
              setState(() => sortBy = v);
              _applyFilters();
            },
            itemBuilder: (_) => [
              _sortMenuItem('alphabetical', 'A – Z'),
              _sortMenuItem('difficulty', 'Difficulty'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (sortBy == value)
            const Icon(Icons.check, color: AppTheme.accentGold, size: 16)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  // ── Active filter pills ───────────────────────────────────────────────────

  Widget _buildActivePills() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          ...selectedSpirits.map((s) => _ActivePill(
                label: s,
                onRemove: () {
                  setState(() => selectedSpirits.remove(s));
                  _applyFilters();
                },
              )),
          ...selectedMethods.map((m) => _ActivePill(
                label: m[0].toUpperCase() + m.substring(1),
                onRemove: () {
                  setState(() => selectedMethods.remove(m));
                  _applyFilters();
                },
              )),
          ...selectedDifficulties.map((d) => _ActivePill(
                label: '★' * d,
                onRemove: () {
                  setState(() => selectedDifficulties.remove(d));
                  _applyFilters();
                },
              )),
        ],
      ),
    );
  }

  // ── Count row ─────────────────────────────────────────────────────────────

  Widget _buildCountRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${filteredCocktails.length} '
            '${filteredCocktails.length == 1 ? 'cocktail' : 'cocktails'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
              letterSpacing: 0.4,
            ),
          ),
          if (hasActiveFilters) ...[
            const Spacer(),
            GestureDetector(
              onTap: _clearFilters,
              child: Text(
                'Clear all',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.accentGold.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    if (filteredCocktails.isEmpty) {
      return _BrowseEmptyState(
        hasFilters: hasActiveFilters,
        onClear: _clearFilters,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: filteredCocktails.length,
      itemBuilder: (context, index) {
        final cocktail = filteredCocktails[index];
        return _BrowseCocktailCard(
          cocktail: cocktail,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CocktailDetailScreen(
                  database: widget.database,
                  cocktail: cocktail,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Browse Cocktail Card ─────────────────────────────────────────────────────
//
// Key visual changes vs old _CocktailCard:
//   • 4px spirit-colored left border (instead of interior accent bar)
//   • depth shadow (instead of flat border)
//   • Title case name at 18sp w700 (instead of ALL CAPS 16sp bold)
//   • Larger thumbnail (72×72, radius 10)
//   • Spirit label demoted to muted gold subtitle
//   • Difficulty as spirit-tinted dot row (instead of star text)
//   • Press-scale animation (consistent with FinderRailTile)

class _BrowseCocktailCard extends StatefulWidget {
  final Cocktail cocktail;
  final VoidCallback onTap;

  const _BrowseCocktailCard({
    required this.cocktail,
    required this.onTap,
  });

  @override
  State<_BrowseCocktailCard> createState() => _BrowseCocktailCardState();
}

class _BrowseCocktailCardState extends State<_BrowseCocktailCard> {
  bool _pressed = false;
  String? _resolvedImagePath;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  Future<void> _resolveImage() async {
    final base = widget.cocktail.imagePath ??
        ImageUtils.generateBasePathFromName(widget.cocktail.name);
    final resolved = await ImageUtils.findCocktailImage(base);
    if (mounted) setState(() => _resolvedImagePath = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final cocktail = widget.cocktail;
    final accentColor = _spiritColor(cocktail.baseSpirit);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        scale: _pressed ? 0.982 : 1.0,
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: accentColor, width: 4),
              top: BorderSide(
                color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                width: 1,
              ),
              right: BorderSide(
                color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                width: 1,
              ),
              bottom: BorderSide(
                color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              children: [
                // Thumbnail
                _BrowseThumb(
                  cocktail: cocktail,
                  resolvedPath: _resolvedImagePath,
                ),
                const SizedBox(width: 14),
                // Text block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cocktail.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      // Spirit · Method · Glass
                      Text(
                        '${cocktail.baseSpirit}  ·  '
                        '${_capitalize(cocktail.method)}  ·  '
                        '${cocktail.glass}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary
                              .withValues(alpha: 0.85),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Difficulty dots
                      _DifficultyDots(
                        difficulty: cocktail.difficulty,
                        color: accentColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ─── Thumbnail ────────────────────────────────────────────────────────────────

class _BrowseThumb extends StatelessWidget {
  final Cocktail cocktail;
  final String? resolvedPath;
  static const double _size = 72;

  const _BrowseThumb({required this.cocktail, this.resolvedPath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: resolvedPath != null
          ? Image.asset(
              resolvedPath!,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.local_bar,
          color: AppTheme.accentGold,
          size: 24,
        ),
      );
}

// ─── Difficulty dots ──────────────────────────────────────────────────────────

class _DifficultyDots extends StatelessWidget {
  final int difficulty;
  final Color color;

  const _DifficultyDots({required this.difficulty, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < difficulty;
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

// ─── Filter sheet sub-widgets ─────────────────────────────────────────────────

class _SheetFilterSection extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _SheetFilterSection({
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
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _SheetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  const _SheetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.accentGold;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accent : AppTheme.surfaceLight,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? accent : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─── Active filter pill ───────────────────────────────────────────────────────

class _ActivePill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActivePill({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentGold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 13,
              color: AppTheme.accentGold.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _BrowseEmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;

  const _BrowseEmptyState({
    required this.hasFilters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentGold.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                Icons.local_bar_outlined,
                size: 34,
                color: AppTheme.accentGold.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilters ? 'No cocktails match' : 'No cocktails found',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your filters'
                  : 'The library appears to be empty',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.accentGold.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Clear filters',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentGold.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
