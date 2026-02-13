import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../core/theme/app_theme.dart';
import '../core/utils/image_utils.dart';
import '../data/database.dart';
import '../data/ingredient_data.dart';
import 'cocktail_detail_screen.dart';

enum _FinderMode { canMake, oneAway, all }

class FinderScreen extends StatefulWidget {
  final AppDatabase database;
  final VoidCallback? onNavigateToMyBar;

  const FinderScreen({
    super.key,
    required this.database,
    this.onNavigateToMyBar,
  });

  @override
  State<FinderScreen> createState() => FinderScreenState();
}

class FinderScreenState extends State<FinderScreen>
    with TickerProviderStateMixin {
  int _barCount = 0;
  List<CocktailMatch> _exactMatches = [];
  List<CocktailMatch> _missing1 = [];
  List<CocktailMatch> _missing2Plus = [];
  SavedBar? _activeBar;
  List<SavedBar> _savedBars = [];
  _FinderMode _mode = _FinderMode.canMake;
  bool _isSwitchingBar = false;

  String _searchQuery = '';
  String _spiritFilter = 'All';
  String _sortBy = 'match';
  bool _showSubstitutions = true;

  bool _isLoading = true;
  final _searchController = TextEditingController();
  final Map<int, _FinderSnapshot> _snapshotCache = {};
  final Map<int, _BarQuickStats> _barStats = {};
  bool _finderDataLoaded = false;
  List<Cocktail> _allCocktails = [];
  Map<int, Ingredient> _ingredientMap = {};
  Map<int, List<CocktailIngredient>> _cocktailIngredientsByCocktail = {};

  late AnimationController _animController;
  late Animation<double> _heroFade;
  late Animation<double> _heroScale;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _heroScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    loadBarAndMatch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> loadBarAndMatch() async {
    setState(() => _isLoading = true);
    await _ensureFinderData();

    final bars = await (widget.database.select(
      widget.database.savedBars,
    )..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
    SavedBar? activeBar = await widget.database.getDefaultSavedBar();
    activeBar ??= bars.isNotEmpty ? bars.first : null;

    final snapshot = await _snapshotForBar(activeBar);
    _sortList(snapshot.exact);
    _sortList(snapshot.missing1);
    _sortList(snapshot.missing2Plus);
    _animController.reset();

    setState(() {
      _activeBar = activeBar;
      _savedBars = bars;
      _barCount = snapshot.barIngredientCount;
      _exactMatches = snapshot.exact;
      _missing1 = snapshot.missing1;
      _missing2Plus = snapshot.missing2Plus;
      if (activeBar != null) {
        _barStats[activeBar.id] = _BarQuickStats(
          stockedCount: snapshot.barIngredientCount,
          stockedPct: _ingredientMap.isEmpty
              ? 0.0
              : (snapshot.barIngredientCount / _ingredientMap.length).clamp(
                  0.0,
                  1.0,
                ),
          canMakeCount: snapshot.exact.length,
        );
      }
      _isLoading = false;
    });

    _animController.forward();
    _prefetchBars(bars, activeBarId: activeBar?.id);
  }

  Future<void> _ensureFinderData() async {
    if (_finderDataLoaded) return;
    _allCocktails = await widget.database
        .select(widget.database.cocktails)
        .get();
    final allIngredients = await widget.database
        .select(widget.database.ingredients)
        .get();
    _ingredientMap = {for (final i in allIngredients) i.id: i};
    final allCi = await widget.database
        .select(widget.database.cocktailIngredients)
        .get();
    _cocktailIngredientsByCocktail = {};
    for (final ci in allCi) {
      _cocktailIngredientsByCocktail
          .putIfAbsent(ci.cocktailId, () => [])
          .add(ci);
    }
    _finderDataLoaded = true;
  }

  Future<_FinderSnapshot> _snapshotForBar(SavedBar? bar) async {
    final barId = bar?.id ?? -1;
    final cached = _snapshotCache[barId];
    if (cached != null) return cached;

    Set<int> barIds = {};
    if (bar != null) {
      final ingredients = await widget.database.getSavedBarIngredients(bar.id);
      barIds = ingredients.map((i) => i.id).toSet();
    }

    final barCanonicals = <String>{};
    for (final id in barIds) {
      final name = _ingredientMap[id]?.name;
      if (name != null) {
        barCanonicals.add(IngredientEquivalence.normalise(name));
      }
    }

    final barSubCanonicals = <String>{};
    if (_showSubstitutions) {
      for (final canon in barCanonicals) {
        barSubCanonicals.addAll(IngredientSubstitutions.getSubstitutes(canon));
      }
    }

    final exact = <CocktailMatch>[];
    final m1 = <CocktailMatch>[];
    final m2 = <CocktailMatch>[];

    for (final cocktail in _allCocktails) {
      final ciRows = _cocktailIngredientsByCocktail[cocktail.id] ?? const [];
      if (ciRows.isEmpty) continue;

      final requiredCanonToDisplay = <String, String>{};
      for (final ci in ciRows) {
        final name = _ingredientMap[ci.ingredientId]?.name;
        if (name == null) continue;
        final canon = IngredientEquivalence.normalise(name);
        requiredCanonToDisplay.putIfAbsent(canon, () => name);
      }
      if (requiredCanonToDisplay.isEmpty) continue;

      int matchedCount = 0;
      final missingNames = <String>[];
      final subsUsed = <String>[];

      for (final entry in requiredCanonToDisplay.entries) {
        if (barCanonicals.contains(entry.key)) {
          matchedCount++;
        } else if (_showSubstitutions && barSubCanonicals.contains(entry.key)) {
          matchedCount++;
          subsUsed.add(entry.value);
        } else {
          missingNames.add(entry.value);
        }
      }

      if (missingNames.length > 3) continue;
      final totalRequired = requiredCanonToDisplay.length;
      final match = CocktailMatch(
        cocktail: cocktail,
        totalIngredients: totalRequired,
        matchingIngredients: matchedCount,
        requiredIngredients: requiredCanonToDisplay.values.toList(),
        missingIngredients: missingNames,
        missingCount: missingNames.length,
        substitutionsUsed: subsUsed,
        matchPercentage: matchedCount / totalRequired,
      );

      if (missingNames.isEmpty) {
        exact.add(match);
      } else if (missingNames.length == 1) {
        m1.add(match);
      } else {
        m2.add(match);
      }
    }

    final snapshot = _FinderSnapshot(
      barIngredientCount: barIds.length,
      exact: exact,
      missing1: m1,
      missing2Plus: m2,
    );
    _snapshotCache[barId] = snapshot;
    return snapshot;
  }

  void _prefetchBars(List<SavedBar> bars, {int? activeBarId}) {
    for (final bar in bars) {
      if (bar.id == activeBarId) continue;
      _snapshotForBar(bar).then((snapshot) {
        if (!mounted) return;
        final stockedPct = _ingredientMap.isEmpty
            ? 0.0
            : (snapshot.barIngredientCount / _ingredientMap.length).clamp(
                0.0,
                1.0,
              );
        setState(() {
          _barStats[bar.id] = _BarQuickStats(
            stockedCount: snapshot.barIngredientCount,
            stockedPct: stockedPct,
            canMakeCount: snapshot.exact.length,
          );
        });
      });
    }
  }

  void _sortList(List<CocktailMatch> list) {
    switch (_sortBy) {
      case 'name':
        list.sort((a, b) => a.cocktail.name.compareTo(b.cocktail.name));
      case 'difficulty':
        list.sort(
          (a, b) => a.cocktail.difficulty.compareTo(b.cocktail.difficulty),
        );
      default:
        list.sort((a, b) {
          final cmp = b.matchPercentage.compareTo(a.matchPercentage);
          return cmp != 0 ? cmp : a.cocktail.name.compareTo(b.cocktail.name);
        });
    }
  }

  List<CocktailMatch> _applyFilters(List<CocktailMatch> matches) {
    return matches.where((m) {
      if (_searchQuery.isNotEmpty && !_matchesSearch(m, _searchQuery)) {
        return false;
      }
      if (_spiritFilter != 'All' &&
          m.cocktail.baseSpirit.toLowerCase() != _spiritFilter.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _matchesSearch(CocktailMatch match, String query) {
    final nq = query.toLowerCase().trim();
    if (nq.isEmpty) return true;
    final fields = [
      match.cocktail.name,
      match.cocktail.baseSpirit,
      ...match.requiredIngredients,
    ];
    return fields.any((f) => f.toLowerCase().contains(nq));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentGold),
        ),
      );
    }

    final filteredExact = _applyFilters(_exactMatches);
    final filtered1 = _applyFilters(_missing1);
    final filtered2 = _applyFilters(_missing2Plus);
    final activeName = _activeBar?.name ?? 'My Bar';
    final modeResults = _resultsForMode(filteredExact, filtered1, filtered2);

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: _activeBar == null
            ? _buildEmptyBarState()
            : Column(
                children: [
                  FadeTransition(
                    opacity: _heroFade,
                    child: ScaleTransition(
                      scale: _heroScale,
                      child: _buildHeroHeader(
                        readyCount: filteredExact.length,
                        activeBarName: activeName,
                        oneAwayCount: filtered1.length,
                        allCount:
                            filteredExact.length +
                            filtered1.length +
                            filtered2.length,
                      ),
                    ),
                  ),
                  _buildSearchRow(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Showing cocktails for "$activeName"',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Opacity(
                        key: ValueKey(
                          '${_activeBar?.id ?? -1}_${_mode.name}_$_isSwitchingBar',
                        ),
                        opacity: _isSwitchingBar ? 0.55 : 1.0,
                        child: _buildResultsForMode(modeResults),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<CocktailMatch> _resultsForMode(
    List<CocktailMatch> exact,
    List<CocktailMatch> oneAway,
    List<CocktailMatch> all,
  ) {
    switch (_mode) {
      case _FinderMode.canMake:
        return exact;
      case _FinderMode.oneAway:
        return oneAway;
      case _FinderMode.all:
        return [...exact, ...oneAway, ...all];
    }
  }

  // ── Hero Header ──
  Widget _buildHeroHeader({
    required int readyCount,
    required String activeBarName,
    required int oneAwayCount,
    required int allCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surfaceDark, Color(0xFF252218)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                label: 'Active bar selector. Currently using $activeBarName',
                button: true,
                child: InkWell(
                  onTap: _showBarSelectorSheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.surfaceLight.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Using: ',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                        Text(
                          activeBarName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.accentGold,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onNavigateToMyBar,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.surfaceLight.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.liquor,
                        color: AppTheme.accentGold,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'My Bar ($_barCount)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppTheme.accentGold.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  '$readyCount cocktails available with $activeBarName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildModeTabs(
            readyCount: readyCount,
            oneAwayCount: oneAwayCount,
            allCount: allCount,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMiniStat(
                '${_exactMatches.length}',
                'Ready',
                AppTheme.accentGold,
              ),
              _buildMiniStat(
                '${_missing1.length}',
                'One Away',
                const Color(0xFFE8A838),
              ),
              _buildMiniStat(
                '${_missing2Plus.length}',
                'Close',
                const Color(0xFF888888),
              ),
              _buildSubsToggle(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs({
    required int readyCount,
    required int oneAwayCount,
    required int allCount,
  }) {
    Widget tab(_FinderMode mode, String label, int count) {
      final selected = _mode == mode;
      return Expanded(
        child: Semantics(
          label: '$label mode, $count cocktails',
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () => setState(() => _mode = mode),
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.accentGold.withValues(alpha: 0.18)
                    : AppTheme.surfaceDark.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected
                      ? AppTheme.accentGold.withValues(alpha: 0.5)
                      : AppTheme.surfaceLight.withValues(alpha: 0.8),
                ),
              ),
              child: Text(
                '$label  $count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppTheme.accentGold
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(_FinderMode.canMake, 'Can Make', readyCount),
        const SizedBox(width: 6),
        tab(_FinderMode.oneAway, '1 Away', oneAwayCount),
        const SizedBox(width: 6),
        tab(_FinderMode.all, 'All', allCount),
      ],
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _showSubstitutions = !_showSubstitutions);
        _snapshotCache.clear();
        _barStats.clear();
        loadBarAndMatch();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _showSubstitutions
              ? AppTheme.accentGold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _showSubstitutions
                ? AppTheme.accentGold
                : AppTheme.surfaceLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_horiz,
              size: 14,
              color: _showSubstitutions
                  ? AppTheme.accentGold
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              'Subs',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _showSubstitutions
                    ? AppTheme.accentGold
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBarSelectorSheet() async {
    final totalIngredients = _ingredientMap.length;
    if (_savedBars.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SELECT BAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 10),
            ..._savedBars.map((bar) {
              final active = _activeBar?.id == bar.id;
              final stats = _barStats[bar.id];
              final stockedCount = stats?.stockedCount ?? 0;
              final stockedPct = stats?.stockedPct ?? 0.0;
              final canMake = stats?.canMakeCount ?? 0;
              final pctText = totalIngredients == 0
                  ? '0%'
                  : '${(stockedPct * 100).round()}% stocked';
              return Semantics(
                label:
                    'Use ${bar.name}, $pctText, $canMake cocktails available',
                button: true,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    await _switchActiveBar(bar);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppTheme.accentGold.withValues(alpha: 0.12)
                          : AppTheme.primaryDark.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? AppTheme.accentGold.withValues(alpha: 0.35)
                            : AppTheme.surfaceLight.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          active
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: active
                              ? AppTheme.accentGold
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bar.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? AppTheme.accentGold
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$stockedCount ingredients • $pctText • $canMake can make',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary.withValues(
                                    alpha: 0.78,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _switchActiveBar(SavedBar bar) async {
    if (_activeBar?.id == bar.id) return;

    setState(() => _isSwitchingBar = true);
    await (widget.database.update(widget.database.savedBars)
          ..where((b) => b.isDefault.equals(true)))
        .write(const SavedBarsCompanion(isDefault: Value(false)));
    await (widget.database.update(
      widget.database.savedBars,
    )..where((b) => b.id.equals(bar.id))).write(
      SavedBarsCompanion(
        isDefault: const Value(true),
        lastUsed: Value(DateTime.now()),
      ),
    );

    final snapshot = await _snapshotForBar(bar);
    _sortList(snapshot.exact);
    _sortList(snapshot.missing1);
    _sortList(snapshot.missing2Plus);

    final bars = await (widget.database.select(
      widget.database.savedBars,
    )..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
    final stockedPct = _ingredientMap.isEmpty
        ? 0.0
        : (snapshot.barIngredientCount / _ingredientMap.length).clamp(0.0, 1.0);

    if (!mounted) return;
    setState(() {
      _activeBar = bar;
      _savedBars = bars;
      _barCount = snapshot.barIngredientCount;
      _exactMatches = snapshot.exact;
      _missing1 = snapshot.missing1;
      _missing2Plus = snapshot.missing2Plus;
      _barStats[bar.id] = _BarQuickStats(
        stockedCount: snapshot.barIngredientCount,
        stockedPct: stockedPct,
        canMakeCount: snapshot.exact.length,
      );
      _isSwitchingBar = false;
      _mode = _FinderMode.canMake;
    });
    _prefetchBars(bars, activeBarId: bar.id);
  }

  // ── Search Row ──
  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search cocktails...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppTheme.textSecondary,
                            size: 16,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterButton(),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sort,
                color: AppTheme.textSecondary,
                size: 18,
              ),
            ),
            color: AppTheme.surfaceDark,
            onSelected: (v) {
              setState(() => _sortBy = v);
              _sortList(_exactMatches);
              _sortList(_missing1);
              _sortList(_missing2Plus);
              setState(() {});
            },
            itemBuilder: (_) => [
              _sortItem('match', 'Best Match'),
              _sortItem('name', 'A — Z'),
              _sortItem('difficulty', 'Difficulty'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    final hasFilter = _spiritFilter != 'All';
    return GestureDetector(
      onTap: _showSpiritFilterSheet,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasFilter ? AppTheme.accentGold : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: hasFilter ? null : Border.all(color: AppTheme.surfaceLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list,
              size: 16,
              color: hasFilter ? AppTheme.primaryDark : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              hasFilter ? _spiritFilter : 'Spirit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasFilter
                    ? AppTheme.primaryDark
                    : AppTheme.textSecondary,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _spiritFilter = 'All'),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: AppTheme.primaryDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSpiritFilterSheet() {
    final spirits = [
      'All',
      'Gin',
      'Vodka',
      'Rum',
      'Bourbon',
      'Whiskey',
      'Tequila',
      'Brandy',
      'Cognac',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FILTER BY SPIRIT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: spirits.map((s) {
                final sel = _spiritFilter == s;
                return GestureDetector(
                  onTap: () {
                    setState(() => _spiritFilter = s);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.accentGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel
                            ? AppTheme.accentGold
                            : AppTheme.surfaceLight,
                      ),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                        color: sel
                            ? AppTheme.primaryDark
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortBy == value)
            const Icon(Icons.check, color: AppTheme.accentGold, size: 16)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  // ── Empty State ──
  Widget _buildEmptyBarState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.accentGold.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.liquor,
                color: AppTheme.accentGold,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Stock Your Bar',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add the ingredients you have and Finder\nwill show what cocktails you can make.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: widget.onNavigateToMyBar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentGold.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.liquor, color: AppTheme.primaryDark, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Go to My Bar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tip: Start with a preset like "Classic Bar"\nto quickly stock common ingredients',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Results ──
  Widget _buildResultsForMode(List<CocktailMatch> matches) {
    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'No matches',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            if (_searchQuery.isNotEmpty || _spiritFilter != 'All') ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _spiritFilter = 'All';
                  });
                },
                child: const Text(
                  'Clear filters',
                  style: TextStyle(color: AppTheme.accentGold),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      children: [
        if (_mode == _FinderMode.canMake)
          _sectionHeader(
            'READY TO MAKE',
            matches.length,
            AppTheme.accentGold,
            Icons.check_circle_outline,
          ),
        if (_mode == _FinderMode.oneAway)
          _sectionHeader(
            'ONE AWAY',
            matches.length,
            const Color(0xFFE8A838),
            Icons.add_circle_outline,
          ),
        if (_mode == _FinderMode.all)
          _sectionHeader(
            'ALL MATCHES',
            matches.length,
            AppTheme.textSecondary,
            Icons.local_bar_outlined,
          ),
        ...matches.map((m) {
          final isExact = m.missingCount == 0;
          final accent = isExact
              ? AppTheme.accentGold
              : (m.missingCount == 1
                    ? const Color(0xFFE8A838)
                    : const Color(0xFF888888));
          return _cocktailCard(m, accent, isExact);
        }),
      ],
    );
  }

  Widget _sectionHeader(String title, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cocktailCard(CocktailMatch match, Color accentColor, bool isExact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CocktailDetailScreen(
                cocktail: match.cocktail,
                database: widget.database,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExact
                    ? accentColor.withValues(alpha: 0.4)
                    : AppTheme.surfaceLight,
                width: isExact ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                _CocktailThumb(cocktail: match.cocktail),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.cocktail.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isExact)
                        Row(
                          children: [
                            Text(
                              'Ready to make',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                            if (match.substitutionsUsed.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.swap_horiz,
                                size: 12,
                                color: accentColor,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'subs',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        Text(
                          'Need: ${match.missingIngredients.join(", ")}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            match.cocktail.baseSpirit,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppTheme.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            match.cocktail.method.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppTheme.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            match.cocktail.glass,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CocktailThumb extends StatefulWidget {
  final Cocktail cocktail;
  const _CocktailThumb({required this.cocktail});
  @override
  State<_CocktailThumb> createState() => _CocktailThumbState();
}

class _CocktailThumbState extends State<_CocktailThumb> {
  String? _imagePath;
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final base =
        widget.cocktail.imagePath ??
        ImageUtils.generateBasePathFromName(widget.cocktail.name);
    final resolved = await ImageUtils.findCocktailImage(base);
    if (mounted) setState(() => _imagePath = resolved);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _imagePath != null
          ? Image.asset(
              _imagePath!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.local_bar, color: AppTheme.accentGold, size: 20),
  );
}

class CocktailMatch {
  final Cocktail cocktail;
  final int totalIngredients;
  final int matchingIngredients;
  final List<String> requiredIngredients;
  final List<String> missingIngredients;
  final int missingCount;
  final List<String> substitutionsUsed;
  final double matchPercentage;

  CocktailMatch({
    required this.cocktail,
    required this.totalIngredients,
    required this.matchingIngredients,
    required this.requiredIngredients,
    required this.missingIngredients,
    required this.missingCount,
    required this.substitutionsUsed,
    required this.matchPercentage,
  });
}

class _FinderSnapshot {
  final int barIngredientCount;
  final List<CocktailMatch> exact;
  final List<CocktailMatch> missing1;
  final List<CocktailMatch> missing2Plus;

  _FinderSnapshot({
    required this.barIngredientCount,
    required this.exact,
    required this.missing1,
    required this.missing2Plus,
  });
}

class _BarQuickStats {
  final int stockedCount;
  final double stockedPct;
  final int canMakeCount;

  _BarQuickStats({
    required this.stockedCount,
    required this.stockedPct,
    required this.canMakeCount,
  });
}
