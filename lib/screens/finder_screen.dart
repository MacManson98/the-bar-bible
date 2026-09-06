// ignore_for_file: unused_element, prefer_final_fields

import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import '../core/services/bar_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/bar_create_diagnostics.dart';
import '../core/utils/image_utils.dart';
import '../data/database.dart';
import '../data/flavor_data.dart';
import '../data/ingredient_data.dart';
import '../widgets/bar_selector_dropdown.dart';
import '../services/auth_service.dart';
import '../services/user_sync_service.dart';
import 'cocktail_detail_screen.dart';
import 'paywall_screen.dart';

enum _FinderMode { canMake, oneAway, all }

enum _FinderViewMode { tiles, list }

class FinderScreen extends StatefulWidget {
  final AppDatabase database;
  final ValueChanged<int>? onBarSwitched;
  final VoidCallback? onNavigateToMyBar;
  /// null = show all, 'cocktail' | 'shot' | 'mocktail' to restrict this instance.
  final String? categoryFilter;

  const FinderScreen({
    super.key,
    required this.database,
    this.onBarSwitched,
    this.onNavigateToMyBar,
    this.categoryFilter,
  });

  @override
  State<FinderScreen> createState() => FinderScreenState();
}

class FinderScreenState extends State<FinderScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  static const int _railPreviewLimit = 10;
  static const int _smallTilesThreshold = 12;
  static const double _railTileHeight = 220;

  int _barCount = 0;
  List<CocktailMatch> _exactMatches = [];
  List<CocktailMatch> _missing1 = [];
  List<CocktailMatch> _missing2Plus = [];
  SavedBar? _activeBar;
  List<SavedBar> _savedBars = [];
  _FinderMode _mode = _FinderMode.canMake;
  _FinderViewMode _viewMode = _FinderViewMode.tiles;
  String? _activeRailId;
  String? _activeRailTitle;
  bool Function(CocktailMatch m)? _activeRailPredicate;
  // _isSwitchingBar removed â€” bar switching now handled by shell pill

  String _searchQuery = '';
  String _spiritFilter = 'All';
  final Set<String> _flavorFilters = {};
  String _sortBy = 'match';
  bool _isFilterSheetOpen = false;
  bool _isRailTransitioning = false;
  bool _isCreatingBar = false;
  BarCreateDiagnosticsFlow? _createDiagnostics;
  bool _deferredBarRefreshScheduled = false;
  SavedBar? _pendingDeferredRefreshBar;
  List<SavedBar> _pendingDeferredRefreshBars = const [];
  BarCreateDiagnosticsFlow? _pendingDeferredRefreshDiagnostics;
  DateTime? _lastImeSensitiveEventAt;
  Timer? _searchDebounceTimer;

  bool _isLoading = true;
  late final BarService _barService;
  final _searchController = TextEditingController();
  final _resultsScrollController = ScrollController();
  final Map<int, _FinderSnapshot> _snapshotCache = {};
  final Map<int, _BarQuickStats> _barStats = {};
  bool _finderDataLoaded = false;
  List<Cocktail> _allCocktails = [];
  Map<int, Ingredient> _ingredientMap = {};
  Map<int, List<CocktailIngredient>> _cocktailIngredientsByCocktail = {};
  Map<int, _CocktailMeta> _cocktailMetaById = {};

  // Derived/cached view data. Rebuilt only when source data or filters change.
  List<CocktailMatch> _filteredExactCache = const [];
  List<CocktailMatch> _filteredMissing1Cache = const [];
  List<CocktailMatch> _filteredMissing2PlusCache = const [];
  List<CocktailMatch> _modeResultsCache = const [];
  List<_RailSectionData> _cachedTileSections = const [];

  late AnimationController _animController;
  late Animation<double> _heroFade;
  late Animation<double> _heroScale;

  @override
  void initState() {
    super.initState();
    _barService = BarService(widget.database);
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
    _finishCreateDiagnostics(result: 'disposed');
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _resultsScrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _delayForImeSettleIfNeeded() async {
    final last = _lastImeSensitiveEventAt;
    if (last == null) return;
    const settleWindow = Duration(milliseconds: 220);
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= settleWindow) return;
    final wait = settleWindow - elapsed;
    if (kDebugMode) {
      debugPrint('Finder IME settle delay ${wait.inMilliseconds}ms');
    }
    await Future.delayed(wait);
  }

  String _nextAutoBarName(List<SavedBar> bars) {
    final names = bars.map((b) => b.name.trim().toLowerCase()).toSet();
    const base = 'new bar';
    if (!names.contains(base)) return 'New Bar';
    var index = 2;
    while (names.contains('$base $index')) {
      index++;
    }
    return 'New Bar $index';
  }

  Future<void> _pushBarsToCloud() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    final synced = await UserSyncService(widget.database).pushBars(uid);
    if (!synced && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t sync to cloud — will retry later')),
      );
    }
  }

  void _markCreateSetState(String reason) {
    _createDiagnostics?.incrementSetState(reason);
  }

  void _finishCreateDiagnostics({required String result}) {
    _createDiagnostics?.finish(result: result);
    _createDiagnostics = null;
  }

  void _setSearchQueryDebounced(String value) {
    _searchDebounceTimer?.cancel();
    if (value.isEmpty) {
      if (_searchQuery.isEmpty) return;
      setState(() {
        _searchQuery = '';
        _refreshDerivedCaches();
      });
      return;
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || value == _searchQuery) return;
      setState(() {
        _searchQuery = value;
        _refreshDerivedCaches();
      });
    });
  }

  Future<void> loadBarAndMatch() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Clear cached snapshots so we recompute from DB truth.
    // Ingredients may have changed in My Bar since last visit.
    _snapshotCache.clear();
    _barStats.clear();

    await _ensureFinderData();

    final bars = await (widget.database.select(
      widget.database.savedBars,
    )..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
    SavedBar? activeBar = await widget.database.getDefaultSavedBar();
    activeBar = _resolvePreferredBar(activeBar, bars);

    final snapshot = await _snapshotForBar(activeBar);
    _sortList(snapshot.exact);
    _sortList(snapshot.missing1);
    _sortList(snapshot.missing2Plus);
    if (!mounted) return;
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
      _refreshDerivedCaches();
      _isLoading = false;
    });

    _animController.forward();
    _prefetchBars(bars, activeBarId: activeBar?.id);
  }

  SavedBar? _resolvePreferredBar(SavedBar? activeBar, List<SavedBar> bars) {
    if (bars.isEmpty) return null;
    if (activeBar != null) return activeBar;
    for (final bar in bars) {
      if (bar.name.trim().toLowerCase() == 'my bar') return bar;
    }
    return bars.first;
  }

  Future<void> _ensureFinderData() async {
    if (_finderDataLoaded) return;
    _allCocktails = await widget.database
        .select(widget.database.cocktails)
        .get();
    // All cocktails load — premium ones are shown with a lock badge for free users
    if (widget.categoryFilter != null) {
      _allCocktails = _allCocktails
          .where((c) => c.category == widget.categoryFilter)
          .toList();
    }
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
    _cocktailMetaById = {for (final c in _allCocktails) c.id: _metaFor(c)};
    _finderDataLoaded = true;
  }

  Future<_FinderSnapshot> _snapshotForBar(SavedBar? bar) async {
    _createDiagnostics?.incrementCounter(
      '_snapshotForBar',
      stackTrace: StackTrace.current,
    );
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
    for (final canon in barCanonicals) {
      barSubCanonicals.addAll(IngredientSubstitutions.getSubstitutes(canon));
    }

    final exact = <CocktailMatch>[];
    final m1 = <CocktailMatch>[];
    final m2 = <CocktailMatch>[];

    var processed = 0;
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
        } else if (barSubCanonicals.contains(entry.key)) {
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

      processed++;
      if (processed % 120 == 0) {
        // Yield periodically so heavy snapshot builds do not block animation
        // frames (IME/show-hide and create transitions).
        await Future<void>.delayed(Duration.zero);
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
      case 'name_desc':
        list.sort((a, b) => b.cocktail.name.compareTo(a.cocktail.name));
      case 'difficulty':
        list.sort((a, b) => a.cocktail.difficulty.compareTo(b.cocktail.difficulty));
      case 'difficulty_desc':
        list.sort((a, b) => b.cocktail.difficulty.compareTo(a.cocktail.difficulty));
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
      if (_flavorFilters.isNotEmpty) {
        final meta = _cocktailMetaById[m.cocktail.id];
        if (meta == null) return false;
        final matchesAny = _flavorFilters.any((label) {
          final chip = kFlavorChips.firstWhere(
            (c) => c.label == label,
            orElse: () => FlavorChip(label: label, aliases: {label}),
          );
          return _hasTasteTag(meta, chip.aliases);
        });
        if (!matchesAny) return false;
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
    super.build(context);
    if (_isLoading) {
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
        child: _activeBar == null
            ? _buildEmptyBarState()
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _heroFade,
                      child: ScaleTransition(
                        scale: _heroScale,
                        child: _buildHeroHeader(
                          readyCount: _filteredExactCache.length,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 6)),
                ],
                body: Column(
                  children: [
                    _buildSearchRow(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide =
                              Tween<Offset>(
                                begin: const Offset(0.02, 0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              );
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(position: slide, child: child),
                          );
                        },
                        child: Opacity(
                          key: ValueKey(
                            '${_activeBar?.id ?? -1}_$_searchQuery$_spiritFilter${_flavorFilters.join(',')}',
                          ),
                          opacity: 1.0,
                          child: _buildResultsForMode(_modeResultsCache),
                        ),
                      ),
                    ),
                  ],
                ),
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

  void _refreshDerivedCaches() {
    _createDiagnostics?.incrementCounter(
      '_refreshDerivedCaches',
      stackTrace: StackTrace.current,
    );
    _filteredExactCache = _applyFilters(_exactMatches);
    _filteredMissing1Cache = _applyFilters(_missing1);
    _filteredMissing2PlusCache = _applyFilters(_missing2Plus);
    _modeResultsCache = _resultsForMode(
      _filteredExactCache,
      _filteredMissing1Cache,
      _filteredMissing2PlusCache,
    );
    // Always compute so curated picks are available regardless of mode.
    _cachedTileSections = _computeTileSections(_filteredExactCache);
  }

  List<_RailSectionData> _computeTileSections(List<CocktailMatch> matches) {
    final rails = _buildFinderRails(matches);
    if (rails.isEmpty) return const [];

    final isSmallTilesMode = matches.length < _smallTilesThreshold;
    final sections = <_RailSectionData>[];
    final usedIds = <int>{};

    if (isSmallTilesMode) {
      _FinderRailBucket? startHere;
      for (final rail in rails) {
        if (rail.id == 'start_here') {
          startHere = rail;
          break;
        }
      }
      if (startHere != null) {
        final startAvailable = startHere.matches
            .where((m) => !usedIds.contains(m.cocktail.id))
            .toList();
        final startPreview = startAvailable
            .take(_railPreviewLimit)
            .toList();
        if (startPreview.isNotEmpty) {
          usedIds.addAll(startPreview.map((m) => m.cocktail.id));
          sections.add(
            _RailSectionData(
              rail: startHere,
              railAvailable: startAvailable,
              preview: startPreview,
              minPreviewToRender: 1,
            ),
          );
        }
      }
      for (final rail in rails) {
        if (rail.id == 'start_here') continue;
        final railAvailable = rail.matches
            .where((m) => !usedIds.contains(m.cocktail.id))
            .toList();
        final preview = railAvailable.take(_railPreviewLimit).toList();
        if (preview.length < 2) continue;
        usedIds.addAll(preview.map((m) => m.cocktail.id));
        sections.add(
          _RailSectionData(
            rail: rail,
            railAvailable: railAvailable,
            preview: preview,
            minPreviewToRender: 2,
          ),
        );
      }
    } else {
      for (final rail in rails) {
        final railAvailable = rail.matches
            .where((m) => !usedIds.contains(m.cocktail.id))
            .toList();
        final preview = railAvailable.take(_railPreviewLimit).toList();
        if (preview.length < 2) continue;
        usedIds.addAll(preview.map((m) => m.cocktail.id));
        sections.add(
          _RailSectionData(
            rail: rail,
            railAvailable: railAvailable,
            preview: preview,
            minPreviewToRender: 2,
          ),
        );
      }

      // Fallback: allow duplicates to preserve rail count.
      if (sections.length < 7) {
        sections.clear();
        for (final rail in rails) {
          final railAvailable = List<CocktailMatch>.from(rail.matches);
          final preview = railAvailable.take(_railPreviewLimit).toList();
          if (preview.length < 2) continue;
          sections.add(
            _RailSectionData(
              rail: rail,
              railAvailable: railAvailable,
              preview: preview,
              minPreviewToRender: 2,
            ),
          );
        }
      }
    }

    final allMakeableSection = _allMakeableSectionData(matches);
    if (allMakeableSection != null) {
      sections.add(allMakeableSection);
    }
    return sections;
  }

  _RailSectionData? _allMakeableSectionData(List<CocktailMatch> matches) {
    if (matches.isEmpty) return null;
    final uniqueById = <int, CocktailMatch>{};
    for (final m in matches) {
      uniqueById[m.cocktail.id] = m;
    }
    final allUnique = uniqueById.values.toList()
      ..sort((a, b) => a.cocktail.name.compareTo(b.cocktail.name));
    final preview = allUnique.take(_railPreviewLimit).toList();
    if (preview.isEmpty) return null;
    final rail = _FinderRailBucket(
      id: 'all_makeable',
      title: 'All Makeable (${allUnique.length})',
      family: _RailFamily.hybrid,
      count: allUnique.length,
      matches: allUnique,
      score: 1000,
    );
    return _RailSectionData(
      rail: rail,
      railAvailable: allUnique,
      preview: preview,
      minPreviewToRender: 1,
    );
  }

  // â”€â”€ Hero Header â”€â”€
  Widget _buildHeroHeader({required int readyCount}) {
    final categoryLabel = widget.categoryFilter == 'mocktail'
        ? 'mocktails'
        : widget.categoryFilter == 'shot'
            ? 'shots'
            : 'cocktails';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surfaceDark.withValues(alpha: 0.98),
            const Color(0xFF222017),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 2,
            width: double.infinity,
            color: AppTheme.accentGold.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 14),
          BarSelectorDropdown(
            currentBarName: _activeBar?.name ?? 'My Bar',
            currentBarId: _activeBar?.id,
            bars: _savedBars,
            maxWidth: 320,
            isCreateInProgress: _isCreatingBar,
            onSelectBar: (barId) async {
              if (barId == _activeBar?.id) return;
              SavedBar? selectedBar;
              for (final bar in _savedBars) {
                if (bar.id == barId) {
                  selectedBar = bar;
                  break;
                }
              }
              if (selectedBar == null) return;
              await _switchActiveBar(selectedBar, allBars: _savedBars);
            },
            onCreateBar: () async {
              await _createNewBar();
            },
            onClearBar: () async {
              await _clearCurrentBarWithConfirm();
            },
            onDeleteBar: (bar) async {
              await _deleteBarWithConfirm(bar);
            },
          ),
          const SizedBox(height: 14),
          Text(
            '$readyCount',
            style: const TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w800,
              color: AppTheme.accentGold,
              height: 1.0,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$categoryLabel you can make right now',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                onChanged: _setSearchQueryDebounced,
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
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppTheme.textSecondary,
                            size: 17,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _setSearchQueryDebounced('');
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
          _buildFilterButton(),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Container(
              width: 38,
              height: 38,
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
              setState(() {
                _sortBy = v;
                _sortList(_exactMatches);
                _sortList(_missing1);
                _sortList(_missing2Plus);
                _refreshDerivedCaches();
              });
            },
            itemBuilder: (_) => [
              _sortItem('match', 'Best Match'),
              _sortItem('name', 'A \u2013 Z'),
              _sortItem('name_desc', 'Z \u2013 A'),
              _sortItem('difficulty', 'Difficulty \u2191'),
              _sortItem('difficulty_desc', 'Difficulty \u2193'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    final activeCount =
        (_spiritFilter != 'All' ? 1 : 0) + _flavorFilters.length;
    final hasFilter = activeCount > 0;
    return GestureDetector(
      onTap: _showFilterSheet,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasFilter ? AppTheme.accentGold : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(11),
          border: hasFilter
              ? null
              : Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.8)),
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
              hasFilter ? 'Filters ($activeCount)' : 'Filters',
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
                onTap: () => setState(() {
                  _spiritFilter = 'All';
                  _flavorFilters.clear();
                  _refreshDerivedCaches();
                }),
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

  Future<List<SavedBar>> _loadBarsOrdered() {
    return (widget.database.select(
      widget.database.savedBars,
    )..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
  }

  Future<void> _setDefaultBar(int barId) async {
    await _barService.setDefaultBar(barId);
  }

  void _applyActiveBarSnapshot(
    SavedBar bar,
    _FinderSnapshot snapshot, {
    required List<SavedBar> allBars,
    bool prefetch = true,
  }) {
    final stockedPct = _ingredientMap.isEmpty
        ? 0.0
        : (snapshot.barIngredientCount / _ingredientMap.length).clamp(0.0, 1.0);

    if (!mounted) return;
    _markCreateSetState('_applyActiveBarSnapshot');
    setState(() {
      _activeBar = bar;
      _savedBars = List<SavedBar>.from(allBars)
        ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      _barCount = snapshot.barIngredientCount;
      _exactMatches = snapshot.exact;
      _missing1 = snapshot.missing1;
      _missing2Plus = snapshot.missing2Plus;
      _activeRailId = null;
      _activeRailTitle = null;
      _activeRailPredicate = null;
      _viewMode = _FinderViewMode.tiles;
      _barStats[bar.id] = _BarQuickStats(
        stockedCount: snapshot.barIngredientCount,
        stockedPct: stockedPct,
        canMakeCount: snapshot.exact.length,
      );
      _refreshDerivedCaches();
    });

    widget.onBarSwitched?.call(bar.id);
    if (prefetch) {
      _prefetchBars(allBars, activeBarId: bar.id);
    }
  }

  void _scheduleDeferredBarRefresh(
    SavedBar bar, {
    required List<SavedBar> allBars,
    BarCreateDiagnosticsFlow? diagnostics,
  }) {
    _pendingDeferredRefreshBar = bar;
    _pendingDeferredRefreshBars = allBars;
    _pendingDeferredRefreshDiagnostics = diagnostics;
    if (_deferredBarRefreshScheduled) return;
    _deferredBarRefreshScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _deferredBarRefreshScheduled = false;
      final refreshBar = _pendingDeferredRefreshBar;
      final refreshBars = _pendingDeferredRefreshBars;
      final flow = _pendingDeferredRefreshDiagnostics;
      _pendingDeferredRefreshBar = null;
      _pendingDeferredRefreshBars = const [];
      _pendingDeferredRefreshDiagnostics = null;
      if (!mounted || refreshBar == null) {
        flow?.finish(result: 'aborted');
        if (identical(_createDiagnostics, flow)) {
          _createDiagnostics = null;
        }
        return;
      }

      final sw = Stopwatch()..start();
      try {
        flow?.step('phaseB:postFrameStart');
        await _delayForImeSettleIfNeeded();
        flow?.step('phaseB:imeSettleDone');
        final snapshot = await _snapshotForBar(refreshBar);
        flow?.step('phaseB:snapshotForBarDone');
        _sortList(snapshot.exact);
        _sortList(snapshot.missing1);
        _sortList(snapshot.missing2Plus);
        flow?.step('phaseB:sortDone');
        _applyActiveBarSnapshot(
          refreshBar,
          snapshot,
          allBars: refreshBars,
          prefetch: false,
        );
        flow?.step('phaseB:applySnapshotDone');
        Future<void>.delayed(const Duration(milliseconds: 280), () {
          if (!mounted || _activeBar?.id != refreshBar.id) return;
          _prefetchBars(refreshBars, activeBarId: refreshBar.id);
        });
        flow?.step('phaseB:prefetchDeferred');
      } finally {
        flow?.step('phaseB:finally');
        if (kDebugMode) {
          debugPrint(
            'Finder create Phase B (deferred hydration) ${sw.elapsedMilliseconds}ms',
          );
        }
        if (mounted) {
          _markCreateSetState('phaseB:complete');
          setState(() => _isCreatingBar = false);
        }
        _finishCreateDiagnostics(result: 'completed');
      }
    });
  }

  Future<void> _createNewBar() async {
    if (_isCreatingBar) return;
    final flow = BarCreateDiagnosticsFlow.start('Finder');
    _createDiagnostics = flow;
    flow.step('tapHandler');
    if (mounted) {
      _markCreateSetState('create:start');
      setState(() => _isCreatingBar = true);
    }
    final phaseASw = Stopwatch()..start();
    try {
      final now = DateTime.now();
      final trimmedName = _nextAutoBarName(_savedBars);
      flow.step('phaseA:autoName:$trimmedName');
      final newBarId = await widget.database
          .into(widget.database.savedBars)
          .insert(
            SavedBarsCompanion.insert(
              name: trimmedName,
              isDefault: const Value(true),
              lastUsed: Value(now),
            ),
          );
      flow.step('phaseA:insertBar');
      await _setDefaultBar(newBarId);
      flow.step('phaseA:setDefaultBar');
      final bars = await _loadBarsOrdered();
      flow.step('phaseA:loadBarsOrdered');
      if (!mounted) {
        _finishCreateDiagnostics(result: 'unmounted');
        return;
      }

      SavedBar? selectedBar;
      for (final bar in bars) {
        if (bar.id == newBarId) {
          selectedBar = bar;
          break;
        }
      }
      selectedBar ??= SavedBar(
        id: newBarId,
        name: trimmedName,
        isDefault: true,
        createdAt: now,
        lastUsed: now,
      );
      final SavedBar createdBar = selectedBar;

      _markCreateSetState('phaseA:optimisticUi');
      setState(() {
        _savedBars = bars;
        _activeBar = createdBar;
        _barCount = 0;
        _exactMatches = [];
        _missing1 = [];
        _missing2Plus = [];
        _activeRailId = null;
        _activeRailTitle = null;
        _activeRailPredicate = null;
        _viewMode = _FinderViewMode.tiles;
        _refreshDerivedCaches();
      });
      flow.step('phaseA:setStateDone');

      if (kDebugMode) {
        debugPrint(
          'Finder create Phase A (immediate UI) ${phaseASw.elapsedMilliseconds}ms',
        );
      }

      _scheduleDeferredBarRefresh(createdBar, allBars: bars, diagnostics: flow);
      flow.step('phaseA:scheduleDeferredHydration');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "${createdBar.name}"'),
            action: SnackBarAction(
              label: 'Rename',
              onPressed: () {
                _showRenameBarDialog(createdBar);
              },
            ),
          ),
        );
        _pushBarsToCloud();
      }
    } catch (_) {
      flow.step('error');
      if (!mounted) {
        _finishCreateDiagnostics(result: 'unmounted_error');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create bar. Please try again.'),
        ),
      );
      _markCreateSetState('create:error');
      setState(() => _isCreatingBar = false);
      _finishCreateDiagnostics(result: 'error');
    }
  }

  Future<void> _showRenameBarDialog(SavedBar bar) async {
    final renamed = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameBarDialog(initialName: bar.name),
    );
    if (!mounted || renamed == null || renamed.trim().isEmpty) return;

    final name = renamed.trim();
    await (widget.database.update(widget.database.savedBars)
          ..where((b) => b.id.equals(bar.id)))
        .write(SavedBarsCompanion(name: Value(name)));
    final bars = await _loadBarsOrdered();
    if (!mounted) return;
    _markCreateSetState('rename:setState');
    setState(() {
      _savedBars = bars;
      if (_activeBar?.id == bar.id) {
        _activeBar = _activeBar!.copyWith(name: name);
      }
    });
    widget.onBarSwitched?.call(bar.id);
    _pushBarsToCloud();
  }

  Future<void> _clearCurrentBarWithConfirm() async {
    if (_activeBar == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Clear Current Bar',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Remove all ingredients from "${_activeBar!.name}"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: TextStyle(color: Colors.red.shade300)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _activeBar == null) return;

    await (widget.database.delete(
      widget.database.savedBarIngredients,
    )..where((bi) => bi.savedBarId.equals(_activeBar!.id))).go();

    if (!mounted) return;
    await loadBarAndMatch();
  }

  Future<void> _deleteBarWithConfirm(SavedBar bar) async {
    if (_savedBars.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need at least one bar.')),
      );
      return;
    }

    final deletingActive = _activeBar?.id == bar.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Delete Bar',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          deletingActive
              ? 'Delete "${bar.name}"? This is your active bar, so another bar will be selected automatically.'
              : 'Delete "${bar.name}" and all of its ingredients?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red.shade300),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await (widget.database.delete(
      widget.database.savedBarIngredients,
    )..where((row) => row.savedBarId.equals(bar.id))).go();

    await (widget.database.delete(
      widget.database.savedBars,
    )..where((row) => row.id.equals(bar.id))).go();

    var remainingBars = await _loadBarsOrdered();
    if (remainingBars.isEmpty || !mounted) return;

    final activeBarStillExists =
        _activeBar != null && remainingBars.any((b) => b.id == _activeBar!.id);
    final hasDefault = remainingBars.any((b) => b.isDefault);

    if (deletingActive || !activeBarStillExists || !hasDefault) {
      await _setDefaultBar(remainingBars.first.id);
      remainingBars = await _loadBarsOrdered();
    }

    if (!mounted || remainingBars.isEmpty) return;

    if (deletingActive || !activeBarStillExists) {
      final nextActive = remainingBars.first;
      final snapshot = await _snapshotForBar(nextActive);
      _sortList(snapshot.exact);
      _sortList(snapshot.missing1);
      _sortList(snapshot.missing2Plus);
      _applyActiveBarSnapshot(nextActive, snapshot, allBars: remainingBars);
      return;
    }

    _markCreateSetState('delete:refreshBarsOnly');
    setState(() {
      _savedBars = remainingBars;
      _refreshDerivedCaches();
    });

    final activeId = _activeBar?.id;
    if (activeId != null) {
      widget.onBarSwitched?.call(activeId);
    }
  }

  Future<void> _switchActiveBar(
    SavedBar bar, {
    required List<SavedBar> allBars,
  }) async {
    _createDiagnostics?.incrementCounter(
      '_switchActiveBar',
      stackTrace: StackTrace.current,
    );
    if (_activeBar?.id == bar.id) return;

    await _setDefaultBar(bar.id);
    final latestBars = await _loadBarsOrdered();
    final barsForUi = latestBars.isEmpty ? allBars : latestBars;

    final snapshot = await _snapshotForBar(bar);
    _sortList(snapshot.exact);
    _sortList(snapshot.missing1);
    _sortList(snapshot.missing2Plus);
    _applyActiveBarSnapshot(bar, snapshot, allBars: barsForUi);
    // mounted guard is inside _applyActiveBarSnapshot
  }

  void _showFilterSheet() {
    if (_isFilterSheetOpen) return;
    _isFilterSheetOpen = true;

    const spirits = ['All', 'Gin', 'Vodka', 'Rum', 'Bourbon', 'Whiskey', 'Tequila', 'Brandy', 'Cognac'];

    String tempSpirit = _spiritFilter;
    final tempFlavors = Set<String>.from(_flavorFilters);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) {
          final anyActive = tempSpirit != 'All' || tempFlavors.isNotEmpty;
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(
              24, 20, 24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                    if (anyActive)
                      GestureDetector(
                        onTap: () => setModal(() {
                          tempSpirit = 'All';
                          tempFlavors.clear();
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

                // Spirit section
                Text(
                  'SPIRIT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: spirits.map((s) {
                    final sel = tempSpirit == s;
                    return GestureDetector(
                      onTap: () => setModal(() => tempSpirit = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.accentGold.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? AppTheme.accentGold : AppTheme.surfaceLight,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? AppTheme.accentGold : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Flavor section
                Text(
                  'FLAVOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kFlavorChips.map((chip) {
                    final sel = tempFlavors.contains(chip.label);
                    return GestureDetector(
                      onTap: () => setModal(() {
                        if (sel) {
                          tempFlavors.remove(chip.label);
                        } else {
                          tempFlavors.add(chip.label);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.accentGold.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? AppTheme.accentGold : AppTheme.surfaceLight,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          chip.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? AppTheme.accentGold : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                // Apply button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _spiritFilter = tempSpirit;
                      _flavorFilters
                        ..clear()
                        ..addAll(tempFlavors);
                      _refreshDerivedCaches();
                    });
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
          );
        },
      ),
    ).whenComplete(() => _isFilterSheetOpen = false);
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

  // â”€â”€ Empty State â”€â”€
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
              'Add the ingredients you have to see\nwhat cocktails you can make.',
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

  // â”€â”€ Results â”€â”€
  Widget _buildResultsForMode(List<CocktailMatch> matches) {
    if (_barCount == 0) {
      return _buildFinderPurposeEmptyState();
    }
    final canMake = _filteredExactCache;

    if (canMake.isEmpty && _searchQuery.isEmpty && _spiritFilter == 'All' && _flavorFilters.isEmpty) {
      return _buildFinderPurposeEmptyState();
    }

    if (canMake.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48,
                color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('No matches',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _spiritFilter = 'All';
                  _flavorFilters.clear();
                  _refreshDerivedCaches();
                });
              },
              child: const Text('Clear filters',
                  style: TextStyle(color: AppTheme.accentGold)),
            ),
          ],
        ),
      );
    }

    final curatedSection = _cachedTileSections.isNotEmpty
        ? _cachedTileSections.firstWhere(
            (s) => s.rail.id == 'start_here',
            orElse: () => _cachedTileSections.first,
          )
        : null;
    final curatedMatches = curatedSection?.preview ?? const [];
    final bestUnlock = _computeBestUnlock();
    final allItems = _buildMainListItems(canMake, curatedMatches, bestUnlock);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: 0.025),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        itemCount: allItems.length,
        itemBuilder: (context, index) => allItems[index],
      ),
    );
  }

  List<Widget> _buildMainListItems(
    List<CocktailMatch> canMake,
    List<CocktailMatch> curatedMatches,
    _BestUnlock? bestUnlock,
  ) {
    final items = <Widget>[];

    if (curatedMatches.isNotEmpty) {
      final rail = _cachedTileSections
          .firstWhere((s) => s.rail.id == 'start_here',
              orElse: () => _cachedTileSections.first)
          .rail;
      items.add(_buildCuratedSection(curatedMatches, rail.title));
    }

    items.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'All ${canMake.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5a4a28),
                letterSpacing: 1.0,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _refreshDerivedCaches();
                  });
                },
                child: const Text('Clear',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentGold,
                    )),
              ),
          ],
        ),
      ),
    );

    for (final m in canMake) {
      items.add(_cocktailCard(m, AppTheme.accentGold, true));
    }

    if (bestUnlock != null) items.add(_buildBestUnlockCard(bestUnlock));

    // 1-away section inline
    if (_filteredMissing1Cache.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: AppTheme.surfaceLight,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '1 AWAY  ·  ${_filteredMissing1Cache.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: const Color(0xFFE8A838).withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppTheme.surfaceLight,
                ),
              ),
            ],
          ),
        ),
      );
      for (final m in _filteredMissing1Cache) {
        items.add(_cocktailCard(m, const Color(0xFFE8A838), false));
      }
    }

    items.add(const SizedBox(height: 8));
    return items;
  }

  Widget _buildCuratedSection(List<CocktailMatch> picks, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.isEmpty ? 'Picks for now' : title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentGold,
                  letterSpacing: 1.0,
                ),
              ),
              const Text(
                'Refreshes daily',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3a3020),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: picks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _FinderRailTile(
              match: picks[i],
              database: widget.database,
              width: 138,
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  _BestUnlock? _computeBestUnlock() {
    if (_filteredMissing1Cache.isEmpty) return null;
    final counts = <String, int>{};
    for (final m in _filteredMissing1Cache) {
      if (m.missingIngredients.isEmpty) continue;
      final ing = m.missingIngredients.first;
      counts[ing] = (counts[ing] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    String? best;
    int bestCount = 0;
    counts.forEach((ing, count) {
      if (count > bestCount) { bestCount = count; best = ing; }
    });
    if (best == null || bestCount < 2) return null;
    return _BestUnlock(ingredientName: best!, unlockCount: bestCount);
  }

  Widget _buildBestUnlockCard(_BestUnlock unlock) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.12),
                border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_open_rounded, color: AppTheme.accentGold, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BEST UNLOCK',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Color(0xFF5a4a28), letterSpacing: 0.8,
                      )),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: 'Add ${unlock.ingredientName}',
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppTheme.accentGold,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  unlocks ${unlock.unlockCount} more',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onNavigateToMyBar,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text('+ Add',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOneAwayNudge(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GestureDetector(
        onTap: () => _showOneAwaySheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1 AWAY',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppTheme.accentGold.withValues(alpha: 0.85), letterSpacing: 0.8,
                        )),
                    const SizedBox(height: 2),
                    Text('$count cocktails just out of reach',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary.withValues(alpha: 0.85),
                        )),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.accentGold, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showOneAwaySheet() {
    final items = List<CocktailMatch>.from(_filteredMissing1Cache)
      ..sort((a, b) => a.cocktail.name.compareTo(b.cocktail.name));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1 INGREDIENT AWAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentGold.withValues(alpha: 0.85),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} cocktail${items.length == 1 ? '' : 's'} within reach',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add one more ingredient to unlock these',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.surfaceLight),
                // List
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final m = items[index];
                      final missing = m.missingIngredients.isNotEmpty
                          ? m.missingIngredients.first
                          : 'Unknown';
                      final isLocked = m.cocktail.isPremium &&
                          !context.read<AuthService>().isEffectivelyPremium;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            if (isLocked) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PaywallScreen()),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CocktailDetailScreen(
                                  cocktail: m.cocktail,
                                  database: widget.database,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.surfaceLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    _CocktailThumb(
                                        cocktail: m.cocktail, size: 52),
                                    if (isLocked)
                                      Positioned(
                                        right: 0, bottom: 0,
                                        child: Container(
                                          width: 16, height: 16,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryDark,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Icon(Icons.lock,
                                              size: 10,
                                              color: AppTheme.accentGold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              m.cocktail.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: isLocked
                                                    ? AppTheme.textSecondary
                                                    : AppTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (isLocked)
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 5,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.accentGold
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: AppTheme.accentGold
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: const Text('PRO',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: AppTheme.accentGold,
                                                  )),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      // Missing ingredient pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8A838)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          border: Border.all(
                                            color: const Color(0xFFE8A838)
                                                .withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.add_circle_outline,
                                              size: 11,
                                              color: Color(0xFFE8A838),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              missing,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFE8A838),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isLocked
                                      ? Icons.lock_outline
                                      : Icons.chevron_right,
                                  color: isLocked
                                      ? AppTheme.accentGold
                                          .withValues(alpha: 0.5)
                                      : AppTheme.textSecondary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildListResults(List<CocktailMatch> matches) {
    final filtered =
        (_mode == _FinderMode.canMake &&
            _activeRailPredicate != null &&
            _viewMode == _FinderViewMode.list)
        ? matches.where((m) => _activeRailPredicate!(m)).toList()
        : matches;
    final showRailFilterHeader =
        _mode == _FinderMode.canMake &&
        _activeRailId != null &&
        _activeRailTitle != null &&
        _viewMode == _FinderViewMode.list;
    final list = ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 100),
      itemCount: filtered.length + (showRailFilterHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (showRailFilterHeader && index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.accentGold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Filtered: $_activeRailTitle',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentGold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeRailId = null;
                            _activeRailTitle = null;
                            _activeRailPredicate = null;
                            _viewMode = _FinderViewMode.tiles;
                            _refreshDerivedCaches();
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: AppTheme.accentGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final dataIndex = index - (showRailFilterHeader ? 1 : 0);
        final m = filtered[dataIndex];
        final isExact = m.missingCount == 0;
        final accent = isExact
            ? AppTheme.accentGold
            : (m.missingCount == 1
                  ? const Color(0xFFE8A838)
                  : const Color(0xFF888888));
        return _cocktailCard(m, accent, isExact);
      },
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _mode == _FinderMode.canMake
            ? AppTheme.accentGold.withValues(alpha: 0.035)
            : Colors.transparent,
      ),
      child: list,
    );
  }

  Widget _buildRailSection({
    required _FinderRailBucket rail,
    required List<CocktailMatch> railAvailable,
    required List<CocktailMatch> preview,
    int minPreviewToRender = 3,
  }) {
    if (preview.length < minPreviewToRender) {
      return const SizedBox.shrink();
    }
    final availableCount = railAvailable.length;
    final shownCount = preview.length;
    final canSeeAll = availableCount > shownCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rail.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (canSeeAll)
                  GestureDetector(
                    onTap: () {
                      if (_isRailTransitioning) return;
                      _isRailTransitioning = true;
                      final ids = railAvailable
                          .map((m) => m.cocktail.id)
                          .toSet();
                      setState(() {
                        _viewMode = _FinderViewMode.list;
                        _activeRailId = rail.id;
                        _activeRailTitle = rail.title;
                        _activeRailPredicate = (m) =>
                            ids.contains(m.cocktail.id);
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_resultsScrollController.hasClients) return;
                        _resultsScrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      });
                      Future<void>.delayed(
                        const Duration(milliseconds: 250),
                      ).then((_) {
                        _isRailTransitioning = false;
                      });
                    },
                    child: Text(
                      'See all ($availableCount)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentGold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: _railTileHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: preview.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _FinderRailTile(
                match: preview[i],
                database: widget.database,
                width: 138,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_FinderRailBucket> _buildFinderRails(List<CocktailMatch> matches) {
    if (matches.isEmpty) return const [];
    final total = matches.length;
    int minLow;
    int minHigh;
    if (total <= 20) {
      minLow = 2;
      minHigh = 3;
    } else if (total <= 60) {
      minLow = 2;
      minHigh = 4;
    } else {
      minLow = 4;
      minHigh = 6;
    }

    final byId = {for (final m in matches) m.cocktail.id: m};
    final metas = <int, _CocktailMeta>{};
    for (final m in matches) {
      final meta = _cocktailMetaById[m.cocktail.id];
      if (meta != null) {
        metas[m.cocktail.id] = meta;
      }
    }

    final today = DateTime.now();
    final barId = _activeBar?.id ?? -1;
    final seed = _stableSeed(
      '${today.year}-${today.month}-${today.day}-$barId',
    );
    final startHere = _buildStartHereRail(
      matches: matches,
      metas: metas,
      random: Random(seed),
    );

    final candidates = <_FinderRailBucket>[];
    for (final def in _railDefinitions) {
      final effectiveMin = def.family == _RailFamily.taste
          ? def.minCount
          : def.minCount.clamp(minLow, minHigh);
      var accepted = <CocktailMatch>[];
      for (final m in matches) {
        final meta = metas[m.cocktail.id];
        if (meta != null && def.predicate(m.cocktail, meta)) {
          accepted.add(m);
        }
      }
      if (accepted.length < effectiveMin && total >= 2) {
        accepted = _fallbackRailMatches(def.id, matches, metas);
      }
      if (accepted.length < effectiveMin) continue;
      accepted.sort((a, b) => a.cocktail.name.compareTo(b.cocktail.name));
      final score =
          accepted.length +
          (def.family == _RailFamily.taste ? 0.9 : 0.0) +
          (def.family == _RailFamily.hybrid ? 0.35 : 0.0) +
          (def.family == _RailFamily.spirit ? 0.18 : 0.0) +
          (def.family == _RailFamily.method ? 0.12 : 0.0);
      candidates.add(
        _FinderRailBucket(
          id: def.id,
          title: def.title,
          family: def.family,
          count: accepted.length,
          matches: accepted,
          score: score,
        ),
      );
    }

    candidates.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final familyOrder = <_RailFamily, int>{
        _RailFamily.taste: 0,
        _RailFamily.method: 1,
        _RailFamily.difficulty: 2,
        _RailFamily.glass: 3,
        _RailFamily.spirit: 4,
        _RailFamily.hybrid: 5,
      };
      final fa = familyOrder[a.family] ?? 99;
      final fb = familyOrder[b.family] ?? 99;
      final fc = fa.compareTo(fb);
      return fc != 0 ? fc : a.title.compareTo(b.title);
    });

    final caps = <_RailFamily, int>{
      _RailFamily.taste: 8,
      _RailFamily.spirit: 2,
      _RailFamily.method: 2,
      _RailFamily.glass: 1,
      _RailFamily.difficulty: 1,
      _RailFamily.hybrid: 2,
    };

    final selected = <_FinderRailBucket>[];
    final familyCounts = <_RailFamily, int>{};
    final target = total < 12
        ? 6
        : total <= 20
        ? 7
        : total <= 35
        ? 8
        : total <= 60
        ? 10
        : 10; // + Start Here => typically 8-10 rails for 20-60

    for (final c in candidates) {
      if (selected.length >= target) break;
      var current = familyCounts[c.family] ?? 0;
      final cap = caps[c.family] ?? 99;
      if (current >= cap) continue;
      final conflicts = selected
          .where((s) => _railOverlapRatio(s, c) > 0.88)
          .toList();
      if (conflicts.isNotEmpty) {
        final replaceable = conflicts.firstWhere(
          (s) =>
              c.family == _RailFamily.taste &&
              (s.family == _RailFamily.spirit ||
                  s.family == _RailFamily.method),
          orElse: () => const _FinderRailBucket(
            id: '',
            title: '',
            family: _RailFamily.hybrid,
            count: 0,
            matches: [],
            score: 0,
          ),
        );
        if (replaceable.id.isNotEmpty) {
          selected.removeWhere((s) => s.id == replaceable.id);
          final prevCount = familyCounts[replaceable.family] ?? 0;
          if (prevCount > 0) {
            familyCounts[replaceable.family] = prevCount - 1;
          }
          current = familyCounts[c.family] ?? 0;
        } else {
          continue;
        }
      }
      selected.add(c);
      familyCounts[c.family] = current + 1;
    }
    if (selected.length < target) {
      for (final c in candidates) {
        if (selected.length >= target) break;
        if (selected.any((s) => s.id == c.id)) continue;
        selected.add(c);
      }
    }

    final rails = <_FinderRailBucket>[];
    if (startHere.matches.isNotEmpty) {
      rails.add(startHere);
    }
    rails.addAll(selected);

    // Ensure references are still from current filtered set.
    return rails
        .map(
          (r) => _FinderRailBucket(
            id: r.id,
            title: r.title,
            family: r.family,
            count: r.matches.length,
            matches: r.matches
                .where((m) => byId.containsKey(m.cocktail.id))
                .toList(),
            score: r.score,
          ),
        )
        .where((r) => r.matches.isNotEmpty)
        .toList();
  }

  List<CocktailMatch> _fallbackRailMatches(
    String railId,
    List<CocktailMatch> matches,
    Map<int, _CocktailMeta> metas,
  ) {
    final fallback = <CocktailMatch>[];
    for (final m in matches) {
      final meta = metas[m.cocktail.id];
      if (meta == null) continue;
      var include = false;
      switch (railId) {
        case 'smooth_balanced':
          include = meta.difficulty <= 3 || meta.method == 'build';
          break;
        case 'bold_spirit_forward':
          include = meta.method == 'stir' || meta.difficulty >= 3;
          break;
        case 'bright_fresh':
          include =
              _hasTasteTag(meta, const {'citrus', 'refreshing', 'fresh'}) ||
              meta.method == 'shake';
          break;
        case 'rich_decadent':
          include =
              _hasTasteTag(meta, const {
                'sweet',
                'creamy',
                'dessert',
                'rich',
              }) ||
              meta.difficulty >= 3;
          break;
        case 'after_hours':
          include =
              _hasTasteTag(meta, const {
                'bitter',
                'herbal',
                'smoky',
                'spiced',
              }) ||
              (meta.method == 'stir' && meta.difficulty >= 2);
          break;
      }
      if (include) fallback.add(m);
    }
    if (fallback.length < 2) {
      return matches
          .take(min(_railPreviewLimit, matches.length))
          .toList();
    }
    return fallback;
  }

  double _railOverlapRatio(_FinderRailBucket a, _FinderRailBucket b) {
    if (a.matches.isEmpty || b.matches.isEmpty) return 0.0;
    final aIds = a.matches.map((m) => m.cocktail.id).toSet();
    final bIds = b.matches.map((m) => m.cocktail.id).toSet();
    final intersection = aIds.intersection(bIds).length;
    final base = min(aIds.length, bIds.length);
    if (base == 0) return 0.0;
    return intersection / base;
  }

  // ── Time-aware picks ──────────────────────────────────────────────────────

  _TimeBand _currentTimeBand() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return _TimeBand.morning;
    if (hour >= 12 && hour < 18) return _TimeBand.afternoon;
    if (hour >= 18 && hour < 21) return _TimeBand.earlyEvening;
    if (hour >= 21) return _TimeBand.lateEvening;
    return _TimeBand.lateNight;
  }

  _FinderRailBucket _buildStartHereRail({
    required List<CocktailMatch> matches,
    required Map<int, _CocktailMeta> metas,
    required Random random,
  }) {
    if (matches.length < 5) {
      return const _FinderRailBucket(
        id: 'start_here',
        title: '',
        family: _RailFamily.hybrid,
        count: 0,
        matches: [],
        score: 999.0,
      );
    }

    final band = _currentTimeBand();
    final config = _bandConfigs[band]!;

    // Score every makeable cocktail against the current time band.
    final scored = <_ScoredMatch>[];
    for (final m in matches) {
      final meta = metas[m.cocktail.id];
      if (meta == null) continue;

      double score = random.nextDouble() * 0.03; // stable daily jitter

      for (final tag in config.priorityTags) {
        if (_hasTasteTag(meta, {tag})) score += 3.0;
      }
      for (final tag in config.excludeTags) {
        if (_hasTasteTag(meta, {tag})) score -= 2.0;
      }
      if (config.preferredMethods.contains(meta.method)) score += 1.0;
      if (meta.difficulty > config.maxDifficulty) score -= 1.0;

      scored.add(_ScoredMatch(m, score));
    }

    // Sort by score descending.
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Pick top 6 with diversity guard (max 2 same spirit, max 2 same method).
    final selected = <CocktailMatch>[];
    final usedSpirit = <String, int>{};
    final usedMethod = <String, int>{};

    for (final entry in scored) {
      if (selected.length >= 6) break;
      final m = entry.match;
      final meta = metas[m.cocktail.id]!;
      if ((usedSpirit[meta.spirit] ?? 0) >= 2) continue;
      if ((usedMethod[meta.method] ?? 0) >= 2) continue;
      selected.add(m);
      usedSpirit[meta.spirit] = (usedSpirit[meta.spirit] ?? 0) + 1;
      usedMethod[meta.method] = (usedMethod[meta.method] ?? 0) + 1;
    }

    // If diversity filter was too aggressive, top up from remaining scored list.
    if (selected.length < 3) {
      final selectedIds = selected.map((m) => m.cocktail.id).toSet();
      for (final entry in scored) {
        if (selected.length >= 6) break;
        final m = entry.match;
        if (!selectedIds.contains(m.cocktail.id)) {
          selected.add(m);
          selectedIds.add(m.cocktail.id);
        }
      }
    }

    final label = _bandConfigs[band]!.label;

    return _FinderRailBucket(
      id: 'start_here',
      title: label,
      family: _RailFamily.hybrid,
      count: selected.length,
      matches: selected,
      score: 999.0,
    );
  }


  _CocktailMeta _metaFor(Cocktail c) => _CocktailMeta(
    spirit: _normalizeSpirit(c.baseSpirit),
    method: _normalizeMethod(c.method),
    glass: _normalizeGlass(c.glass),
    difficulty: c.difficulty,
    tags: _parseTags(c.tags),
  );

  String _normalizeMethod(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('shake')) return 'shake';
    if (v.contains('stir')) return 'stir';
    if (v.contains('build')) return 'build';
    if (v.contains('blend') || v.contains('frozen')) return 'blend';
    return v;
  }

  String _normalizeSpirit(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('whiskey') || v.contains('whisky')) return 'whiskey';
    if (v.contains('bourbon')) return 'bourbon';
    if (v.contains('gin')) return 'gin';
    if (v.contains('rum')) return 'rum';
    if (v.contains('vodka')) return 'vodka';
    if (v.contains('tequila')) return 'tequila';
    if (v.contains('brandy')) return 'brandy';
    if (v.contains('cognac')) return 'cognac';
    return v;
  }

  String _normalizeGlass(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('old fashioned') || v.contains('rocks')) return 'rocks';
    if (v.contains('highball') || v.contains('collins')) return 'highball';
    if (v.contains('coupe')) return 'coupe';
    if (v.contains('martini')) return 'martini';
    if (v.contains('nick') || v.contains('nora')) return 'nick_nora';
    return v;
  }

  Set<String> _parseTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <String>{};
    final trimmed = raw.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .map((e) => e.trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toSet();
        }
      } catch (_) {}
    }
    return trimmed
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  String _normalizeTagToken(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\s]+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')
        .replaceAll(RegExp(r'-+'), '-');
  }

  bool _hasTasteTag(_CocktailMeta meta, Set<String> aliases) {
    final normalizedTags = meta.tags.map(_normalizeTagToken).toSet();
    final normalizedAliases = aliases.map(_normalizeTagToken).toSet();
    for (final alias in normalizedAliases) {
      if (alias.isEmpty) continue;
      if (normalizedTags.contains(alias)) return true;
      if (normalizedTags.any(
        (t) => (t.contains(alias) || alias.contains(t)) && t.length >= 5,
      )) {
        return true;
      }
    }
    return false;
  }

  int _stableSeed(String input) {
    var hash = 0;
    for (final code in input.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return hash;
  }

  List<_FinderRailDefinition> get _railDefinitions => [
    _FinderRailDefinition(
      id: 'smooth_balanced',
      title: 'Smooth & Balanced',
      family: _RailFamily.taste,
      minCount: 2,
      predicate: (_, m) =>
          _hasTasteTag(m, const {'smooth', 'balanced', 'velvety', 'round'}),
    ),
    _FinderRailDefinition(
      id: 'bold_spirit_forward',
      title: 'Bold & Spirit-Forward',
      family: _RailFamily.taste,
      minCount: 2,
      predicate: (_, m) => _hasTasteTag(m, const {
        'boozy',
        'spirit-forward',
        'spirit forward',
        'strong',
      }),
    ),
    _FinderRailDefinition(
      id: 'bright_fresh',
      title: 'Bright & Fresh',
      family: _RailFamily.taste,
      minCount: 2,
      predicate: (_, m) => _hasTasteTag(m, const {
        'citrus',
        'refreshing',
        'fresh',
        'tart',
        'floral',
      }),
    ),
    _FinderRailDefinition(
      id: 'rich_decadent',
      title: 'Rich & Decadent',
      family: _RailFamily.taste,
      minCount: 2,
      predicate: (_, m) => _hasTasteTag(m, const {
        'sweet',
        'creamy',
        'rich',
        'decadent',
        'dessert',
      }),
    ),
    _FinderRailDefinition(
      id: 'after_hours',
      title: 'After Hours',
      family: _RailFamily.taste,
      minCount: 2,
      predicate: (_, m) => _hasTasteTag(m, const {
        'bitter',
        'smoky',
        'herbal',
        'spiced',
        'boozy',
      }),
    ),
  ];

  Widget _buildFinderPurposeEmptyState() {
    final barName = _activeBar?.name ?? 'My Bar';
    final categoryLabel = widget.categoryFilter == 'mocktail'
        ? 'mocktails'
        : widget.categoryFilter == 'shot'
            ? 'shots'
            : 'cocktails';
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentGold.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: AppTheme.accentGold,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Showing $categoryLabel you can make\nwith "$barName".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add ingredients to your bar and this tab will instantly list $categoryLabel that match your inventory.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary.withValues(alpha: 0.82),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Semantics(
              button: true,
              label: 'Go to My Bar to add ingredients',
              child: GestureDetector(
                onTap: widget.onNavigateToMyBar,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.liquor, color: AppTheme.primaryDark, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Add Ingredients in My Bar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryDark,
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
    );
  }

  Widget _cocktailCard(CocktailMatch match, Color accentColor, bool isExact) {
    final isPremium = match.cocktail.isPremium;
    final isLocked = isPremium && !context.read<AuthService>().isEffectivelyPremium;
    final showReadyStatus = isExact && _mode != _FinderMode.canMake;
    final isCanMakeMode = _mode == _FinderMode.canMake;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLocked) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PaywallScreen()));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CocktailDetailScreen(
                  cocktail: match.cocktail,
                  database: widget.database,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLocked
                    ? AppTheme.surfaceLight
                    : isCanMakeMode
                        ? AppTheme.accentGold.withValues(alpha: 0.22)
                        : (isExact
                              ? accentColor.withValues(alpha: 0.4)
                              : AppTheme.surfaceLight),
                width: isCanMakeMode ? 1.0 : (isExact ? 1.5 : 1),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    _CocktailThumb(cocktail: match.cocktail),
                    if (isLocked)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 11,
                            color: AppTheme.accentGold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.cocktail.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isLocked
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (isLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppTheme.accentGold.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentGold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (!isExact || showReadyStatus)
                        const SizedBox(height: 4),
                      if (showReadyStatus)
                        Row(
                          children: [
                            Text(
                              'Ready to make',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: accentColor.withValues(alpha: 0.9),
                              ),
                            ),
                            if (match.substitutionsUsed.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.swap_horiz,
                                size: 11,
                                color: accentColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'subs',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontStyle: FontStyle.italic,
                                  color: accentColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        )
                      else if (!isExact)
                        Text(
                          'Need: ${match.missingIngredients.join(", ")}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accentColor.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Text(
                            match.cocktail.baseSpirit,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withValues(alpha: 0.9),
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
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withValues(alpha: 0.9),
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
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isLocked ? Icons.lock_outline : Icons.chevron_right,
                  color: isLocked
                      ? AppTheme.accentGold.withValues(alpha: 0.6)
                      : AppTheme.textSecondary,
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

/// Owns its own TextEditingController so disposal happens when this widget's
/// Element is actually unmounted (i.e. once the dialog's closing transition
/// has fully finished) rather than right when showDialog's Future resolves —
/// disposing eagerly at that point can throw "A TextEditingController was
/// used after being disposed" if the transition (or the keyboard-hide
/// animation it triggers) rebuilds the TextField on a later frame.
class _RenameBarDialog extends StatefulWidget {
  final String initialName;

  const _RenameBarDialog({required this.initialName});

  @override
  State<_RenameBarDialog> createState() => _RenameBarDialogState();
}

class _RenameBarDialogState extends State<_RenameBarDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: const Text(
        'Rename Bar',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Bar name',
          hintStyle: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, name);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CocktailThumb extends StatefulWidget {
  final Cocktail cocktail;
  final double size;
  const _CocktailThumb({required this.cocktail, this.size = 54});
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
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => Container(
    width: widget.size,
    height: widget.size,
    decoration: BoxDecoration(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.local_bar, color: AppTheme.accentGold, size: 20),
  );
}

class _FinderRailTile extends StatefulWidget {
  final CocktailMatch match;
  final AppDatabase database;
  final double? width;
  const _FinderRailTile({
    required this.match,
    required this.database,
    this.width,
  });

  @override
  State<_FinderRailTile> createState() => _FinderRailTileState();
}

class _FinderRailTileState extends State<_FinderRailTile> {
  bool _pressed = false;
  bool _openingDetail = false;

  String _shortTastingNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';

    var lowered = raw.toLowerCase();
    const separators = <String>[
      ' with ',
      ' and ',
      ' & ',
      ';',
      '—',
      '-',
      '.',
      '!',
      '?',
    ];
    for (final s in separators) {
      lowered = lowered.replaceAll(s, ',');
    }
    const phraseBreaks = <String>[
      'notes of',
      'note of',
      'hint of',
      'hints of',
      'finish',
      'upfront',
      'underneath',
    ];
    for (final p in phraseBreaks) {
      lowered = lowered.replaceAll(p, ',');
    }

    final fillers = <String>{
      'notes',
      'softened',
      'delicate',
      'lightly',
      'fresh',
      'smooth',
      'rich',
      'unapologetically',
      'intensely',
      'deeply',
      'seriously',
      'truly',
      'perfectly',
      'beautifully',
      'boldly',
      'brightly',
      'very',
      'really',
      'super',
      'quite',
      'balanced',
      'classic',
    };

    final descriptors = <String>[];
    final seenStems = <String>{};
    for (final token in lowered.split(',')) {
      var chunk = token.trim();
      if (chunk.isEmpty) continue;
      chunk = chunk.replaceAll(
        RegExp(r'\b(a|the)\b\s*', caseSensitive: false),
        ' ',
      );
      for (final word in fillers) {
        final pattern = '\\b${RegExp.escape(word)}\\b';
        chunk = chunk.replaceAll(RegExp(pattern, caseSensitive: false), ' ');
      }
      chunk = chunk.replaceAll(RegExp(r'[^\w\s-]'), ' ');
      chunk = chunk.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (chunk.isEmpty) continue;

      final words = chunk.split(' ').where((w) => w.trim().isNotEmpty).toList();
      if (words.isEmpty) continue;
      final candidate = words.length <= 2
          ? words.join(' ')
          : words.take(2).join(' ');
      if (candidate.length < 4) continue;

      final title =
          candidate[0].toUpperCase() + candidate.substring(1).toLowerCase();
      final stem = title.toLowerCase();
      final stemKey = stem.length >= 5 ? stem.substring(0, 5) : stem;
      if (seenStems.contains(stemKey)) continue;

      seenStems.add(stemKey);
      descriptors.add(title);
      if (descriptors.length == 3) break;
    }

    if (descriptors.isEmpty) return '';
    return descriptors.take(3).join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    final tileNotesRaw = widget.match.cocktail.tilesNotes;
    final tasting = (tileNotesRaw != null && tileNotesRaw.trim().isNotEmpty)
        ? tileNotesRaw.trim()
        : _shortTastingNotes(widget.match.cocktail.tastingNotes);
    return GestureDetector(
      onTapDown: (_) {
        if (_openingDetail || !mounted) return;
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (!mounted) return;
        setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (!mounted) return;
        setState(() => _pressed = false);
      },
      onTap: () async {
        if (_openingDetail || !mounted) return;
        // Check if locked
        final auth = context.read<AuthService>();
        if (widget.match.cocktail.isPremium && !auth.isEffectivelyPremium) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PaywallScreen()));
          return;
        }
        _openingDetail = true;
        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CocktailDetailScreen(
                cocktail: widget.match.cocktail,
                database: widget.database,
              ),
            ),
          );
        } finally {
          if (mounted) _openingDetail = false;
        }
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _pressed ? 0.98 : 1.0,
        curve: Curves.easeOutCubic,
        child: Container(
          height: 220,
          width: widget.width,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.accentGold.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 92,
                child: Center(
                  child: _CocktailThumb(
                    cocktail: widget.match.cocktail,
                    size: 92,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 98,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.match.cocktail.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (tasting.isNotEmpty)
                      Text(
                        tasting,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary.withValues(alpha: 0.85),
                        ),
                      )
                    else
                      const SizedBox(height: 15),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.match.cocktail.baseSpirit} - ${widget.match.cocktail.method}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary.withValues(alpha: 0.86),
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
  }
}

enum _RailFamily { taste, spirit, method, glass, difficulty, hybrid }


class _BestUnlock {
  final String ingredientName;
  final int unlockCount;
  const _BestUnlock({required this.ingredientName, required this.unlockCount});
}

class _ScoredMatch {
  final CocktailMatch match;
  final double score;
  const _ScoredMatch(this.match, this.score);
}

enum _TimeBand { morning, afternoon, earlyEvening, lateEvening, lateNight }

class _BandConfig {
  final Set<String> priorityTags;
  final Set<String> excludeTags;
  final Set<String> preferredMethods;
  final int maxDifficulty;
  final String label;

  const _BandConfig({
    required this.priorityTags,
    required this.excludeTags,
    required this.preferredMethods,
    required this.maxDifficulty,
    required this.label,
  });
}

const Map<_TimeBand, _BandConfig> _bandConfigs = {
  _TimeBand.morning: _BandConfig(
    priorityTags: {'spritz', 'light', 'floral', 'citrus', 'low-abv'},
    excludeTags: {'smoky', 'bitter', 'strong', 'spirit-forward'},
    preferredMethods: {'build', 'shake'},
    maxDifficulty: 2,
    label: 'Good morning picks',
  ),
  _TimeBand.afternoon: _BandConfig(
    priorityTags: {'refreshing', 'citrus', 'tart', 'fruity', 'herbal'},
    excludeTags: {'smoky', 'strong'},
    preferredMethods: {'shake', 'build'},
    maxDifficulty: 3,
    label: 'Afternoon picks',
  ),
  _TimeBand.earlyEvening: _BandConfig(
    priorityTags: {'bitter', 'balanced', 'aperitif', 'citrus', 'herbal'},
    excludeTags: {'creamy', 'dessert', 'sweet'},
    preferredMethods: {'stir', 'shake'},
    maxDifficulty: 3,
    label: 'For the aperitif hour',
  ),
  _TimeBand.lateEvening: _BandConfig(
    priorityTags: {'spirit-forward', 'bold', 'rich', 'smooth', 'complex'},
    excludeTags: {'fruity', 'sweet', 'low-abv'},
    preferredMethods: {'stir'},
    maxDifficulty: 4,
    label: 'For tonight',
  ),
  _TimeBand.lateNight: _BandConfig(
    priorityTags: {'spirit-forward', 'strong', 'simple'},
    excludeTags: {'citrus', 'fruity', 'sweet', 'creamy'},
    preferredMethods: {'stir', 'build'},
    maxDifficulty: 5,
    label: 'Late night picks',
  ),
};

class _CocktailMeta {
  final String spirit;
  final String method;
  final String glass;
  final int difficulty;
  final Set<String> tags;
  const _CocktailMeta({
    required this.spirit,
    required this.method,
    required this.glass,
    required this.difficulty,
    required this.tags,
  });
}

class _FinderRailDefinition {
  final String id;
  final String title;
  final _RailFamily family;
  final int minCount;
  final bool Function(Cocktail cocktail, _CocktailMeta meta) predicate;
  const _FinderRailDefinition({
    required this.id,
    required this.title,
    required this.family,
    required this.minCount,
    required this.predicate,
  });
}

class _FinderRailBucket {
  final String id;
  final String title;
  final _RailFamily family;
  final int count;
  final List<CocktailMatch> matches;
  final double score;
  const _FinderRailBucket({
    required this.id,
    required this.title,
    required this.family,
    required this.count,
    required this.matches,
    required this.score,
  });
}

class _RailSectionData {
  final _FinderRailBucket rail;
  final List<CocktailMatch> railAvailable;
  final List<CocktailMatch> preview;
  final int minPreviewToRender;
  const _RailSectionData({
    required this.rail,
    required this.railAvailable,
    required this.preview,
    required this.minPreviewToRender,
  });
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

