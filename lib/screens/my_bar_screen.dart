import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import '../core/services/bar_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/bar_create_diagnostics.dart';
import '../core/utils/image_utils.dart';
import '../core/utils/bar_analytics.dart';
import '../data/database.dart';
import '../data/ingredient_data.dart';
import '../widgets/bar_selector_dropdown.dart';
import 'cocktail_detail_screen.dart';

typedef BarChangedCallback = void Function();

// ═══════════════════════════════════════════════════════════════════════════════
//  SHELF CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

class _AchievementMilestone {
  final String key;
  final String title;
  final int threshold;

  const _AchievementMilestone(this.key, this.title, this.threshold);
}

const List<_AchievementMilestone> _ingredientAchievements = [
  _AchievementMilestone('first_pour', 'First Pour', 1),
  _AchievementMilestone('getting_started', 'Getting Started', 5),
  _AchievementMilestone('home_bartender', 'Home Bartender', 16),
  _AchievementMilestone('well_stocked', 'Well Stocked', 30),
  _AchievementMilestone('professional', 'Professional', 40),
];

enum _BottleShape { tallSlim, squat, round, dropper, wedge, jar, cup, box }

/// Each bottle entry: shape + individual size tweak (height multiplier).
/// This creates organic height variation within a category.
class _BottleSpec {
  final _BottleShape shape;
  final double heightScale; // 0.85–1.15 range
  final double hMargin; // horizontal margin (px)

  const _BottleSpec(this.shape, {this.heightScale = 1.0, this.hMargin = 1.0});
}

const Map<String, List<_BottleSpec>> _categoryBottles = {
  'Spirits': [
    _BottleSpec(_BottleShape.tallSlim, heightScale: 1.0, hMargin: 0.5),
    _BottleSpec(_BottleShape.squat, heightScale: 1.0, hMargin: 0.5),
    _BottleSpec(_BottleShape.tallSlim, heightScale: 1.1, hMargin: 0.5),
    _BottleSpec(_BottleShape.tallSlim, heightScale: 0.92, hMargin: 0.5),
  ],
  'Liqueurs': [
    _BottleSpec(_BottleShape.squat, heightScale: 1.0, hMargin: 0.5),
    _BottleSpec(_BottleShape.round, heightScale: 1.08, hMargin: 1.0),
    _BottleSpec(_BottleShape.squat, heightScale: 0.9, hMargin: 0.5),
  ],
  'Citrus': [
    _BottleSpec(_BottleShape.wedge, heightScale: 1.0, hMargin: 1.5),
    _BottleSpec(_BottleShape.wedge, heightScale: 0.88, hMargin: 1.5),
  ],
  'Juices': [
    _BottleSpec(_BottleShape.round, heightScale: 1.0, hMargin: 1.0),
    _BottleSpec(_BottleShape.round, heightScale: 0.92, hMargin: 1.0),
  ],
  'Sweeteners': [
    _BottleSpec(_BottleShape.jar, heightScale: 1.0, hMargin: 1.0),
    _BottleSpec(_BottleShape.jar, heightScale: 0.88, hMargin: 1.0),
  ],
  'Mixers': [
    _BottleSpec(_BottleShape.tallSlim, heightScale: 1.0, hMargin: 0.5),
    _BottleSpec(_BottleShape.tallSlim, heightScale: 0.93, hMargin: 0.5),
  ],
  'Bitters': [
    _BottleSpec(_BottleShape.dropper, heightScale: 1.0, hMargin: 1.5),
    _BottleSpec(_BottleShape.dropper, heightScale: 0.9, hMargin: 1.5),
  ],
  'Coffee': [_BottleSpec(_BottleShape.cup, heightScale: 1.0, hMargin: 0.0)],
  'Other': [_BottleSpec(_BottleShape.box, heightScale: 1.0, hMargin: 0.0)],
};

const Map<String, double> _seriousnessCategoryWeights = {
  IngredientCategory.spirits: 1.0,
  IngredientCategory.liqueurs: 0.78,
  IngredientCategory.bitters: 0.56,
  IngredientCategory.citrus: 0.42,
  IngredientCategory.juices: 0.38,
  IngredientCategory.sweeteners: 0.34,
  IngredientCategory.mixers: 0.30,
  IngredientCategory.coffee: 0.24,
  IngredientCategory.other: 0.16,
};

const double _seriousnessSmallCountFactor = 0.18;
const bool _debugShowBackbarBounds = false;

class _BackbarDensityConfig {
  final int bottleCount;
  final int backRowCount;
  final double spacingTightness;
  final double fillLevel;

  const _BackbarDensityConfig({
    required this.bottleCount,
    required this.backRowCount,
    required this.spacingTightness,
    required this.fillLevel,
  });

  const _BackbarDensityConfig.empty()
    : bottleCount = 6,
      backRowCount = 0,
      spacingTightness = 0.0,
      fillLevel = 0.08;

  int get frontRowCount => max(0, bottleCount - backRowCount);
}

class _SeriousnessSnapshot {
  final Map<String, int> categoryCounts;
  final int stockedCount;
  final double index;
  final _BackbarDensityConfig density;

  const _SeriousnessSnapshot({
    required this.categoryCounts,
    required this.stockedCount,
    required this.index,
    required this.density,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class MyBarScreen extends StatefulWidget {
  final AppDatabase database;
  final String activeBarName;
  final ValueChanged<int>? onBarSwitched;
  final BarChangedCallback? onBarChanged;
  final VoidCallback? onNavigateToFinder;

  const MyBarScreen({
    super.key,
    required this.database,
    required this.activeBarName,
    this.onBarSwitched,
    this.onBarChanged,
    this.onNavigateToFinder,
  });

  @override
  State<MyBarScreen> createState() => MyBarScreenState();
}

class MyBarScreenState extends State<MyBarScreen>
    with TickerProviderStateMixin {
  List<Ingredient> _allIngredients = [];
  Set<int> _barIngredientIds = {};
  SavedBar? _activeBar;
  List<SavedBar> _savedBars = [];
  BarAnalyticsResult? _analytics;

  bool _isLoading = true;
  String _searchQuery = '';
  String? _activeShelfCategory;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  final ScrollController _listScrollController = ScrollController(
    keepScrollOffset: false,
  );
  final Map<String, GlobalKey> _categoryKeys = {};
  int _suggestionMode = 0;
  static const _suggestionLabels = [
    'Closest unlock',
    'Biggest unlock',
    'Finish a set',
  ];

  late AnimationController _headerAnimController;
  late Animation<double> _headerFade;

  OverlayEntry? _unlockOverlay;
  late AnimationController _unlockAnimController;
  late Animation<double> _unlockFade;
  late Animation<Offset> _unlockSlide;

  late AnimationController _counterAnimController;
  late BarAnalytics _barAnalytics;
  late final BarService _barService;
  Set<String> _earnedAchievementKeys = {};
  List<Cocktail> _allCocktailsCache = [];
  Map<int, Set<String>> _requiredCanonicalsByCocktail = {};
  bool _matchDataLoaded = false;
  bool _unlockSheetOpen = false;
  int _pendingUnlockCount = 0;
  final Set<int> _pendingUnlockedCocktailIds = <int>{};
  final Set<int> _busyIngredientIds = <int>{};
  final Map<int, BuildContext> _ingredientRowContexts = <int, BuildContext>{};
  final Set<String> _suggestionAddsInFlight = <String>{};
  DateTime? _lastSuggestionAddAt;
  bool _isCreatingBar = false;
  BarCreateDiagnosticsFlow? _createDiagnostics;
  bool _createHydrationScheduled = false;
  int? _pendingCreateHydrationBarId;
  BarCreateDiagnosticsFlow? _pendingCreateHydrationDiagnostics;
  DateTime? _lastImeSensitiveEventAt;
  Timer? _searchDebounceTimer;
  Timer? _unlockDebounceTimer;
  DateTime? _suppressUnlockSheetUntil;
  Map<String, int> _categoryCountsCache = const {};
  int _totalStockedCountCache = 0;
  double _seriousnessIndexCache = 0.0;
  _BackbarDensityConfig _backbarDensityCache =
      const _BackbarDensityConfig.empty();
  bool _lastHeroChangeWasAdd = false;

  @override
  void initState() {
    super.initState();
    _barAnalytics = BarAnalytics(widget.database);
    _barService = BarService(widget.database);

    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );

    _unlockAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _unlockFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_unlockAnimController);
    _unlockSlide =
        Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: const Offset(0, -0.5),
        ).animate(
          CurvedAnimation(
            parent: _unlockAnimController,
            curve: Curves.easeOutCubic,
          ),
        );

    _counterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _loadData();
  }

  @override
  void dispose() {
    _finishCreateDiagnostics(result: 'disposed');
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    _headerAnimController.dispose();
    _unlockAnimController.dispose();
    _counterAnimController.dispose();
    _searchDebounceTimer?.cancel();
    _unlockDebounceTimer?.cancel();
    _unlockOverlay?.remove();
    super.dispose();
  }

  Future<void> loadData() => _loadData();

  Future<void> _loadData() async {
    final ingredients = await widget.database
        .select(widget.database.ingredients)
        .get();
    final bars = await widget.database.select(widget.database.savedBars).get();

    SavedBar? activeBar = await widget.database.getDefaultSavedBar();
    if (activeBar == null && bars.isEmpty) {
      final id = await widget.database
          .into(widget.database.savedBars)
          .insert(
            SavedBarsCompanion.insert(
              name: 'My Bar',
              isDefault: const Value(true),
            ),
          );
      activeBar = await (widget.database.select(
        widget.database.savedBars,
      )..where((b) => b.id.equals(id))).getSingle();
    }
    activeBar ??= bars.first;

    final barIngredients = await widget.database.getSavedBarIngredients(
      activeBar.id,
    );
    final barIds = barIngredients.map((i) => i.id).toSet();
    final analytics = await _barAnalytics.compute();
    final seriousness = _computeSeriousnessSnapshot(
      ingredients: ingredients,
      stockedIds: barIds,
    );

    if (!mounted) return;
    setState(() {
      _allIngredients = ingredients;
      _activeBar = activeBar;
      _savedBars = List<SavedBar>.from(bars)
          ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      _barIngredientIds = barIds;
      _analytics = analytics;
      _categoryCountsCache = seriousness.categoryCounts;
      _totalStockedCountCache = seriousness.stockedCount;
      _seriousnessIndexCache = seriousness.index;
      _backbarDensityCache = seriousness.density;
      _lastHeroChangeWasAdd = false;
      _isLoading = false;
    });
    _earnedAchievementKeys = _earnedAchievementSetForCount(
      _barIngredientIds.length,
    );

    _headerAnimController.forward();
    _scrollIngredientListToTop();
  }

  void _scrollIngredientListToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScrollController.hasClients) return;
      if (_listScrollController.offset <= 0.5) return;
      _listScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _setSearchQuery(String value) {
    _searchDebounceTimer?.cancel();
    if (value.isEmpty) {
      if (_searchQuery.isEmpty) return;
      setState(() => _searchQuery = '');
      _scrollIngredientListToTop();
      return;
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || value == _searchQuery) return;
      setState(() => _searchQuery = value);
      _scrollIngredientListToTop();
    });
  }

  Future<void> _delayForImeSettleIfNeeded() async {
    final last = _lastImeSensitiveEventAt;
    if (last == null) return;
    const settleWindow = Duration(milliseconds: 220);
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= settleWindow) return;
    final wait = settleWindow - elapsed;
    if (kDebugMode) {
      debugPrint('MyBar IME settle delay ${wait.inMilliseconds}ms');
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

  void _markCreateSetState(String reason) {
    _createDiagnostics?.incrementSetState(reason);
  }

  void _finishCreateDiagnostics({required String result}) {
    _createDiagnostics?.finish(result: result);
    _createDiagnostics = null;
  }

  Future<void> _handleSuggestionAdd() async {
    final suggestion = _analytics?.suggestion;
    if (suggestion == null) return;

    final canonical = suggestion.canonicalName;
    final now = DateTime.now();
    final last = _lastSuggestionAddAt;
    if (last != null && now.difference(last).inMilliseconds < 150) {
      return;
    }
    _lastSuggestionAddAt = now;

    if (_suggestionAddsInFlight.contains(canonical)) return;

    final matches = _allIngredients
        .where((i) => IngredientEquivalence.normalise(i.name) == canonical)
        .toList(growable: false);
    if (matches.isEmpty) return;

    Ingredient? target;
    for (final ingredient in matches) {
      if (!_barIngredientIds.contains(ingredient.id)) {
        target = ingredient;
        break;
      }
    }
    if (target == null) return;

    if (!mounted) return;
    setState(() => _suggestionAddsInFlight.add(canonical));

    try {
      await _toggleIngredient(target.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not add suggested ingredient. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _suggestionAddsInFlight.remove(canonical));
      }
    }
  }

  _SeriousnessSnapshot _computeSeriousnessSnapshot({
    required List<Ingredient> ingredients,
    required Set<int> stockedIds,
  }) {
    final categoryCounts = <String, int>{};
    final allCategoryTotals = <String, int>{};

    for (final ingredient in ingredients) {
      allCategoryTotals[ingredient.category] =
          (allCategoryTotals[ingredient.category] ?? 0) + 1;
      if (stockedIds.contains(ingredient.id)) {
        categoryCounts[ingredient.category] =
            (categoryCounts[ingredient.category] ?? 0) + 1;
      }
    }

    double seriousnessScore = 0.0;
    double maxSeriousnessScore = 0.0;
    for (final category in IngredientCategory.allCategories) {
      final weight = _seriousnessCategoryWeights[category] ?? 0.2;
      seriousnessScore += weight * (categoryCounts[category] ?? 0);
      maxSeriousnessScore += weight * (allCategoryTotals[category] ?? 0);
    }

    final scoreNorm = maxSeriousnessScore > 0
        ? (seriousnessScore / maxSeriousnessScore).clamp(0.0, 1.0)
        : 0.0;
    final totalNorm = ingredients.isNotEmpty
        ? (stockedIds.length / ingredients.length).clamp(0.0, 1.0)
        : 0.0;
    final combined =
        (scoreNorm + (_seriousnessSmallCountFactor * totalNorm)) /
        (1.0 + _seriousnessSmallCountFactor);
    final seriousnessIndex = combined.clamp(0.0, 1.0);

    return _SeriousnessSnapshot(
      categoryCounts: categoryCounts,
      stockedCount: stockedIds.length,
      index: seriousnessIndex,
      density: _densityForSeriousnessIndex(seriousnessIndex),
    );
  }

  _BackbarDensityConfig _densityForSeriousnessIndex(double index) {
    int total;
    double spacingTightness;
    if (index < 0.2) {
      final t = (index / 0.2).clamp(0.0, 1.0);
      total = (6 + (2 * t)).round();
      spacingTightness = 0.06;
    } else if (index < 0.5) {
      final t = ((index - 0.2) / 0.3).clamp(0.0, 1.0);
      total = (10 + (4 * t)).round();
      spacingTightness = 0.15;
    } else if (index < 0.8) {
      final t = ((index - 0.5) / 0.3).clamp(0.0, 1.0);
      total = (16 + (6 * t)).round();
      spacingTightness = 0.23;
    } else {
      final t = ((index - 0.8) / 0.2).clamp(0.0, 1.0);
      total = (24 + (6 * t)).round();
      spacingTightness = 0.30;
    }
    total = max(6, total);

    final hasBackRow = index >= 0.5;
    final backRatio = index >= 0.8 ? 0.40 : 0.32;
    final backRow = hasBackRow ? (total * backRatio).round() : 0;
    final fillLevel = (0.10 + (index * 0.86)).clamp(0.0, 1.0);

    return _BackbarDensityConfig(
      bottleCount: total,
      backRowCount: backRow,
      spacingTightness: spacingTightness,
      fillLevel: fillLevel,
    );
  }

  void _recomputeSeriousnessCaches({required bool changedByAdd}) {
    _createDiagnostics?.incrementCounter(
      '_recomputeSeriousnessCaches',
      stackTrace: StackTrace.current,
    );
    final snapshot = _computeSeriousnessSnapshot(
      ingredients: _allIngredients,
      stockedIds: _barIngredientIds,
    );
    _categoryCountsCache = snapshot.categoryCounts;
    _totalStockedCountCache = snapshot.stockedCount;
    _seriousnessIndexCache = snapshot.index;
    _backbarDensityCache = snapshot.density;
    _lastHeroChangeWasAdd = changedByAdd;
  }

  Future<void> _refreshAnalytics() async {
    final analytics = await _barAnalytics.compute();
    _checkForNewAchievements();
    if (mounted) {
      _counterAnimController.forward(from: 0);
      setState(() => _analytics = analytics);
    }
  }

  Set<String> _earnedAchievementSetForCount(int ingredientCount) {
    final set = <String>{};
    for (final milestone in _ingredientAchievements) {
      if (ingredientCount >= milestone.threshold) {
        set.add(milestone.key);
      }
    }
    if (_allIngredients.isNotEmpty &&
        ingredientCount >= _allIngredients.length) {
      set.add('completionist');
    }
    return set;
  }

  void _checkForNewAchievements() {
    final current = _earnedAchievementSetForCount(_barIngredientIds.length);
    final newlyEarned = current.difference(_earnedAchievementKeys);
    _earnedAchievementKeys = current;

    if (newlyEarned.isEmpty || !mounted) return;

    final newest = _ingredientAchievements
        .where((a) => newlyEarned.contains(a.key))
        .fold<_AchievementMilestone?>(
          null,
          (best, item) =>
              best == null || item.threshold > best.threshold ? item : best,
        );

    if (newest != null) {
      _showAchievementPop(newest.title);
    } else if (newlyEarned.contains('completionist')) {
      _showAchievementPop('Completionist');
    }
  }

  Future<void> _showAchievementPop(String title) async {
    if (!mounted) return;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'achievement',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 76),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.accentGold.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGold.withValues(alpha: 0.18),
                        blurRadius: 10,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: AppTheme.accentGold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Achievement Unlocked',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.35,
                              color: AppTheme.accentGold.withValues(
                                alpha: 0.92,
                              ),
                            ),
                          ),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 1050));
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _toggleIngredient(int ingredientId) async {
    if (_activeBar == null) return;
    if (_busyIngredientIds.contains(ingredientId)) return;

    setState(() => _busyIngredientIds.add(ingredientId));
    HapticFeedback.lightImpact();

    try {
      final isAdding = !_barIngredientIds.contains(ingredientId);
      Set<int> exactBefore = {};
      Set<int> exactAfter = {};
      int delta = 0;
      if (isAdding) {
        exactBefore = await _computeExactMatchCocktailIds(_barIngredientIds);
        delta = await _barAnalytics.computeUnlockDelta(ingredientId, true);
      }

      if (_barIngredientIds.contains(ingredientId)) {
        await (widget.database.delete(widget.database.savedBarIngredients)
              ..where(
                (bi) =>
                    bi.savedBarId.equals(_activeBar!.id) &
                    bi.ingredientId.equals(ingredientId),
              ))
            .go();
        setState(() {
          _barIngredientIds.remove(ingredientId);
          _recomputeSeriousnessCaches(changedByAdd: false);
        });
      } else {
        await widget.database.addIngredientToSavedBar(
          savedBarId: _activeBar!.id,
          ingredientId: ingredientId,
        );
        setState(() {
          _barIngredientIds.add(ingredientId);
          _recomputeSeriousnessCaches(changedByAdd: true);
        });
        exactAfter = await _computeExactMatchCocktailIds(_barIngredientIds);
      }

      final anchorContext = _ingredientRowContexts[ingredientId];
      if (isAdding && delta > 0 && anchorContext != null && anchorContext.mounted) {
        _showUnlockDelta(delta, anchorContext);
      }
      if (isAdding) {
        final newlyUnlockedIds = exactAfter.difference(exactBefore);
        if (newlyUnlockedIds.isNotEmpty) {
          _queueUnlockedCocktails(newlyUnlockedIds);
        }
      }

      widget.onBarChanged?.call();
      await _refreshAnalytics();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update ingredient. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIngredientIds.remove(ingredientId));
      }
    }
  }

  Future<void> _ensureMatchDataLoaded() async {
    if (_matchDataLoaded) return;
    final cocktails = await widget.database
        .select(widget.database.cocktails)
        .get();
    final allCi = await widget.database
        .select(widget.database.cocktailIngredients)
        .get();
    final ingredientNameById = {for (final i in _allIngredients) i.id: i.name};
    final required = <int, Set<String>>{};
    for (final ci in allCi) {
      final ingredientName = ingredientNameById[ci.ingredientId];
      if (ingredientName == null) continue;
      final canon = IngredientEquivalence.normalise(ingredientName);
      required.putIfAbsent(ci.cocktailId, () => <String>{}).add(canon);
    }
    _allCocktailsCache = cocktails;
    _requiredCanonicalsByCocktail = required;
    _matchDataLoaded = true;
  }

  Future<Set<int>> _computeExactMatchCocktailIds(
    Set<int> barIngredientIds,
  ) async {
    await _ensureMatchDataLoaded();
    final ingredientNameById = {for (final i in _allIngredients) i.id: i.name};
    final barCanonicals = <String>{};
    for (final id in barIngredientIds) {
      final name = ingredientNameById[id];
      if (name != null) {
        barCanonicals.add(IngredientEquivalence.normalise(name));
      }
    }
    final barSubCanonicals = <String>{};
    for (final canon in barCanonicals) {
      barSubCanonicals.addAll(IngredientSubstitutions.getSubstitutes(canon));
    }

    final exact = <int>{};
    for (final cocktail in _allCocktailsCache) {
      final required = _requiredCanonicalsByCocktail[cocktail.id];
      if (required == null || required.isEmpty) continue;
      bool allMatched = true;
      for (final canon in required) {
        if (!barCanonicals.contains(canon) &&
            !barSubCanonicals.contains(canon)) {
          allMatched = false;
          break;
        }
      }
      if (allMatched) exact.add(cocktail.id);
    }
    return exact;
  }

  void _queueUnlockedCocktails(Set<int> newlyUnlockedIds) {
    if (newlyUnlockedIds.isEmpty || !mounted) return;
    _pendingUnlockedCocktailIds.addAll(newlyUnlockedIds);
    _pendingUnlockCount = _pendingUnlockedCocktailIds.length;

    _unlockDebounceTimer?.cancel();
    _unlockDebounceTimer = Timer(
      const Duration(milliseconds: 900),
      _flushPendingUnlocks,
    );
  }

  void _clearPendingUnlocks() {
    _pendingUnlockedCocktailIds.clear();
    _pendingUnlockCount = 0;
  }

  Future<void> _flushPendingUnlocks() async {
    if (!mounted || _pendingUnlockCount == 0) return;

    if (_unlockSheetOpen) {
      _unlockDebounceTimer?.cancel();
      _unlockDebounceTimer = Timer(
        const Duration(milliseconds: 350),
        _flushPendingUnlocks,
      );
      return;
    }

    final suppressUntil = _suppressUnlockSheetUntil;
    if (suppressUntil != null && DateTime.now().isBefore(suppressUntil)) {
      _clearPendingUnlocks();
      return;
    }

    final idsToShow = Set<int>.from(_pendingUnlockedCocktailIds);
    _clearPendingUnlocks();

    final keepAddingSelected = await _showUnlockedCocktailsSheet(idsToShow);
    if (keepAddingSelected) {
      _suppressUnlockSheetUntil = DateTime.now().add(
        const Duration(seconds: 2),
      );
    }
  }

  Future<bool> _showUnlockedCocktailsSheet(Set<int> unlockedIds) async {
    if (!mounted || _unlockSheetOpen) return false;
    _unlockSheetOpen = true;
    final unlocked =
        _allCocktailsCache.where((c) => unlockedIds.contains(c.id)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final keepAddingSelected = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final single = unlocked.length == 1;
        final title = single
            ? unlocked.first.name
            : '${unlocked.length} cocktails unlocked';
        final subtitle = single
            ? 'You can now make this in ${widget.activeBarName}.'
            : 'New recipes are now available in ${widget.activeBarName}.';
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.surfaceDark.withValues(alpha: 0.99),
                AppTheme.primaryDark.withValues(alpha: 0.99),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppTheme.surfaceLight.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 22,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 2,
                width: double.infinity,
                color: AppTheme.accentGold.withValues(alpha: 0.92),
              ),
              const SizedBox(height: 16),
              _AnimatedUnlockReveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UNLOCKED',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentGold.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (single)
                _AnimatedUnlockReveal(
                  child: SizedBox(
                    height: 212,
                    width: double.infinity,
                    child: _UnlockPreviewCard(
                      cocktail: unlocked.first,
                      showName: false,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: unlocked.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) => SizedBox(
                      width: 156,
                      child: _AnimatedUnlockReveal(
                        child: _UnlockPreviewCard(cocktail: unlocked[index]),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(
                          color: AppTheme.surfaceLight.withValues(alpha: 0.7),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Keep Adding'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: AppTheme.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx, false);
                        if (single) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CocktailDetailScreen(
                                database: widget.database,
                                cocktail: unlocked.first,
                              ),
                            ),
                          );
                        } else {
                          widget.onNavigateToFinder?.call();
                        }
                      },
                      child: Text(single ? 'View Cocktail' : 'View in Finder'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    _unlockSheetOpen = false;
    return keepAddingSelected == true;
  }

  void _showUnlockDelta(int delta, BuildContext anchorContext) {
    _unlockOverlay?.remove();
    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _unlockAnimController.reset();
    _unlockOverlay = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: _unlockAnimController,
        builder: (context, child) => Positioned(
          right: 40,
          top:
              position.dy + size.height / 2 - 16 + (_unlockSlide.value.dy * 40),
          child: Opacity(
            opacity: _unlockFade.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentGold,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentGold.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                '+$delta cocktail${delta != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_unlockOverlay!);
    _unlockAnimController.forward().then((_) {
      _unlockOverlay?.remove();
      _unlockOverlay = null;
    });
  }

  Future<void> _switchToBar(int barId) async {
    _createDiagnostics?.incrementCounter(
      '_switchToBar',
      stackTrace: StackTrace.current,
    );
    await _delayForImeSettleIfNeeded();
    await _barService.setDefaultBar(barId);

    final active = await (widget.database.select(
      widget.database.savedBars,
    )..where((b) => b.id.equals(barId))).getSingle();
    final ingredients = await widget.database.getSavedBarIngredients(barId);
    final bars = await (widget.database.select(
      widget.database.savedBars,
    )..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();

    if (!mounted) return;
    _markCreateSetState('_switchToBar:setState');
    setState(() {
      _activeBar = active;
      _savedBars = bars;
      _barIngredientIds = ingredients.map((i) => i.id).toSet();
      _activeShelfCategory = null;
      _searchQuery = '';
      _searchController.clear();
      _recomputeSeriousnessCaches(changedByAdd: false);
    });
    _scrollIngredientListToTop();

    widget.onBarChanged?.call();
    _refreshAnalytics();
  }

  void _scheduleCreateHydration(
    int barId, {
    BarCreateDiagnosticsFlow? diagnostics,
  }) {
    _pendingCreateHydrationBarId = barId;
    _pendingCreateHydrationDiagnostics = diagnostics;
    if (_createHydrationScheduled) return;
    _createHydrationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _createHydrationScheduled = false;
      final hydrationBarId = _pendingCreateHydrationBarId;
      final flow = _pendingCreateHydrationDiagnostics;
      _pendingCreateHydrationBarId = null;
      _pendingCreateHydrationDiagnostics = null;
      if (!mounted || hydrationBarId == null) {
        flow?.finish(result: 'aborted');
        if (identical(_createDiagnostics, flow)) {
          _createDiagnostics = null;
        }
        return;
      }

      final phaseBSw = Stopwatch()..start();
      try {
        flow?.step('phaseB:postFrameStart');
        await _delayForImeSettleIfNeeded();
        flow?.step('phaseB:imeSettleDone');
        if (widget.onBarSwitched != null) {
          flow?.incrementCounter(
            '_switchToBar(delegate)',
            stackTrace: StackTrace.current,
          );
          widget.onBarSwitched!(hydrationBarId);
        } else {
          await _switchToBar(hydrationBarId);
        }
        flow?.step('phaseB:switchDone');
      } finally {
        flow?.step('phaseB:finally');
        if (kDebugMode) {
          debugPrint(
            'MyBar create Phase B (deferred hydration) ${phaseBSw.elapsedMilliseconds}ms',
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
    final flow = BarCreateDiagnosticsFlow.start('MyBar');
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

      if (!mounted) {
        _finishCreateDiagnostics(result: 'unmounted');
        return;
      }

      final optimisticBar = SavedBar(
        id: newBarId,
        name: trimmedName,
        isDefault: true,
        createdAt: now,
        lastUsed: now,
      );
      final existing = List<SavedBar>.from(_savedBars)
        ..removeWhere((b) => b.id == newBarId)
        ..insert(0, optimisticBar);

      _markCreateSetState('phaseA:optimisticUi');
      setState(() {
        _savedBars = existing;
        _activeBar = optimisticBar;
        _barIngredientIds = {};
        _activeShelfCategory = null;
        _searchQuery = '';
        _searchController.clear();
        _categoryCountsCache = const {};
        _totalStockedCountCache = 0;
        _seriousnessIndexCache = 0.0;
        _backbarDensityCache = const _BackbarDensityConfig.empty();
        _lastHeroChangeWasAdd = false;
      });
      flow.step('phaseA:setStateDone');
      _scrollIngredientListToTop();
      flow.step('phaseA:scrollTopDone');

      if (kDebugMode) {
        debugPrint(
          'MyBar create Phase A (immediate UI) ${phaseASw.elapsedMilliseconds}ms',
        );
      }

      _scheduleCreateHydration(newBarId, diagnostics: flow);
      flow.step('phaseA:scheduleDeferredHydration');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "${optimisticBar.name}"'),
            action: SnackBarAction(
              label: 'Rename',
              onPressed: () {
                _showRenameBarDialog(optimisticBar.id, optimisticBar.name);
              },
            ),
          ),
        );
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

  Future<void> _showRenameBarDialog(int barId, String initialName) async {
    final controller = TextEditingController(text: initialName);
    final renamed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Rename Bar',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Bar name',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || renamed == null || renamed.trim().isEmpty) return;
    final name = renamed.trim();

    await (widget.database.update(widget.database.savedBars)
          ..where((b) => b.id.equals(barId)))
        .write(SavedBarsCompanion(name: Value(name)));

    final bars = await (widget.database.select(
      widget.database.savedBars,
    )..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
    if (!mounted) return;
    setState(() {
      _savedBars = bars;
      if (_activeBar?.id == barId) {
        _activeBar = _activeBar!.copyWith(name: name);
      }
    });
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
    setState(() {
      _barIngredientIds.clear();
      _recomputeSeriousnessCaches(changedByAdd: false);
    });
    widget.onBarChanged?.call();
    await _refreshAnalytics();
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

    var remainingBars = await (widget.database.select(
      widget.database.savedBars,
    )..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
    if (remainingBars.isEmpty || !mounted) return;

    final activeBarStillExists =
        _activeBar != null && remainingBars.any((b) => b.id == _activeBar!.id);
    final hasDefault = remainingBars.any((b) => b.isDefault);

    if (deletingActive || !activeBarStillExists || !hasDefault) {
      await _barService.setDefaultBar(remainingBars.first.id);
      remainingBars = await (widget.database.select(
        widget.database.savedBars,
      )..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
    }

    if (!mounted || remainingBars.isEmpty) return;

    if (deletingActive || !activeBarStillExists) {
      await _switchToBar(remainingBars.first.id);
    } else {
      final active = remainingBars.firstWhere(
        (b) => b.id == _activeBar!.id,
        orElse: () => remainingBars.first,
      );
      final ingredients = await widget.database.getSavedBarIngredients(active.id);
      if (!mounted) return;
      setState(() {
        _activeBar = active;
        _savedBars = remainingBars;
        _barIngredientIds = ingredients.map((i) => i.id).toSet();
        _recomputeSeriousnessCaches(changedByAdd: false);
      });
      widget.onBarChanged?.call();
      await _refreshAnalytics();
    }

    if (!mounted) return;
    final activeId = _activeBar?.id;
    if (activeId != null && widget.onBarSwitched != null) {
      widget.onBarSwitched!(activeId);
    } else {
      widget.onBarChanged?.call();
    }
  }

  void _activateCategoryFilter(String category) {
    if (_activeShelfCategory == category) return;
    setState(() {
      _activeShelfCategory = category;
    });
    _scrollIngredientListToTop();
  }

  void _clearCategoryFilter() {
    if (_activeShelfCategory == null) return;
    setState(() => _activeShelfCategory = null);
    _scrollIngredientListToTop();
  }

  List<Ingredient> get _filteredIngredients {
    var list = _allIngredients;
    if (_activeShelfCategory != null) {
      list = list.where((i) => i.category == _activeShelfCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where(
            (i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    return list;
  }

  Map<String, List<Ingredient>> get _groupedIngredients {
    final map = <String, List<Ingredient>>{};
    for (final i in _filteredIngredients) {
      map.putIfAbsent(i.category, () => []).add(i);
    }
    return map;
  }

  Map<String, int> get _categoryCounts {
    return _categoryCountsCache;
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

    final heroHeight = (MediaQuery.of(context).size.height * 0.32).clamp(
      228.0,
      320.0,
    );

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Center(
                child: BarSelectorDropdown(
                  currentBarName: _activeBar?.name ?? widget.activeBarName,
                  currentBarId: _activeBar?.id,
                  bars: _savedBars,
                  maxWidth: 320,
                  isCreateInProgress: _isCreatingBar,
                  onSelectBar: (barId) async {
                    if (barId == _activeBar?.id) return;
                    if (widget.onBarSwitched != null) {
                      widget.onBarSwitched!(barId);
                      return;
                    }
                    await _switchToBar(barId);
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
              ),
            ),
            const SizedBox(height: 2),
            // ── 1+2. Unified ambient hero shelf ──
            FadeTransition(
              opacity: _headerFade,
              child: SizedBox(
                height: heroHeight,
                child: _MyBarHeroCard(
                  stockedCount: _totalStockedCountCache,
                  seriousnessIndex: _seriousnessIndexCache,
                  density: _backbarDensityCache,
                  showAddSheen: _lastHeroChangeWasAdd,
                ),
              ),
            ),

            // Clear separation: emotional hero vs functional controls.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                height: 1,
                color: AppTheme.surfaceLight.withValues(alpha: 0.35),
              ),
            ),

            // ── 3. Search ──
            _IngredientSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _setSearchQuery,
              onClear: () {
                _searchController.clear();
                _setSearchQuery('');
              },
              hasQuery: _searchQuery.isNotEmpty,
            ),

            // ── 4. Category chips ──
            _CategoryFilterChips(
              selectedCategory: _activeShelfCategory,
              stockedCounts: _categoryCounts,
              onSelect: (category) {
                if (category == null) {
                  _clearCategoryFilter();
                  return;
                }
                _activateCategoryFilter(category);
              },
            ),

            // ── 5. Smart suggestion ──
            if (_analytics?.suggestion != null && _barIngredientIds.isNotEmpty)
              _InlineSuggestion(
                suggestion: _analytics!.suggestion!,
                modeLabel: _suggestionLabels[_suggestionMode],
                isBusy:
                    _suggestionAddsInFlight.contains(
                      _analytics!.suggestion!.canonicalName,
                    ) ||
                    _allIngredients
                        .where(
                          (i) =>
                              IngredientEquivalence.normalise(i.name) ==
                              _analytics!.suggestion!.canonicalName,
                        )
                        .map((i) => i.id)
                        .any(_busyIngredientIds.contains),
                onAdd: _handleSuggestionAdd,
                onCycleMode: () {
                  setState(() {
                    _suggestionMode = (_suggestionMode + 1) % 3;
                  });
                },
              ),

            // ── 6. Ingredient list ──
            Expanded(
              child: _IngredientListSection(
                groupedIngredients: _groupedIngredients,
                barIngredientIds: _barIngredientIds,
                busyIngredientIds: _busyIngredientIds,
                onToggle: _toggleIngredient,
                onTapWithContext: (ingredientId, ctx) {
                  _ingredientRowContexts[ingredientId] = ctx;
                },
                scrollController: _listScrollController,
                categoryKeys: _categoryKeys,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  1+2. BAR INTERIOR ZONE — unified header + rail in one ambient surface
// ═══════════════════════════════════════════════════════════════════════════════

class _MyBarHeroCard extends StatelessWidget {
  final int stockedCount;
  final double seriousnessIndex;
  final _BackbarDensityConfig density;
  final bool showAddSheen;

  const _MyBarHeroCard({
    required this.stockedCount,
    required this.seriousnessIndex,
    required this.density,
    required this.showAddSheen,
  });

  @override
  Widget build(BuildContext context) {
    final warmTint = Color.lerp(
      const Color(0xFF1E1E1E),
      const Color(0xFF2B2317),
      seriousnessIndex * 0.6,
    )!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.accentGold.withValues(
            alpha: 0.08 + seriousnessIndex * 0.1,
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.surfaceDark, warmTint],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _StaticGrainPainter(
                    seed: 31,
                    opacity: 0.028,
                    step: 4,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your bar is growing',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Stocking spirits and essentials builds a serious backbar.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary.withValues(alpha: 0.84),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Backbar density',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.25,
                  color: AppTheme.textSecondary.withValues(alpha: 0.74),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 146,
                child: _BackbarShelfStage(
                  targetFillLevel: density.fillLevel,
                  bottleCount: density.bottleCount,
                  backRowCount: density.backRowCount,
                  spacingTightness: density.spacingTightness,
                  showAddSheen: showAddSheen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Backbar: $stockedCount stocked',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary.withValues(alpha: 0.84),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackbarShelfStage extends StatefulWidget {
  final double targetFillLevel;
  final int bottleCount;
  final int backRowCount;
  final double spacingTightness;
  final bool showAddSheen;

  const _BackbarShelfStage({
    required this.targetFillLevel,
    required this.bottleCount,
    required this.backRowCount,
    required this.spacingTightness,
    required this.showAddSheen,
  });

  @override
  State<_BackbarShelfStage> createState() => _BackbarShelfStageState();
}

class _BackbarShelfStageState extends State<_BackbarShelfStage>
    with TickerProviderStateMixin {
  late AnimationController _fillController;
  late Animation<double> _fillAnimation;
  late AnimationController _sheenController;
  late Animation<double> _sheenSweep;
  late Animation<double> _sheenOpacity;
  double _currentFill = 0.10;

  @override
  void initState() {
    super.initState();
    _currentFill = widget.targetFillLevel.clamp(0.0, 1.0);
    _fillController = AnimationController(vsync: this, value: 1.0);
    _fillAnimation = AlwaysStoppedAnimation<double>(_currentFill);
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _sheenSweep = Tween<double>(begin: -0.8, end: 1.2).animate(
      CurvedAnimation(parent: _sheenController, curve: Curves.easeOutCubic),
    );
    _sheenOpacity = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.26), weight: 34),
        TweenSequenceItem(tween: Tween(begin: 0.26, end: 0.0), weight: 66),
      ],
    ).animate(CurvedAnimation(parent: _sheenController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _BackbarShelfStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFill = widget.targetFillLevel.clamp(0.0, 1.0);
    final increasing = nextFill > _currentFill;
    final duration = increasing
        ? const Duration(milliseconds: 460)
        : const Duration(milliseconds: 320);
    final curve = increasing ? Curves.easeOutCubic : Curves.easeInOutCubic;

    _fillController.duration = duration;
    _fillAnimation = Tween<double>(
      begin: _currentFill,
      end: nextFill,
    ).animate(CurvedAnimation(parent: _fillController, curve: curve));
    _currentFill = nextFill;
    _fillController.forward(from: 0.0);

    if (increasing && widget.showAddSheen) {
      _sheenController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    _sheenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _fillController,
                  _sheenController,
                ]),
                builder: (context, child) {
                  return CustomPaint(
                    size: stageSize,
                    painter: _BackbarShelfPainter(
                      fillLevel: _fillAnimation.value,
                      bottleCount: widget.bottleCount,
                      backRowCount: widget.backRowCount,
                      spacingTightness: widget.spacingTightness,
                      sheenX: _sheenSweep.value,
                      sheenOpacity: _sheenOpacity.value,
                    ),
                  );
                },
              ),
            ),
            if (kDebugMode && _debugShowBackbarBounds)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.accentGold.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BackbarShelfPainter extends CustomPainter {
  final double fillLevel;
  final int bottleCount;
  final int backRowCount;
  final double spacingTightness;
  final double sheenX;
  final double sheenOpacity;

  _BackbarShelfPainter({
    required this.fillLevel,
    required this.bottleCount,
    required this.backRowCount,
    required this.spacingTightness,
    required this.sheenX,
    required this.sheenOpacity,
  });

  static final List<Path> _templates = _BottleTemplateLibrary.templates;

  @override
  void paint(Canvas canvas, Size size) {
    final stageRect = Offset.zero & size;
    final top = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.surfaceDark.withValues(alpha: 0.72),
          const Color(0xFF1E1A14).withValues(alpha: 0.94),
        ],
      ).createShader(stageRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(stageRect, const Radius.circular(10)),
      top,
    );

    final shelfY = size.height - 18;
    final shelfGlow = Paint()
      ..color = AppTheme.accentGold.withValues(alpha: 0.24)
      ..strokeWidth = 1.2;
    final shelfBase = Paint()
      ..color = AppTheme.surfaceLight.withValues(alpha: 0.58)
      ..strokeWidth = 3.0;
    canvas.drawLine(
      Offset(4, shelfY),
      Offset(size.width - 4, shelfY),
      shelfGlow,
    );
    canvas.drawLine(
      Offset(4, shelfY + 1.6),
      Offset(size.width - 4, shelfY + 1.6),
      shelfBase,
    );

    final frontCount = max(0, bottleCount - backRowCount);
    _paintRow(
      canvas: canvas,
      size: size,
      count: max(0, backRowCount),
      isBackRow: true,
      baselineY: shelfY - 6,
      fillLevel: fillLevel * 0.92,
      spacingTightness: spacingTightness,
    );
    _paintRow(
      canvas: canvas,
      size: size,
      count: max(6, frontCount),
      isBackRow: false,
      baselineY: shelfY,
      fillLevel: fillLevel,
      spacingTightness: spacingTightness,
    );
  }

  void _paintRow({
    required Canvas canvas,
    required Size size,
    required int count,
    required bool isBackRow,
    required double baselineY,
    required double fillLevel,
    required double spacingTightness,
  }) {
    if (count <= 0) return;
    final rowInset = isBackRow ? 18.0 : 10.0;
    final rowWidth = max(1.0, size.width - rowInset * 2);
    final normSpacing = count > 1 ? rowWidth / (count - 1) : rowWidth;
    final compressed = normSpacing * (1.0 - spacingTightness.clamp(0.0, 0.35));
    final rowSpan = compressed * (count - 1);
    final leftStart = (size.width - rowSpan) / 2;

    for (int i = 0; i < count; i++) {
      final template =
          _templates[(i * 7 + (isBackRow ? 3 : 11)) % _templates.length];
      final jitter = (((i * 19 + (isBackRow ? 5 : 13)) % 7) - 3) * 0.7;
      final x = leftStart + (compressed * i) + jitter;
      final width = (isBackRow ? 12.0 : 14.5) + ((i % 4) * 0.8);
      final height = (isBackRow ? 40.0 : 54.0) + (((i * 11) % 5) * 2.4);
      final rect = Rect.fromLTWH(
        x - (width / 2),
        baselineY - height,
        width,
        height,
      );
      _paintBottle(
        canvas: canvas,
        template: template,
        rect: rect,
        fillLevel: fillLevel,
        backRow: isBackRow,
      );
    }
  }

  void _paintBottle({
    required Canvas canvas,
    required Path template,
    required Rect rect,
    required double fillLevel,
    required bool backRow,
  }) {
    final matrix = Matrix4.identity()
      ..translateByDouble(rect.left, rect.top, 0.0, 1.0)
      ..scaleByDouble(rect.width, rect.height, 1.0, 1.0);
    final path = template.transform(matrix.storage);

    final glassOutline = Paint()
      ..color =
          (backRow
                  ? AppTheme.surfaceLight.withValues(alpha: 0.52)
                  : AppTheme.surfaceLight.withValues(alpha: 0.66))
              .withValues(alpha: backRow ? 0.50 : 0.64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = backRow ? 0.9 : 1.1;
    final glassBody = Paint()
      ..color = backRow
          ? Colors.white.withValues(alpha: 0.045)
          : Colors.white.withValues(alpha: 0.065)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, glassBody);
    canvas.drawPath(path, glassOutline);

    final inner = path.getBounds().deflate(max(0.5, rect.width * 0.07));
    final clampedFill = fillLevel.clamp(0.0, 1.0);
    final liquidTop = inner.bottom - (inner.height * clampedFill);
    final liquidRect = Rect.fromLTRB(
      inner.left,
      liquidTop,
      inner.right,
      inner.bottom + 1,
    );
    final liquid = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.accentGold.withValues(alpha: backRow ? 0.26 : 0.34),
          AppTheme.accentGold.withValues(alpha: backRow ? 0.42 : 0.54),
        ],
      ).createShader(liquidRect);

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(liquidRect, liquid);

    final highlightX = inner.left + (inner.width * 0.23);
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: backRow ? 0.06 : 0.09);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          highlightX,
          inner.top + 2,
          max(1.0, inner.width * 0.10),
          max(4.0, inner.height * 0.70),
        ),
        const Radius.circular(2),
      ),
      highlight,
    );

    if (sheenOpacity > 0.0 && clampedFill > 0.12) {
      final sheen = Paint()
        ..shader = LinearGradient(
          begin: Alignment(sheenX - 0.22, -1),
          end: Alignment(sheenX + 0.10, 1),
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: sheenOpacity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(inner);
      canvas.drawRect(inner, sheen);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackbarShelfPainter oldDelegate) {
    return fillLevel != oldDelegate.fillLevel ||
        bottleCount != oldDelegate.bottleCount ||
        backRowCount != oldDelegate.backRowCount ||
        spacingTightness != oldDelegate.spacingTightness ||
        sheenX != oldDelegate.sheenX ||
        sheenOpacity != oldDelegate.sheenOpacity;
  }
}

class _BottleTemplateLibrary {
  static final List<Path> templates = <Path>[
    _tallClassic(),
    _bourgogne(),
    _roundShoulder(),
    _flaskSlim(),
    _apothecary(),
  ];

  static Path _tallClassic() {
    return Path()
      ..moveTo(0.40, 0.0)
      ..lineTo(0.60, 0.0)
      ..lineTo(0.60, 0.16)
      ..cubicTo(0.76, 0.25, 0.84, 0.37, 0.84, 0.54)
      ..lineTo(0.84, 1.0)
      ..lineTo(0.16, 1.0)
      ..lineTo(0.16, 0.54)
      ..cubicTo(0.16, 0.37, 0.24, 0.25, 0.40, 0.16)
      ..close();
  }

  static Path _bourgogne() {
    return Path()
      ..moveTo(0.38, 0.0)
      ..lineTo(0.62, 0.0)
      ..lineTo(0.62, 0.13)
      ..cubicTo(0.83, 0.24, 0.92, 0.42, 0.88, 0.60)
      ..lineTo(0.84, 1.0)
      ..lineTo(0.16, 1.0)
      ..lineTo(0.12, 0.60)
      ..cubicTo(0.08, 0.42, 0.17, 0.24, 0.38, 0.13)
      ..close();
  }

  static Path _roundShoulder() {
    return Path()
      ..moveTo(0.42, 0.0)
      ..lineTo(0.58, 0.0)
      ..lineTo(0.58, 0.16)
      ..cubicTo(0.80, 0.23, 0.93, 0.40, 0.90, 0.62)
      ..lineTo(0.86, 1.0)
      ..lineTo(0.14, 1.0)
      ..lineTo(0.10, 0.62)
      ..cubicTo(0.07, 0.40, 0.20, 0.23, 0.42, 0.16)
      ..close();
  }

  static Path _flaskSlim() {
    return Path()
      ..moveTo(0.44, 0.0)
      ..lineTo(0.56, 0.0)
      ..lineTo(0.56, 0.17)
      ..lineTo(0.70, 0.30)
      ..lineTo(0.72, 1.0)
      ..lineTo(0.28, 1.0)
      ..lineTo(0.30, 0.30)
      ..lineTo(0.44, 0.17)
      ..close();
  }

  static Path _apothecary() {
    return Path()
      ..moveTo(0.35, 0.0)
      ..lineTo(0.65, 0.0)
      ..lineTo(0.65, 0.11)
      ..lineTo(0.78, 0.22)
      ..lineTo(0.82, 1.0)
      ..lineTo(0.18, 1.0)
      ..lineTo(0.22, 0.22)
      ..lineTo(0.35, 0.11)
      ..close();
  }
}

class _UnlockPreviewCard extends StatelessWidget {
  final Cocktail cocktail;
  final bool showName;

  const _UnlockPreviewCard({required this.cocktail, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final basePath =
        cocktail.imagePath ??
        ImageUtils.generateBasePathFromName(cocktail.name);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.surfaceLight.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentGold.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: 0.6,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FutureBuilder<String?>(
              future: ImageUtils.findCocktailImage(basePath),
              builder: (context, snapshot) {
                final path = snapshot.data;
                if (path == null) {
                  return Container(
                    color: AppTheme.surfaceLight.withValues(alpha: 0.2),
                    child: const Center(
                      child: Icon(
                        Icons.local_bar_rounded,
                        color: AppTheme.textSecondary,
                        size: 22,
                      ),
                    ),
                  );
                }
                return Image.asset(
                  path,
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              },
            ),
          ),
          if (showName)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                cocktail.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedUnlockReveal extends StatelessWidget {
  final Widget child;

  const _AnimatedUnlockReveal({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.97, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  RAIL CELL — one category shelf section
// ═══════════════════════════════════════════════════════════════════════════════

class _RailCell extends StatefulWidget {
  final String category;
  final int stocked;
  final int target;
  final bool isActive;
  final bool justCompleted;
  final double warmth;

  const _RailCell({
    required this.category,
    required this.stocked,
    required this.target,
    required this.isActive,
    required this.justCompleted,
    required this.warmth,
  });

  @override
  State<_RailCell> createState() => _RailCellState();
}

class _RailCellState extends State<_RailCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 70),
        ]).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
        );
    _glowOpacity = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.5), weight: 25),
        TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.0), weight: 75),
      ],
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _RailCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.justCompleted && !oldWidget.justCompleted) {
      _pulseController.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFull = widget.stocked >= widget.target;
    final isEmpty = widget.stocked == 0;
    final bottles =
        _categoryBottles[widget.category] ??
        [const _BottleSpec(_BottleShape.box)];
    final filledCount = min(widget.stocked, widget.target);

    // Shelf surface color evolves with warmth + completion
    final shelfColor = isFull
        ? Color.lerp(
            AppTheme.accentGold.withValues(alpha: 0.30),
            AppTheme.accentGold.withValues(alpha: 0.45),
            widget.warmth,
          )!
        : Color.lerp(
            AppTheme.surfaceLight.withValues(alpha: 0.35),
            AppTheme.surfaceLight.withValues(alpha: 0.50),
            widget.warmth,
          )!;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final activeScale = widget.isActive ? 1.015 : 1.0;
        return Transform.scale(
          scale: widget.isActive
              ? _pulseScale.value *
                    activeScale // active cells sit forward
              : _pulseScale.value,
          child: Container(
            width: 72,
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            decoration: BoxDecoration(
              // Active state stays visibly forward at a glance.
              color: widget.isActive
                  ? AppTheme.accentGold.withValues(alpha: 0.075)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isActive
                    ? AppTheme.accentGold.withValues(alpha: 0.24)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: [
                if (_pulseController.isAnimating)
                  BoxShadow(
                    color: AppTheme.accentGold.withValues(
                      alpha: _glowOpacity.value * 0.25,
                    ),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                // Active under-glow (always, not just on pulse)
                if (widget.isActive)
                  BoxShadow(
                    color: AppTheme.accentGold.withValues(alpha: 0.12),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Recessed alcove creates clear depth behind bottles.
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(3, 2, 3, 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.16),
                                Colors.black.withValues(alpha: 0.24),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.035),
                            ),
                          ),
                        ),
                      ),
                      if (isFull)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(5, 5, 5, 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: RadialGradient(
                                  center: const Alignment(0, 0.28),
                                  radius: 0.95,
                                  colors: [
                                    AppTheme.accentGold.withValues(alpha: 0.09),
                                    AppTheme.accentGold.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _BottleRow(
                            specs: bottles,
                            filledCount: filledCount,
                            isFull: isFull,
                            isEmpty: isEmpty,
                            warmth: widget.warmth,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (isFull)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.fromLTRB(5, 0, 5, 1.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppTheme.accentGold.withValues(alpha: 0.42),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGold.withValues(alpha: 0.18),
                          blurRadius: 4,
                          spreadRadius: 0.2,
                        ),
                      ],
                    ),
                  ),

                // Shelf ledge reads as a physical edge.
                _ShelfLedge(color: shelfColor),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Three-layer shelf ledge: highlight, surface, shadow.
class _ShelfLedge extends StatelessWidget {
  final Color color;
  const _ShelfLedge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top highlight (light catch)
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          color: color.withValues(alpha: min(color.a + 0.18, 1.0)),
        ),
        // Surface
        Container(
          height: 3.2,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(0.7),
          ),
        ),
        // Under-shadow
        Container(
          height: 1.4,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(0.7),
          ),
        ),
      ],
    );
  }
}

/// Deterministic static grain for subtle tactile depth in the bar interior.
class _StaticGrainPainter extends CustomPainter {
  final int seed;
  final double opacity;
  final int step;

  const _StaticGrainPainter({
    required this.seed,
    required this.opacity,
    this.step = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = Colors.black.withValues(alpha: opacity);
    final light = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.45);

    for (int y = 0; y < size.height.toInt(); y += step) {
      for (int x = 0; x < size.width.toInt(); x += step) {
        final hash = _hash2D(x, y, seed);
        if ((hash & 31) == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            dark,
          );
        } else if ((hash & 63) == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            light,
          );
        }
      }
    }
  }

  int _hash2D(int x, int y, int seed) {
    int h = x * 374761393 + y * 668265263 + seed * 1442695041;
    h = (h ^ (h >> 13)) * 1274126177;
    return h ^ (h >> 16);
  }

  @override
  bool shouldRepaint(covariant _StaticGrainPainter oldDelegate) {
    return seed != oldDelegate.seed ||
        opacity != oldDelegate.opacity ||
        step != oldDelegate.step;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  BOTTLE ROW — organic spacing via per-bottle specs
// ═══════════════════════════════════════════════════════════════════════════════

class _BottleRow extends StatelessWidget {
  final List<_BottleSpec> specs;
  final int filledCount;
  final bool isFull;
  final bool isEmpty;
  final double warmth;

  const _BottleRow({
    required this.specs,
    required this.filledCount,
    required this.isFull,
    required this.isEmpty,
    required this.warmth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(specs.length, (i) {
        final spec = specs[i];
        final isFilled = i < filledCount;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spec.hMargin),
          child: _AnimatedBottle(
            spec: spec,
            isFilled: isFilled,
            isCategoryFull: isFull,
            index: i,
            warmth: warmth,
          ),
        );
      }),
    );
  }
}

class _AnimatedBottle extends StatefulWidget {
  final _BottleSpec spec;
  final bool isFilled;
  final bool isCategoryFull;
  final int index;
  final double warmth;

  const _AnimatedBottle({
    required this.spec,
    required this.isFilled,
    required this.isCategoryFull,
    required this.index,
    required this.warmth,
  });

  @override
  State<_AnimatedBottle> createState() => _AnimatedBottleState();
}

class _AnimatedBottleState extends State<_AnimatedBottle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _placementY;
  late Animation<double> _presence;
  late Animation<double> _shimmerSweep;
  late Animation<double> _shimmerOpacity;
  bool _wasFilledBefore = false;

  @override
  void initState() {
    super.initState();
    _wasFilledBefore = widget.isFilled;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 340 + widget.index * 25),
    );

    // Bottle physically rises from below the shelf, overshoots, then settles.
    _placementY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 10.0,
          end: -2.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 80,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -2.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_controller);
    _presence = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
    );
    _shimmerSweep = Tween<double>(begin: -0.7, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.34, 0.92, curve: Curves.easeOutCubic),
      ),
    );
    _shimmerOpacity =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.38), weight: 35),
          TweenSequenceItem(tween: Tween(begin: 0.38, end: 0.0), weight: 65),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.34, 1.0, curve: Curves.easeOut),
          ),
        );

    if (widget.isFilled) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedBottle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFilled && !_wasFilledBefore) {
      _controller.forward(from: 0);
      _wasFilledBefore = true;
    } else if (!widget.isFilled && _wasFilledBefore) {
      _controller.value = 0;
      _wasFilledBefore = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseSize = _baseBottleSize(widget.spec.shape);
    final size = Size(
      baseSize.width,
      baseSize.height * widget.spec.heightScale,
    );

    // Filled bottle color warms subtly with overall bar warmth
    final filledColor = widget.isCategoryFull
        ? Color.lerp(
            AppTheme.accentGold.withValues(alpha: 0.65),
            AppTheme.accentGold.withValues(alpha: 0.85),
            widget.warmth,
          )!
        : Color.lerp(
            AppTheme.textSecondary.withValues(alpha: 0.40),
            AppTheme.textSecondary.withValues(alpha: 0.55),
            widget.warmth,
          )!;

    return SizedBox(
      width: size.width,
      height: size.height + 2, // +2 for base shadow
      child: ClipRect(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Ghost slot
            Positioned(
              bottom: 2,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: _BottlePainter(
                    shape: widget.spec.shape,
                    color: AppTheme.surfaceLight.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),

            // Filled bottle placement + one-time shimmer sweep.
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final visible = widget.isFilled || _controller.value > 0.0;
                if (!visible) return const SizedBox.shrink();

                return Transform.translate(
                  offset: Offset(0, _placementY.value),
                  child: Opacity(
                    opacity: _presence.value,
                    child: SizedBox(
                      width: size.width,
                      height: size.height + 2,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Positioned(
                            bottom: 2,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: size,
                                painter: _BottlePainter(
                                  shape: widget.spec.shape,
                                  color: filledColor,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            child: Opacity(
                              opacity: _shimmerOpacity.value,
                              child: ShaderMask(
                                blendMode: BlendMode.srcATop,
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    begin: Alignment(
                                      _shimmerSweep.value - 0.25,
                                      -1,
                                    ),
                                    end: Alignment(
                                      _shimmerSweep.value + 0.12,
                                      1,
                                    ),
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.95),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ).createShader(bounds);
                                },
                                child: CustomPaint(
                                  size: size,
                                  painter: _BottlePainter(
                                    shape: widget.spec.shape,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            child: Container(
                              width: size.width + 2,
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 2,
                                    offset: const Offset(0, 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Size _baseBottleSize(_BottleShape shape) {
    switch (shape) {
      case _BottleShape.tallSlim:
        return const Size(10, 30);
      case _BottleShape.squat:
        return const Size(12, 22);
      case _BottleShape.round:
        return const Size(12, 20);
      case _BottleShape.dropper:
        return const Size(8, 24);
      case _BottleShape.wedge:
        return const Size(12, 16);
      case _BottleShape.jar:
        return const Size(12, 18);
      case _BottleShape.cup:
        return const Size(14, 16);
      case _BottleShape.box:
        return const Size(14, 18);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  BOTTLE SILHOUETTE PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

class _BottlePainter extends CustomPainter {
  final _BottleShape shape;
  final Color color;

  _BottlePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    switch (shape) {
      case _BottleShape.tallSlim:
        _drawTallSlim(canvas, paint, w, h);
      case _BottleShape.squat:
        _drawSquat(canvas, paint, w, h);
      case _BottleShape.round:
        _drawRound(canvas, paint, w, h);
      case _BottleShape.dropper:
        _drawDropper(canvas, paint, w, h);
      case _BottleShape.wedge:
        _drawWedge(canvas, paint, w, h);
      case _BottleShape.jar:
        _drawJar(canvas, paint, w, h);
      case _BottleShape.cup:
        _drawCup(canvas, paint, w, h);
      case _BottleShape.box:
        _drawBox(canvas, paint, w, h);
    }
  }

  void _drawTallSlim(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      ..moveTo(w * 0.35, 0)
      ..lineTo(w * 0.65, 0)
      ..lineTo(w * 0.65, h * 0.15)
      ..lineTo(w * 0.85, h * 0.28)
      ..lineTo(w * 0.85, h)
      ..lineTo(w * 0.15, h)
      ..lineTo(w * 0.15, h * 0.28)
      ..lineTo(w * 0.35, h * 0.15)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawSquat(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      ..moveTo(w * 0.35, 0)
      ..lineTo(w * 0.65, 0)
      ..lineTo(w * 0.65, h * 0.12)
      ..lineTo(w * 0.9, h * 0.3)
      ..lineTo(w * 0.9, h)
      ..lineTo(w * 0.1, h)
      ..lineTo(w * 0.1, h * 0.3)
      ..lineTo(w * 0.35, h * 0.12)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawRound(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      ..moveTo(w * 0.35, 0)
      ..lineTo(w * 0.65, 0)
      ..lineTo(w * 0.65, h * 0.15)
      ..quadraticBezierTo(w, h * 0.35, w * 0.9, h * 0.6)
      ..lineTo(w * 0.85, h)
      ..lineTo(w * 0.15, h)
      ..lineTo(w * 0.1, h * 0.6)
      ..quadraticBezierTo(0, h * 0.35, w * 0.35, h * 0.15)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawDropper(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.2, 0, w * 0.6, h * 0.12),
          const Radius.circular(1.5),
        ),
      )
      ..moveTo(w * 0.3, h * 0.12)
      ..lineTo(w * 0.7, h * 0.12)
      ..lineTo(w * 0.7, h * 0.25)
      ..lineTo(w * 0.8, h * 0.32)
      ..lineTo(w * 0.8, h)
      ..lineTo(w * 0.2, h)
      ..lineTo(w * 0.2, h * 0.32)
      ..lineTo(w * 0.3, h * 0.25)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawWedge(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      ..moveTo(w * 0.5, h * 0.1)
      ..quadraticBezierTo(w * 0.95, h * 0.2, w * 0.9, h * 0.7)
      ..quadraticBezierTo(w * 0.7, h, w * 0.5, h)
      ..quadraticBezierTo(w * 0.3, h, w * 0.1, h * 0.7)
      ..quadraticBezierTo(w * 0.05, h * 0.2, w * 0.5, h * 0.1)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawJar(Canvas canvas, Paint paint, double w, double h) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.1, 0, w * 0.8, h * 0.15),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.15, w * 0.9, h * 0.85),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  void _drawCup(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      ..moveTo(w * 0.1, h * 0.15)
      ..lineTo(w * 0.7, h * 0.15)
      ..lineTo(w * 0.65, h)
      ..lineTo(w * 0.15, h)
      ..close();
    canvas.drawPath(path, paint);
    final handlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.65, h * 0.25, w * 0.3, h * 0.45),
      -1.2,
      2.4,
      false,
      handlePaint,
    );
  }

  void _drawBox(Canvas canvas, Paint paint, double w, double h) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.1, w * 0.9, h * 0.9),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.0, 0, w, h * 0.15),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BottlePainter oldDelegate) =>
      shape != oldDelegate.shape || color != oldDelegate.color;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  3. SEARCH FIELD
// ═══════════════════════════════════════════════════════════════════════════════

class _IngredientSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;

  const _IngredientSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search ingredients...',
            hintStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppTheme.textSecondary,
              size: 18,
            ),
            suffixIcon: hasQuery
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppTheme.textSecondary,
                      size: 16,
                    ),
                    onPressed: onClear,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  4. INLINE SUGGESTION
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryFilterChips extends StatelessWidget {
  final String? selectedCategory;
  final Map<String, int> stockedCounts;
  final ValueChanged<String?> onSelect;

  const _CategoryFilterChips({
    required this.selectedCategory,
    required this.stockedCounts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accentGold.withValues(alpha: 0.18)
                : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.accentGold.withValues(alpha: 0.42)
                  : AppTheme.surfaceLight.withValues(alpha: 0.75),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? AppTheme.accentGold
                  : AppTheme.textSecondary.withValues(alpha: 0.92),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 34,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(
            label: 'All',
            selected: selectedCategory == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          ...IngredientCategory.allCategories.expand((category) {
            final stocked = stockedCounts[category] ?? 0;
            return [
              chip(
                label: '$category ($stocked)',
                selected: selectedCategory == category,
                onTap: () => onSelect(category),
              ),
              const SizedBox(width: 8),
            ];
          }),
        ],
      ),
    );
  }
}

class _InlineSuggestion extends StatelessWidget {
  final SmartSuggestion suggestion;
  final String modeLabel;
  final bool isBusy;
  final VoidCallback onAdd;
  final VoidCallback onCycleMode;

  const _InlineSuggestion({
    required this.suggestion,
    required this.modeLabel,
    required this.isBusy,
    required this.onAdd,
    required this.onCycleMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCycleMode,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: AppTheme.accentGold.withValues(alpha: 0.5),
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: AppTheme.accentGold.withValues(alpha: 0.6),
              size: 14,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: suggestion.ingredientName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' → ${suggestion.unlocksCount} cocktail${suggestion.unlocksCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isBusy ? null : onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isBusy
                      ? AppTheme.accentGold.withValues(alpha: 0.6)
                      : AppTheme.accentGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isBusy
                    ? const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: AppTheme.primaryDark,
                        ),
                      )
                    : const Text(
                        'ADD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                          letterSpacing: 0.5,
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

// ═══════════════════════════════════════════════════════════════════════════════
//  5. INGREDIENT LIST SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _IngredientListSection extends StatelessWidget {
  final Map<String, List<Ingredient>> groupedIngredients;
  final Set<int> barIngredientIds;
  final Set<int> busyIngredientIds;
  final Future<void> Function(int) onToggle;
  final void Function(int ingredientId, BuildContext context) onTapWithContext;
  final ScrollController scrollController;
  final Map<String, GlobalKey> categoryKeys;

  const _IngredientListSection({
    required this.groupedIngredients,
    required this.barIngredientIds,
    required this.busyIngredientIds,
    required this.onToggle,
    required this.onTapWithContext,
    required this.scrollController,
    required this.categoryKeys,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = groupedIngredients;

    if (grouped.isEmpty) {
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
              'No ingredients found',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    final sortedEntries = <MapEntry<String, List<Ingredient>>>[];
    for (final cat in IngredientCategory.allCategories) {
      if (grouped.containsKey(cat)) {
        sortedEntries.add(MapEntry(cat, grouped[cat]!));
      }
    }

    final sortedByCategory = <String, List<Ingredient>>{};
    for (final entry in sortedEntries) {
      categoryKeys.putIfAbsent(entry.key, () => GlobalKey());
      sortedByCategory[entry.key] = List<Ingredient>.from(entry.value)
        ..sort((a, b) {
          final aS = barIngredientIds.contains(a.id);
          final bS = barIngredientIds.contains(b.id);
          if (aS && !bS) return -1;
          if (!aS && bS) return 1;
          return a.name.compareTo(b.name);
        });
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        for (final entry in sortedEntries) ...[
          SliverPersistentHeader(
            key: categoryKeys[entry.key],
            pinned: true,
            delegate: _StickyHeaderDelegate(
              category: entry.key,
              icon: IngredientCategory.categoryIcons[entry.key] ?? '📦',
              count: entry.value
                  .where((i) => barIngredientIds.contains(i.id))
                  .length,
              total: entry.value.length,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final sorted = sortedByCategory[entry.key] ?? const <Ingredient>[];
              final ingredient = sorted[index];
              final isStocked = barIngredientIds.contains(ingredient.id);
              final isBusy = busyIngredientIds.contains(ingredient.id);
              return _IngredientRow(
                ingredient: ingredient,
                isStocked: isStocked,
                isBusy: isBusy,
                onTap: isBusy ? null : () => onToggle(ingredient.id),
                onTapWithContext: isBusy
                    ? null
                    : (ctx) => onTapWithContext(ingredient.id, ctx),
              );
            }, childCount: (sortedByCategory[entry.key] ?? const <Ingredient>[]).length),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String category;
  final String icon;
  final int count;
  final int total;

  _StickyHeaderDelegate({
    required this.category,
    required this.icon,
    required this.count,
    required this.total,
  });

  @override
  double get minExtent => 36;
  @override
  double get maxExtent => 36;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppTheme.primaryDark,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Text(
            category.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count/$total',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 0.5, color: AppTheme.surfaceLight)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      category != oldDelegate.category ||
      count != oldDelegate.count ||
      total != oldDelegate.total;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  INGREDIENT ROW
// ═══════════════════════════════════════════════════════════════════════════════

class _IngredientRow extends StatefulWidget {
  final Ingredient ingredient;
  final bool isStocked;
  final bool isBusy;
  final VoidCallback? onTap;
  final void Function(BuildContext ctx)? onTapWithContext;

  const _IngredientRow({
    required this.ingredient,
    required this.isStocked,
    required this.isBusy,
    required this.onTap,
    required this.onTapWithContext,
  });

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.0).animate(_scaleController);
  }

  @override
  void didUpdateWidget(covariant _IngredientRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStocked != oldWidget.isStocked) {
      _scaleController.reset();
      _scale =
          TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03), weight: 40),
            TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 60),
          ]).animate(
            CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
          );
      _scaleController.forward();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: InkWell(
        onTap: widget.onTap == null
            ? null
            : () {
                widget.onTapWithContext?.call(context);
                widget.onTap?.call();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: widget.isStocked
                ? AppTheme.accentGold.withValues(alpha: 0.05)
                : Colors.transparent,
            border: const Border(
              bottom: BorderSide(color: AppTheme.surfaceLight, width: 0.3),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: widget.isBusy
                      ? AppTheme.surfaceDark
                      : widget.isStocked
                      ? AppTheme.accentGold
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: widget.isBusy
                        ? AppTheme.accentGold.withValues(alpha: 0.6)
                        : widget.isStocked
                        ? AppTheme.accentGold
                        : AppTheme.surfaceLight,
                    width: 1.5,
                  ),
                ),
                child: widget.isBusy
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.7,
                          color: AppTheme.accentGold,
                        ),
                      )
                    : widget.isStocked
                    ? const Icon(
                        Icons.check,
                        color: AppTheme.primaryDark,
                        size: 15,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.ingredient.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.isStocked
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: widget.isStocked
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
              if (IngredientSubstitutions.getSubstitutes(
                widget.ingredient.name,
              ).isNotEmpty)
                Tooltip(
                  message: 'Has substitutions',
                  child: Icon(
                    Icons.swap_horiz,
                    size: 14,
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


