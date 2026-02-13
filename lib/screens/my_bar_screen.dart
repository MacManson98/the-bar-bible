import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import '../core/theme/app_theme.dart';
import '../core/utils/bar_analytics.dart';
import '../data/database.dart';
import '../data/ingredient_data.dart';
import 'achievements_screen.dart';

typedef BarChangedCallback = void Function();

// ═══════════════════════════════════════════════════════════════════════════════
//  SHELF CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

const Map<String, int> _coreShelfTargets = {
  'Spirits': 4,
  'Liqueurs': 3,
  'Citrus': 2,
  'Juices': 2,
  'Sweeteners': 2,
  'Mixers': 2,
  'Bitters': 2,
  'Coffee': 1,
  'Other': 1,
};

int get _totalShelfTarget => _coreShelfTargets.values.fold(0, (a, b) => a + b);

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

/// Ambient warmth: as bar fills, the environment subtly warms.
/// Returns 0.0 (empty) to 1.0 (fully stocked).
double _barWarmth(Map<String, int> counts) {
  int filled = 0;
  int total = 0;
  for (final cat in IngredientCategory.allCategories) {
    final stocked = counts[cat] ?? 0;
    final target = _coreShelfTargets[cat] ?? 2;
    filled += min(stocked, target);
    total += target;
  }
  return total > 0 ? (filled / total).clamp(0.0, 1.0) : 0.0;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class MyBarScreen extends StatefulWidget {
  final AppDatabase database;
  final BarChangedCallback? onBarChanged;
  final VoidCallback? onNavigateToFinder;

  const MyBarScreen({
    super.key,
    required this.database,
    this.onBarChanged,
    this.onNavigateToFinder,
  });

  @override
  State<MyBarScreen> createState() => _MyBarScreenState();
}

class _MyBarScreenState extends State<MyBarScreen>
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

  final ScrollController _listScrollController = ScrollController();
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
  Map<String, int> _prevCategoryCounts = {};
  Set<String> _earnedAchievementKeys = {};

  @override
  void initState() {
    super.initState();
    _barAnalytics = BarAnalytics(widget.database);

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
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    _headerAnimController.dispose();
    _unlockAnimController.dispose();
    _counterAnimController.dispose();
    _unlockOverlay?.remove();
    super.dispose();
  }

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

    setState(() {
      _allIngredients = ingredients;
      _activeBar = activeBar;
      _savedBars = bars;
      _barIngredientIds = barIds;
      _analytics = analytics;
      _isLoading = false;
    });
    _earnedAchievementKeys = _earnedAchievementSetForCount(
      _barIngredientIds.length,
    );

    _headerAnimController.forward();
  }

  Future<void> _refreshAnalytics() async {
    _prevCategoryCounts = Map.from(_categoryCounts);
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

  int get _earnedAchievementCount =>
      _earnedAchievementSetForCount(_barIngredientIds.length).length;

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

  Future<void> _toggleIngredient(int ingredientId, {GlobalKey? rowKey}) async {
    if (_activeBar == null) return;
    HapticFeedback.lightImpact();

    final isAdding = !_barIngredientIds.contains(ingredientId);
    int delta = 0;
    if (isAdding) {
      delta = await _barAnalytics.computeUnlockDelta(ingredientId, true);
    }

    if (_barIngredientIds.contains(ingredientId)) {
      await (widget.database.delete(widget.database.savedBarIngredients)..where(
            (bi) =>
                bi.savedBarId.equals(_activeBar!.id) &
                bi.ingredientId.equals(ingredientId),
          ))
          .go();
      setState(() => _barIngredientIds.remove(ingredientId));
    } else {
      await widget.database
          .into(widget.database.savedBarIngredients)
          .insert(
            SavedBarIngredientsCompanion.insert(
              savedBarId: _activeBar!.id,
              ingredientId: ingredientId,
            ),
          );
      setState(() => _barIngredientIds.add(ingredientId));
    }

    if (isAdding && delta > 0 && rowKey != null) {
      _showUnlockDelta(delta, rowKey);
    }

    widget.onBarChanged?.call();
    _refreshAnalytics();
  }

  void _showUnlockDelta(int delta, GlobalKey rowKey) {
    _unlockOverlay?.remove();
    final renderBox = rowKey.currentContext?.findRenderObject() as RenderBox?;
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

  Future<void> _loadPreset(String presetName) async {
    if (_activeBar == null) return;
    final presetIngredientNames = BarPresets.getPreset(presetName);
    if (presetIngredientNames.isEmpty) return;

    final matchedIds = <int>{};
    for (final name in presetIngredientNames) {
      final match = _allIngredients.where(
        (i) => i.name.toLowerCase() == name.toLowerCase(),
      );
      if (match.isNotEmpty) matchedIds.add(match.first.id);
    }

    await (widget.database.delete(
      widget.database.savedBarIngredients,
    )..where((bi) => bi.savedBarId.equals(_activeBar!.id))).go();

    for (final id in matchedIds) {
      await widget.database
          .into(widget.database.savedBarIngredients)
          .insert(
            SavedBarIngredientsCompanion.insert(
              savedBarId: _activeBar!.id,
              ingredientId: id,
            ),
          );
    }

    setState(() => _barIngredientIds = matchedIds);
    widget.onBarChanged?.call();
    _refreshAnalytics();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Loaded "$presetName" — ${matchedIds.length} ingredients',
          ),
          backgroundColor: AppTheme.surfaceDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _clearBar() async {
    if (_activeBar == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'Clear Bar',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Remove all ingredients from your bar?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppTheme.accentGold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await (widget.database.delete(
      widget.database.savedBarIngredients,
    )..where((bi) => bi.savedBarId.equals(_activeBar!.id))).go();
    setState(() => _barIngredientIds.clear());
    widget.onBarChanged?.call();
    _refreshAnalytics();
  }

  Future<void> _switchToBar(int barId) async {
    await (widget.database.update(widget.database.savedBars)
          ..where((b) => b.isDefault.equals(true)))
        .write(const SavedBarsCompanion(isDefault: Value(false)));
    await (widget.database.update(
      widget.database.savedBars,
    )..where((b) => b.id.equals(barId))).write(
      SavedBarsCompanion(
        isDefault: const Value(true),
        lastUsed: Value(DateTime.now()),
      ),
    );

    final active = await (widget.database.select(
      widget.database.savedBars,
    )..where((b) => b.id.equals(barId))).getSingle();
    final ingredients = await widget.database.getSavedBarIngredients(barId);
    final bars = await (widget.database.select(
      widget.database.savedBars,
    )..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();

    if (!mounted) return;
    setState(() {
      _activeBar = active;
      _savedBars = bars;
      _barIngredientIds = ingredients.map((i) => i.id).toSet();
      _activeShelfCategory = null;
      _searchQuery = '';
      _searchController.clear();
    });

    widget.onBarChanged?.call();
    _refreshAnalytics();
  }

  Future<String?> _showBarNameDialog({
    required String title,
    required String actionLabel,
    String hintText = 'Bar name',
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.primaryDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              actionLabel,
              style: const TextStyle(color: AppTheme.accentGold),
            ),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  Future<void> _saveCurrentBarAsNew() async {
    final name = await _showBarNameDialog(
      title: 'Save As New Bar',
      actionLabel: 'Save',
      hintText: 'e.g., Home Classic Setup',
    );
    if (name == null) return;

    int? newBarId;
    await widget.database.transaction(() async {
      newBarId = await widget.database
          .into(widget.database.savedBars)
          .insert(
            SavedBarsCompanion.insert(
              name: name,
              lastUsed: Value(DateTime.now()),
            ),
          );
      for (final ingredientId in _barIngredientIds) {
        await widget.database
            .into(widget.database.savedBarIngredients)
            .insert(
              SavedBarIngredientsCompanion.insert(
                savedBarId: newBarId!,
                ingredientId: ingredientId,
              ),
            );
      }
    });
    if (newBarId == null) return;

    await _switchToBar(newBarId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "$name" as a new bar'),
        backgroundColor: AppTheme.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _onShelfCategoryTap(String category) {
    if (_activeShelfCategory == category) {
      setState(() => _activeShelfCategory = null);
    } else {
      _activateCategoryFilter(category);
    }
  }

  void _activateCategoryFilter(String category) {
    setState(() {
      _activeShelfCategory = category;
      _searchQuery = '';
      _searchController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _categoryKeys[category];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          alignment: 0.0,
        );
      }
    });
  }

  void _swipeIngredientCategory({required bool forward}) {
    const categories = IngredientCategory.allCategories;
    if (categories.isEmpty) return;

    final currentIndex = _activeShelfCategory == null
        ? -1
        : categories.indexOf(_activeShelfCategory!);

    int nextIndex;
    if (currentIndex < 0) {
      nextIndex = forward ? 0 : categories.length - 1;
    } else {
      nextIndex = (currentIndex + (forward ? 1 : -1)) % categories.length;
      if (nextIndex < 0) nextIndex += categories.length;
    }

    final nextCategory = categories[nextIndex];
    HapticFeedback.selectionClick();
    _activateCategoryFilter(nextCategory);
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
    final map = <String, int>{};
    for (final i in _allIngredients) {
      if (_barIngredientIds.contains(i.id)) {
        map[i.category] = (map[i.category] ?? 0) + 1;
      }
    }
    return map;
  }

  int get _totalShelfSlotsFilled {
    int filled = 0;
    for (final cat in IngredientCategory.allCategories) {
      final stocked = _categoryCounts[cat] ?? 0;
      final target = _coreShelfTargets[cat] ?? 2;
      filled += min(stocked, target);
    }
    return filled;
  }

  String get _milestoneMessage {
    final level = _analytics?.barLevel ?? BarLevel.empty;
    final count = _barIngredientIds.length;
    final next = level.nextThreshold;
    if (level == BarLevel.professional) {
      return 'Full setup · ${_analytics?.exactMatchCount ?? 0} cocktails unlocked';
    }
    final remaining = next - count;
    if (remaining <= 0) return '';
    const levels = BarLevel.values;
    final nextIndex = level.index + 1;
    if (nextIndex >= levels.length) return '';
    final nextLevel = levels[nextIndex];
    return '$remaining more to ${nextLevel.label}';
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

    final analytics = _analytics ?? BarAnalyticsResult.empty();
    final counts = _categoryCounts;
    final warmth = _barWarmth(counts);

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── 1+2. Unified ambient zone: header + bar rail ──
            FadeTransition(
              opacity: _headerFade,
              child: _BarInteriorZone(
                level: analytics.barLevel,
                milestoneMessage: _milestoneMessage,
                shelfFilled: _totalShelfSlotsFilled,
                shelfTotal: _totalShelfTarget,
                badgeCount: _earnedAchievementCount,
                activeBarId: _activeBar?.id,
                savedBars: _savedBars,
                warmth: warmth,
                categoryCounts: counts,
                prevCategoryCounts: _prevCategoryCounts,
                activeCategory: _activeShelfCategory,
                onBadgesTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                ),
                onPresetSelected: (value) {
                  if (value == 'clear') {
                    _clearBar();
                  } else if (value == 'save_as_new_bar') {
                    _saveCurrentBarAsNew();
                  } else if (value.startsWith('bar:')) {
                    final id = int.tryParse(value.substring(4));
                    if (id != null) _switchToBar(id);
                  } else if (value.startsWith('preset:')) {
                    _loadPreset(value.substring(7));
                  }
                },
                onShelfCategoryTap: _onShelfCategoryTap,
              ),
            ),

            // ── 3. Search ──
            _IngredientSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (v) => setState(() {
                _searchQuery = v;
                if (v.isNotEmpty) _activeShelfCategory = null;
              }),
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              hasQuery: _searchQuery.isNotEmpty,
            ),

            // ── 4. Smart suggestion ──
            if (_analytics?.suggestion != null && _barIngredientIds.isNotEmpty)
              _InlineSuggestion(
                suggestion: _analytics!.suggestion!,
                modeLabel: _suggestionLabels[_suggestionMode],
                onAdd: () async {
                  final match = _allIngredients.where(
                    (i) =>
                        IngredientEquivalence.normalise(i.name) ==
                        _analytics!.suggestion!.canonicalName,
                  );
                  if (match.isNotEmpty &&
                      !_barIngredientIds.contains(match.first.id)) {
                    await _toggleIngredient(match.first.id);
                    HapticFeedback.mediumImpact();
                  }
                },
                onCycleMode: () {
                  setState(() {
                    _suggestionMode = (_suggestionMode + 1) % 3;
                  });
                },
              ),

            // ── 5. Ingredient list ──
            Expanded(
              child: _IngredientListSection(
                groupedIngredients: _groupedIngredients,
                barIngredientIds: _barIngredientIds,
                onToggle: _toggleIngredient,
                scrollController: _listScrollController,
                categoryKeys: _categoryKeys,
                onSwipeCategory: _swipeIngredientCategory,
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

class _BarInteriorZone extends StatelessWidget {
  final BarLevel level;
  final String milestoneMessage;
  final int shelfFilled;
  final int shelfTotal;
  final int badgeCount;
  final int? activeBarId;
  final List<SavedBar> savedBars;
  final double warmth; // 0.0–1.0 ambient warmth
  final Map<String, int> categoryCounts;
  final Map<String, int> prevCategoryCounts;
  final String? activeCategory;
  final VoidCallback onBadgesTap;
  final ValueChanged<String> onPresetSelected;
  final ValueChanged<String> onShelfCategoryTap;

  const _BarInteriorZone({
    required this.level,
    required this.milestoneMessage,
    required this.shelfFilled,
    required this.shelfTotal,
    required this.badgeCount,
    required this.activeBarId,
    required this.savedBars,
    required this.warmth,
    required this.categoryCounts,
    required this.prevCategoryCounts,
    required this.activeCategory,
    required this.onBadgesTap,
    required this.onPresetSelected,
    required this.onShelfCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    // Ambient warmth tints the entire zone as bar fills
    final warmColor = Color.lerp(
      const Color(0xFF1E1E1E), // cold/empty
      const Color(0xFF2A2010), // warm amber
      warmth * 0.6, // subtle — never goes full warm
    )!;

    final borderRadius = BorderRadius.circular(14);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: AppTheme.accentGold.withValues(alpha: 0.05 + warmth * 0.06),
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.surfaceDark, warmColor],
                  ),
                ),
              ),
            ),
            // Stable low-opacity grain keeps the interior feeling tactile.
            const Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _StaticGrainPainter(
                      seed: 27,
                      opacity: 0.03,
                      step: 4,
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 12, 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 430;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGold.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppTheme.accentGold.withValues(
                                        alpha: 0.20,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${level.icon}  ${level.label}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentGold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _BadgesPillButton(
                                badgeCount: badgeCount,
                                onTap: onBadgesTap,
                                compact: compact,
                              ),
                              const SizedBox(width: 4),
                              _PresetsPillButton(
                                onSelected: onPresetSelected,
                                savedBars: savedBars,
                                activeBarId: activeBarId,
                                compact: compact,
                              ),
                            ],
                          ),
                          if (milestoneMessage.isNotEmpty) ...[
                            const SizedBox(height: 9),
                            Text(
                              milestoneMessage,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.68,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),

                // ── Progress bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0.0,
                        end: shelfTotal > 0
                            ? (shelfFilled / shelfTotal).clamp(0.0, 1.0)
                            : 0.0,
                      ),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        backgroundColor: AppTheme.surfaceLight.withValues(
                          alpha: 0.35,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppTheme.accentGold,
                        ),
                        minHeight: 2,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 7, 14, 0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.accentGold.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            size: 16,
                            color: AppTheme.accentGold.withValues(alpha: 0.72),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppTheme.accentGold.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Swipe across categories',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.82,
                              ),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ── Bar rail (bottles on shelf) ──
                SizedBox(
                  height: 80,
                  child: RepaintBoundary(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: IngredientCategory.allCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 2),
                      itemBuilder: (context, index) {
                        final cat = IngredientCategory.allCategories[index];
                        final stocked = categoryCounts[cat] ?? 0;
                        final target = _coreShelfTargets[cat] ?? 2;
                        final isActive = activeCategory == cat;
                        final prevStocked = prevCategoryCounts[cat] ?? 0;
                        final justCompleted =
                            prevStocked < target && stocked >= target;

                        return GestureDetector(
                          onTap: () => onShelfCategoryTap(cat),
                          behavior: HitTestBehavior.opaque,
                          child: _RailCell(
                            category: cat,
                            stocked: stocked,
                            target: target,
                            isActive: isActive,
                            justCompleted: justCompleted,
                            warmth: warmth,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesPillButton extends StatelessWidget {
  final int badgeCount;
  final bool compact;
  final VoidCallback onTap;

  const _BadgesPillButton({
    required this.badgeCount,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HeaderPillButton(
      icon: Icons.emoji_events_outlined,
      label: 'Achievements',
      trailing: Container(
        constraints: const BoxConstraints(minWidth: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentGold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: AppTheme.accentGold.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          '$badgeCount',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.accentGold,
          ),
        ),
      ),
      onTap: onTap,
      compact: compact,
    );
  }
}

class _PresetsPillButton extends StatelessWidget {
  final ValueChanged<String> onSelected;
  final List<SavedBar> savedBars;
  final int? activeBarId;
  final bool compact;

  const _PresetsPillButton({
    required this.onSelected,
    required this.savedBars,
    required this.activeBarId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _HeaderPillButton(
      label: 'Presets',
      icon: null,
      trailing: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: compact ? 16 : 17,
        color: AppTheme.accentGold.withValues(alpha: 0.74),
      ),
      compact: compact,
      onTap: () async {
        final triggerBox = context.findRenderObject() as RenderBox?;
        final overlayBox =
            Overlay.of(context).context.findRenderObject() as RenderBox?;
        if (triggerBox == null || overlayBox == null) return;

        final topLeft = triggerBox.localToGlobal(
          Offset.zero,
          ancestor: overlayBox,
        );
        final bottomRight = triggerBox.localToGlobal(
          triggerBox.size.bottomRight(Offset.zero),
          ancestor: overlayBox,
        );

        final selected = await showMenu<String>(
          context: context,
          color: AppTheme.surfaceDark,
          position: RelativeRect.fromRect(
            Rect.fromPoints(topLeft, bottomRight),
            Offset.zero & overlayBox.size,
          ),
          items: [
            const PopupMenuItem(
              enabled: false,
              child: Text(
                'BARS',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.accentGold,
                  letterSpacing: 1,
                ),
              ),
            ),
            ...savedBars.map((bar) {
              final isActive = bar.id == activeBarId;
              return PopupMenuItem(
                value: 'bar:${bar.id}',
                child: Row(
                  children: [
                    Icon(
                      isActive
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: isActive
                          ? AppTheme.accentGold
                          : AppTheme.textSecondary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 165,
                      child: Text(
                        bar.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isActive
                              ? AppTheme.accentGold
                              : AppTheme.textPrimary,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const PopupMenuItem(
              value: 'save_as_new_bar',
              child: Row(
                children: [
                  Icon(Icons.add, color: AppTheme.accentGold, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Save as New Bar',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              enabled: false,
              child: Text(
                'PRESETS',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.accentGold,
                  letterSpacing: 1,
                ),
              ),
            ),
            ...BarPresets.getAllPresetNames().map(
              (name) => PopupMenuItem(
                value: 'preset:$name',
                child: Text(
                  name,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(
                    Icons.clear_all,
                    color: AppTheme.textSecondary,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Clear All',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        );

        if (selected != null) onSelected(selected);
      },
    );
  }
}

class _HeaderPillButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Widget? trailing;
  final bool compact;
  final VoidCallback onTap;

  const _HeaderPillButton({
    required this.label,
    required this.icon,
    this.trailing,
    this.compact = false,
    required this.onTap,
  });

  @override
  State<_HeaderPillButton> createState() => _HeaderPillButtonState();
}

class _HeaderPillButtonState extends State<_HeaderPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final background = _pressed
        ? AppTheme.surfaceLight.withValues(alpha: 0.12)
        : AppTheme.surfaceLight.withValues(alpha: 0.18);
    final border = _pressed
        ? AppTheme.accentGold.withValues(alpha: 0.16)
        : AppTheme.accentGold.withValues(alpha: 0.13);

    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      scale: _pressed ? 0.98 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 7 : 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            splashColor: AppTheme.accentGold.withValues(alpha: 0.08),
            highlightColor: AppTheme.accentGold.withValues(alpha: 0.06),
            hoverColor: AppTheme.accentGold.withValues(alpha: 0.03),
            onHighlightChanged: (isHighlighted) {
              if (_pressed != isHighlighted) {
                setState(() => _pressed = isHighlighted);
              }
            },
            onTap: widget.onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null)
                  Icon(
                    widget.icon,
                    size: widget.compact ? 16 : 17,
                    color: AppTheme.accentGold.withValues(alpha: 0.76),
                  ),
                if (widget.icon != null && widget.label != null)
                  SizedBox(width: widget.compact ? 4 : 5),
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: widget.compact ? 10.8 : 11.4,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                if (widget.trailing != null) ...[
                  SizedBox(width: widget.label == null ? 4 : 5),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
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
    final hasOverflow = widget.stocked > widget.target;
    final isEmpty = widget.stocked == 0;
    final bottles =
        _categoryBottles[widget.category] ??
        [const _BottleSpec(_BottleShape.box)];
    final filledCount = min(widget.stocked, widget.target);
    final label = _shortLabels[widget.category] ?? widget.category;

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

                const SizedBox(height: 3),

                // ── Label + overflow ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: widget.isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0.15,
                        color: widget.isActive
                            ? AppTheme.accentGold
                            : isEmpty
                            ? AppTheme.textSecondary.withValues(alpha: 0.3)
                            : AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                    if (hasOverflow) ...[
                      const SizedBox(width: 2),
                      Text(
                        '+${widget.stocked - widget.target}',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentGold.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const _shortLabels = {
    'Spirits': 'Spirits',
    'Liqueurs': 'Liqueurs',
    'Citrus': 'Citrus',
    'Juices': 'Juices',
    'Sweeteners': 'Sweets',
    'Mixers': 'Mixers',
    'Bitters': 'Bitters',
    'Coffee': 'Coffee',
    'Other': 'Other',
  };
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

class _InlineSuggestion extends StatelessWidget {
  final SmartSuggestion suggestion;
  final String modeLabel;
  final VoidCallback onAdd;
  final VoidCallback onCycleMode;

  const _InlineSuggestion({
    required this.suggestion,
    required this.modeLabel,
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
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
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
  final Future<void> Function(int, {GlobalKey? rowKey}) onToggle;
  final ScrollController scrollController;
  final Map<String, GlobalKey> categoryKeys;
  final void Function({required bool forward}) onSwipeCategory;

  const _IngredientListSection({
    required this.groupedIngredients,
    required this.barIngredientIds,
    required this.onToggle,
    required this.scrollController,
    required this.categoryKeys,
    required this.onSwipeCategory,
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

    for (final entry in sortedEntries) {
      categoryKeys.putIfAbsent(entry.key, () => GlobalKey());
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity <= -250) {
          onSwipeCategory(forward: true);
        } else if (velocity >= 250) {
          onSwipeCategory(forward: false);
        }
      },
      child: CustomScrollView(
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
                final sorted = List<Ingredient>.from(entry.value)
                  ..sort((a, b) {
                    final aS = barIngredientIds.contains(a.id);
                    final bS = barIngredientIds.contains(b.id);
                    if (aS && !bS) return -1;
                    if (!aS && bS) return 1;
                    return a.name.compareTo(b.name);
                  });
                final ingredient = sorted[index];
                final rowKey = GlobalKey();
                final isStocked = barIngredientIds.contains(ingredient.id);
                return _IngredientRow(
                  key: rowKey,
                  ingredient: ingredient,
                  isStocked: isStocked,
                  onTap: () => onToggle(ingredient.id, rowKey: rowKey),
                );
              }, childCount: entry.value.length),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
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
  final VoidCallback onTap;

  const _IngredientRow({
    super.key,
    required this.ingredient,
    required this.isStocked,
    required this.onTap,
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
        onTap: widget.onTap,
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
                  color: widget.isStocked
                      ? AppTheme.accentGold
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: widget.isStocked
                        ? AppTheme.accentGold
                        : AppTheme.surfaceLight,
                    width: 1.5,
                  ),
                ),
                child: widget.isStocked
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
