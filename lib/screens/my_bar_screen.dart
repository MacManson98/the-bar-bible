import 'dart:async';
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
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/user_sync_service.dart';
import '../widgets/bar_selector_dropdown.dart';
import 'cocktail_detail_screen.dart';

typedef BarChangedCallback = void Function();

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

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
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<Ingredient> _allIngredients = [];
  Set<int> _barIngredientIds = {};
  SavedBar? _activeBar;
  List<SavedBar> _savedBars = [];
  BarAnalyticsResult? _analytics;

  bool _isLoading = true;
  String _searchQuery = '';
  // null = overview; set = category detail
  String? _activeCategoryFilter;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final ScrollController _listScrollController = ScrollController(keepScrollOffset: false);

  // Per-ingredient unlock deltas, populated when entering a category detail view
  Map<int, int> _unlockDeltaCache = {};
  bool _deltaLoading = false;

  late AnimationController _headerAnimController;
  late Animation<double> _headerFade;

  OverlayEntry? _unlockOverlay;
  late AnimationController _unlockAnimController;
  late Animation<double> _unlockFade;
  late Animation<Offset> _unlockSlide;

  late AnimationController _counterAnimController;
  late BarAnalytics _barAnalytics;
  late final BarService _barService;
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

  @override
  void initState() {
    super.initState();
    _barAnalytics = BarAnalytics(widget.database);
    _barService = BarService(widget.database);

    _headerAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade = CurvedAnimation(parent: _headerAnimController, curve: Curves.easeOut);

    _unlockAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _unlockFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_unlockAnimController);
    _unlockSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: const Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _unlockAnimController, curve: Curves.easeOutCubic));

    _counterAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

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

  Future<void> _loadData() async {
    final ingredients = await widget.database.select(widget.database.ingredients).get();
    final bars = await widget.database.select(widget.database.savedBars).get();

    SavedBar? activeBar = await widget.database.getDefaultSavedBar();
    if (activeBar == null && bars.isEmpty) {
      final id = await widget.database.into(widget.database.savedBars).insert(
        SavedBarsCompanion.insert(name: 'My Bar', isDefault: const Value(true)),
      );
      activeBar = await (widget.database.select(widget.database.savedBars)
            ..where((b) => b.id.equals(id)))
          .getSingle();
    }
    activeBar ??= bars.first;

    final barIngredients = await widget.database.getSavedBarIngredients(activeBar.id);
    final barIds = barIngredients.map((i) => i.id).toSet();
    final analytics = await _barAnalytics.compute();

    if (!mounted) return;
    setState(() {
      _allIngredients = ingredients;
      _activeBar = activeBar;
      _savedBars = List<SavedBar>.from(bars)..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      _barIngredientIds = barIds;
      _analytics = analytics;
      _isLoading = false;
    });

    _headerAnimController.forward();
    _scrollIngredientListToTop();
  }

  void _scrollIngredientListToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScrollController.hasClients) return;
      if (_listScrollController.offset <= 0.5) return;
      _listScrollController.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void _setSearchQuery(String value) {
    _searchDebounceTimer?.cancel();
    if (value.isEmpty) {
      if (_searchQuery.isEmpty) return;
      setState(() => _searchQuery = '');
      return;
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || value == _searchQuery) return;
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearchInput() {
    _searchController.clear();
    _setSearchQuery('');
  }

  Future<void> _openCategory(String category) async {
    setState(() {
      _activeCategoryFilter = category;
      _deltaLoading = true;
      _unlockDeltaCache = {};
    });
    _scrollIngredientListToTop();

    final missing = _allIngredients
        .where((i) => i.category == category && !_barIngredientIds.contains(i.id))
        .toList();

    final deltas = <int, int>{};
    for (final ingredient in missing) {
      final delta = await _barAnalytics.computeUnlockDelta(ingredient.id, true);
      deltas[ingredient.id] = delta;
    }

    if (!mounted) return;
    setState(() {
      _unlockDeltaCache = deltas;
      _deltaLoading = false;
    });
  }

  void _closeCategory() {
    setState(() {
      _activeCategoryFilter = null;
      _unlockDeltaCache = {};
      _deltaLoading = false;
    });
    _scrollIngredientListToTop();
  }

  Future<void> _delayForImeSettleIfNeeded() async {
    final last = _lastImeSensitiveEventAt;
    if (last == null) return;
    const settleWindow = Duration(milliseconds: 220);
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= settleWindow) return;
    final wait = settleWindow - elapsed;
    if (kDebugMode) debugPrint('MyBar IME settle delay ${wait.inMilliseconds}ms');
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

  void _markCreateSetState(String reason) => _createDiagnostics?.incrementSetState(reason);

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
    if (last != null && now.difference(last).inMilliseconds < 150) return;
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
        const SnackBar(content: Text('Could not add suggested ingredient. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _suggestionAddsInFlight.remove(canonical));
    }
  }

  Future<void> _refreshAnalytics() async {
    final analytics = await _barAnalytics.compute();
    if (mounted) {
      _counterAnimController.forward(from: 0);
      setState(() => _analytics = analytics);
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
              ..where((bi) =>
                  bi.savedBarId.equals(_activeBar!.id) & bi.ingredientId.equals(ingredientId)))
            .go();
        setState(() => _barIngredientIds.remove(ingredientId));
      } else {
        await widget.database.addIngredientToSavedBar(
          savedBarId: _activeBar!.id,
          ingredientId: ingredientId,
        );
        setState(() => _barIngredientIds.add(ingredientId));
        exactAfter = await _computeExactMatchCocktailIds(_barIngredientIds);
      }

      final anchorContext = _ingredientRowContexts[ingredientId];
      if (isAdding && delta > 0 && anchorContext != null && anchorContext.mounted) {
        _showUnlockDelta(delta, anchorContext);
      }
      if (isAdding) {
        final newlyUnlockedIds = exactAfter.difference(exactBefore);
        if (newlyUnlockedIds.isNotEmpty) _queueUnlockedCocktails(newlyUnlockedIds);
      }

      widget.onBarChanged?.call();
      await _refreshAnalytics();
      _pushBarsToCloud();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update ingredient. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busyIngredientIds.remove(ingredientId));
    }
  }

  Future<void> _ensureMatchDataLoaded() async {
    if (_matchDataLoaded) return;
    final cocktails = await widget.database.select(widget.database.cocktails).get();
    final allCi = await widget.database.select(widget.database.cocktailIngredients).get();
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

  Future<Set<int>> _computeExactMatchCocktailIds(Set<int> barIngredientIds) async {
    await _ensureMatchDataLoaded();
    final ingredientNameById = {for (final i in _allIngredients) i.id: i.name};
    final barCanonicals = <String>{};
    for (final id in barIngredientIds) {
      final name = ingredientNameById[id];
      if (name != null) barCanonicals.add(IngredientEquivalence.normalise(name));
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
        if (!barCanonicals.contains(canon) && !barSubCanonicals.contains(canon)) {
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
    _unlockDebounceTimer = Timer(const Duration(milliseconds: 900), _flushPendingUnlocks);
  }

  void _clearPendingUnlocks() {
    _pendingUnlockedCocktailIds.clear();
    _pendingUnlockCount = 0;
  }

  Future<void> _flushPendingUnlocks() async {
    if (!mounted || _pendingUnlockCount == 0) return;
    if (_unlockSheetOpen) {
      _unlockDebounceTimer?.cancel();
      _unlockDebounceTimer = Timer(const Duration(milliseconds: 350), _flushPendingUnlocks);
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
      _suppressUnlockSheetUntil = DateTime.now().add(const Duration(seconds: 2));
    }
  }

  Future<bool> _showUnlockedCocktailsSheet(Set<int> unlockedIds) async {
    if (!mounted || _unlockSheetOpen) return false;
    _unlockSheetOpen = true;
    final unlocked = _allCocktailsCache.where((c) => unlockedIds.contains(c.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final keepAddingSelected = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final single = unlocked.length == 1;
        final title = single ? unlocked.first.name : '${unlocked.length} cocktails unlocked';
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
            border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.35)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.36), blurRadius: 22, offset: const Offset(0, -6))],
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 2, width: double.infinity, color: AppTheme.accentGold.withValues(alpha: 0.92)),
              const SizedBox(height: 16),
              _AnimatedUnlockReveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UNLOCKED', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppTheme.accentGold.withValues(alpha: 0.95))),
                    const SizedBox(height: 6),
                    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.9), height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (single)
                _AnimatedUnlockReveal(
                  child: SizedBox(height: 212, width: double.infinity, child: _UnlockPreviewCard(cocktail: unlocked.first, showName: false)),
                )
              else
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: unlocked.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) => SizedBox(width: 156, child: _AnimatedUnlockReveal(child: _UnlockPreviewCard(cocktail: unlocked[index]))),
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
                        side: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.7)),
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
                          Navigator.push(context, MaterialPageRoute(builder: (_) => CocktailDetailScreen(database: widget.database, cocktail: unlocked.first)));
                        } else {
                          widget.onNavigateToFinder?.call();
                        }
                      },
                      child: Text(single ? 'View Cocktail' : 'View Cocktails'),
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
          top: position.dy + size.height / 2 - 16 + (_unlockSlide.value.dy * 40),
          child: Opacity(
            opacity: _unlockFade.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentGold,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.accentGold.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)],
              ),
              child: Text('+$delta cocktail${delta != 1 ? 's' : ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
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
    _createDiagnostics?.incrementCounter('_switchToBar', stackTrace: StackTrace.current);
    await _delayForImeSettleIfNeeded();
    await _barService.setDefaultBar(barId);

    final active = await (widget.database.select(widget.database.savedBars)..where((b) => b.id.equals(barId))).getSingleOrNull();
    if (active == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That bar no longer exists.')),
      );
      await _loadData();
      return;
    }
    final ingredients = await widget.database.getSavedBarIngredients(barId);
    final bars = await (widget.database.select(widget.database.savedBars)..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();

    if (!mounted) return;
    _markCreateSetState('_switchToBar:setState');
    setState(() {
      _activeBar = active;
      _savedBars = bars;
      _barIngredientIds = ingredients.map((i) => i.id).toSet();
      _activeCategoryFilter = null;
      _unlockDeltaCache = {};
      _searchQuery = '';
      _searchController.clear();
    });
    _scrollIngredientListToTop();
    widget.onBarChanged?.call();
    _refreshAnalytics();
  }

  void _scheduleCreateHydration(int barId, {BarCreateDiagnosticsFlow? diagnostics}) {
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
        if (identical(_createDiagnostics, flow)) _createDiagnostics = null;
        return;
      }

      final phaseBSw = Stopwatch()..start();
      try {
        flow?.step('phaseB:postFrameStart');
        await _delayForImeSettleIfNeeded();
        flow?.step('phaseB:imeSettleDone');
        if (widget.onBarSwitched != null) {
          flow?.incrementCounter('_switchToBar(delegate)', stackTrace: StackTrace.current);
          widget.onBarSwitched!(hydrationBarId);
        } else {
          await _switchToBar(hydrationBarId);
        }
        flow?.step('phaseB:switchDone');
      } finally {
        flow?.step('phaseB:finally');
        if (kDebugMode) debugPrint('MyBar create Phase B (deferred hydration) ${phaseBSw.elapsedMilliseconds}ms');
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
      final newBarId = await widget.database.into(widget.database.savedBars).insert(
        SavedBarsCompanion.insert(name: trimmedName, isDefault: const Value(true), lastUsed: Value(now)),
      );
      flow.step('phaseA:insertBar');

      if (!mounted) {
        _finishCreateDiagnostics(result: 'unmounted');
        return;
      }

      final optimisticBar = SavedBar(id: newBarId, name: trimmedName, isDefault: true, createdAt: now, lastUsed: now);
      final existing = List<SavedBar>.from(_savedBars)
        ..removeWhere((b) => b.id == newBarId)
        ..insert(0, optimisticBar);

      _markCreateSetState('phaseA:optimisticUi');
      setState(() {
        _savedBars = existing;
        _activeBar = optimisticBar;
        _barIngredientIds = {};
        _activeCategoryFilter = null;
        _unlockDeltaCache = {};
        _searchQuery = '';
        _searchController.clear();
      });
      flow.step('phaseA:setStateDone');
      _scrollIngredientListToTop();
      flow.step('phaseA:scrollTopDone');

      if (kDebugMode) debugPrint('MyBar create Phase A (immediate UI) ${phaseASw.elapsedMilliseconds}ms');

      _scheduleCreateHydration(newBarId, diagnostics: flow);
      flow.step('phaseA:scheduleDeferredHydration');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "${optimisticBar.name}"'),
            action: SnackBarAction(label: 'Rename', onPressed: () => _showRenameBarDialog(optimisticBar.id, optimisticBar.name)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create bar. Please try again.')));
      _markCreateSetState('create:error');
      setState(() => _isCreatingBar = false);
      _finishCreateDiagnostics(result: 'error');
    }
  }

  Future<void> _showRenameBarDialog(int barId, String initialName) async {
    final renamed = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameBarDialog(initialName: initialName),
    );
    if (!mounted || renamed == null || renamed.trim().isEmpty) return;
    final name = renamed.trim();

    await (widget.database.update(widget.database.savedBars)..where((b) => b.id.equals(barId)))
        .write(SavedBarsCompanion(name: Value(name)));

    final bars = await (widget.database.select(widget.database.savedBars)..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
    if (!mounted) return;
    setState(() {
      _savedBars = bars;
      if (_activeBar?.id == barId) _activeBar = _activeBar!.copyWith(name: name);
    });
    widget.onBarChanged?.call();
    _pushBarsToCloud();
  }

  Future<void> _clearCurrentBarWithConfirm() async {
    if (_activeBar == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Clear Current Bar', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Remove all ingredients from "${_activeBar!.name}"?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Clear', style: TextStyle(color: Colors.red.shade300))),
        ],
      ),
    );
    if (confirmed != true || !mounted || _activeBar == null) return;

    await (widget.database.delete(widget.database.savedBarIngredients)..where((bi) => bi.savedBarId.equals(_activeBar!.id))).go();

    if (!mounted) return;
    setState(() => _barIngredientIds.clear());
    widget.onBarChanged?.call();
    await _refreshAnalytics();
    _pushBarsToCloud();
  }

  Future<void> _deleteBarWithConfirm(SavedBar bar) async {
    if (_savedBars.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You need at least one bar.')));
      return;
    }

    final deletingActive = _activeBar?.id == bar.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Bar', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          deletingActive
              ? 'Delete "${bar.name}"? This is your active bar, so another bar will be selected automatically.'
              : 'Delete "${bar.name}" and all of its ingredients?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: Colors.red.shade300))),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await (widget.database.delete(widget.database.savedBarIngredients)..where((row) => row.savedBarId.equals(bar.id))).go();
    await (widget.database.delete(widget.database.savedBars)..where((row) => row.id.equals(bar.id))).go();

    var remainingBars = await (widget.database.select(widget.database.savedBars)..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
    if (remainingBars.isEmpty || !mounted) return;

    final activeBarStillExists = _activeBar != null && remainingBars.any((b) => b.id == _activeBar!.id);
    final hasDefault = remainingBars.any((b) => b.isDefault);

    if (deletingActive || !activeBarStillExists || !hasDefault) {
      await _barService.setDefaultBar(remainingBars.first.id);
      remainingBars = await (widget.database.select(widget.database.savedBars)..orderBy([(b) => OrderingTerm.desc(b.lastUsed)])).get();
    }

    if (!mounted || remainingBars.isEmpty) return;

    if (deletingActive || !activeBarStillExists) {
      await _switchToBar(remainingBars.first.id);
    } else {
      final active = remainingBars.firstWhere((b) => b.id == _activeBar!.id, orElse: () => remainingBars.first);
      final ingredients = await widget.database.getSavedBarIngredients(active.id);
      if (!mounted) return;
      setState(() {
        _activeBar = active;
        _savedBars = remainingBars;
        _barIngredientIds = ingredients.map((i) => i.id).toSet();
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

  // ─── Derived data ─────────────────────────────────────────────────────────

  List<Ingredient> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return _allIngredients.where((i) => i.name.toLowerCase().contains(q)).toList()
      ..sort((a, b) {
        final aStocked = _barIngredientIds.contains(a.id) ? 0 : 1;
        final bStocked = _barIngredientIds.contains(b.id) ? 0 : 1;
        if (aStocked != bStocked) return aStocked - bStocked;
        return a.name.compareTo(b.name);
      });
  }

  List<Ingredient> _categoryIngredients(String category) {
    final all = _allIngredients.where((i) => i.category == category).toList();
    final stocked = all.where((i) => _barIngredientIds.contains(i.id)).toList()..sort((a, b) => a.name.compareTo(b.name));
    final missing = all.where((i) => !_barIngredientIds.contains(i.id)).toList()..sort((a, b) => a.name.compareTo(b.name));
    return [...stocked, ...missing];
  }

  int _stockedCountForCategory(String category) =>
      _allIngredients.where((i) => i.category == category && _barIngredientIds.contains(i.id)).length;

  int _totalCountForCategory(String category) =>
      _allIngredients.where((i) => i.category == category).length;

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
      );
    }

    final analytics = _analytics ?? BarAnalyticsResult.empty();
    final suggestion = analytics.suggestion;
    final hasSuggestion = suggestion != null && _barIngredientIds.isNotEmpty;
    final suggestionIsBusy = hasSuggestion &&
        (_suggestionAddsInFlight.contains(suggestion.canonicalName) ||
            _allIngredients
                .where((i) => IngredientEquivalence.normalise(i.name) == suggestion.canonicalName)
                .map((i) => i.id)
                .any(_busyIngredientIds.contains));

    final inSearchMode = _searchQuery.isNotEmpty;
    final inCategoryMode = _activeCategoryFilter != null && !inSearchMode;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            _BarHeader(
              activeBarName: _activeBar?.name ?? widget.activeBarName,
              activeBarId: _activeBar?.id,
              bars: _savedBars,
              isCreatingBar: _isCreatingBar,
              onSelectBar: (barId) async {
                if (barId == _activeBar?.id) return;
                if (widget.onBarSwitched != null) {
                  widget.onBarSwitched!(barId);
                  return;
                }
                await _switchToBar(barId);
              },
              onCreateBar: _createNewBar,
              onClearBar: _clearCurrentBarWithConfirm,
              onDeleteBar: _deleteBarWithConfirm,
            ),
            Expanded(
              child: FadeTransition(
                opacity: _headerFade,
                child: inCategoryMode
                    ? _CategoryDetailView(
                        category: _activeCategoryFilter!,
                        ingredients: _categoryIngredients(_activeCategoryFilter!),
                        barIngredientIds: _barIngredientIds,
                        busyIngredientIds: _busyIngredientIds,
                        unlockDeltas: _unlockDeltaCache,
                        deltaLoading: _deltaLoading,
                        stockedCount: _stockedCountForCategory(_activeCategoryFilter!),
                        totalCount: _totalCountForCategory(_activeCategoryFilter!),
                        onToggle: _toggleIngredient,
                        onTapWithContext: (id, ctx) => _ingredientRowContexts[id] = ctx,
                        onBack: _closeCategory,
                      )
                    : NestedScrollView(
                        controller: _listScrollController,
                        headerSliverBuilder: (context, innerBoxIsScrolled) => [
                          if (!inSearchMode)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _StatCard(
                                      cocktailCount: analytics.exactMatchCount,
                                      stockedCount: _barIngredientIds.length,
                                      totalCount: _allIngredients.length,
                                      onTap: widget.onNavigateToFinder,
                                    ),
                                    if (hasSuggestion) ...[
                                      const SizedBox(height: 10),
                                      _SuggestionNudge(
                                        suggestion: suggestion,
                                        isBusy: suggestionIsBusy,
                                        onAdd: _handleSuggestionAdd,
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        body: Column(
                          children: [
                            Container(
                              color: AppTheme.primaryDark,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: _IngredientSearchField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: _setSearchQuery,
                                onClear: _clearSearchInput,
                              ),
                            ),
                            Expanded(
                              child: CustomScrollView(
                                slivers: [
                                  if (inSearchMode)
                                    _SearchResultsSliver(
                                      results: _searchResults,
                                      barIngredientIds: _barIngredientIds,
                                      busyIngredientIds: _busyIngredientIds,
                                      onToggle: _toggleIngredient,
                                      onTapWithContext: (id, ctx) => _ingredientRowContexts[id] = ctx,
                                    )
                                  else
                                    _CategoryGridSliver(
                                      allIngredients: _allIngredients,
                                      barIngredientIds: _barIngredientIds,
                                      onTapCategory: _openCategory,
                                    ),
                                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                                ],
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
}

// ═══════════════════════════════════════════════════════════════════════════
//  RENAME BAR DIALOG
// ═══════════════════════════════════════════════════════════════════════════

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
      title: const Text('Rename Bar', style: TextStyle(color: AppTheme.textPrimary)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(hintText: 'Bar name', hintStyle: TextStyle(color: AppTheme.textSecondary)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

// ═══════════════════════════════════════════════════════════════════════════
//  BAR HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _BarHeader extends StatelessWidget {
  final String activeBarName;
  final int? activeBarId;
  final List<SavedBar> bars;
  final bool isCreatingBar;
  final Future<void> Function(int) onSelectBar;
  final Future<void> Function() onCreateBar;
  final Future<void> Function() onClearBar;
  final Future<void> Function(SavedBar) onDeleteBar;

  const _BarHeader({
    required this.activeBarName,
    required this.activeBarId,
    required this.bars,
    required this.isCreatingBar,
    required this.onSelectBar,
    required this.onCreateBar,
    required this.onClearBar,
    required this.onDeleteBar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: AppTheme.primaryDark.withValues(alpha: 0.92),
      child: BarSelectorDropdown(
        key: const ValueKey('bar-selector'),
        currentBarName: activeBarName,
        currentBarId: activeBarId,
        bars: bars,
        maxWidth: 280,
        isCreateInProgress: isCreatingBar,
        onSelectBar: onSelectBar,
        onCreateBar: onCreateBar,
        onClearBar: onClearBar,
        onDeleteBar: onDeleteBar,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STAT CARD
// ═══════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final int cocktailCount;
  final int stockedCount;
  final int totalCount;
  final VoidCallback? onTap;

  const _StatCard({
    required this.cocktailCount,
    required this.stockedCount,
    required this.totalCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.accentGold.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.32)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$cocktailCount',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.0, letterSpacing: -1),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'COCKTAILS AVAILABLE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: AppTheme.accentGold.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$stockedCount stocked',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.55)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${totalCount - stockedCount} to add',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                ),
                if (onTap != null) ...[
                  const SizedBox(height: 6),
                  Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppTheme.accentGold.withValues(alpha: 0.5)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SEARCH FIELD
// ═══════════════════════════════════════════════════════════════════════════

class _IngredientSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _IngredientSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.75)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search ingredients',
          hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 13),
          prefixIcon: Icon(Icons.search, color: AppTheme.accentGold.withValues(alpha: 0.6), size: 19),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18), onPressed: onClear);
            },
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          isDense: true,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUGGESTION NUDGE
// ═══════════════════════════════════════════════════════════════════════════

class _SuggestionNudge extends StatelessWidget {
  final SmartSuggestion suggestion;
  final bool isBusy;
  final VoidCallback onAdd;

  const _SuggestionNudge({required this.suggestion, required this.isBusy, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.accentGold.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 13, color: AppTheme.accentGold.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add ${suggestion.ingredientName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 1),
                  Text('unlocks ${suggestion.unlocksCount} cocktail${suggestion.unlocksCount == 1 ? '' : 's'}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.65))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isBusy)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGold))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.35)),
                ),
                child: Text('+ Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accentGold.withValues(alpha: 0.9))),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY GRID SLIVER
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryGridSliver extends StatelessWidget {
  final List<Ingredient> allIngredients;
  final Set<int> barIngredientIds;
  final void Function(String) onTapCategory;

  const _CategoryGridSliver({
    required this.allIngredients,
    required this.barIngredientIds,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    const categories = IngredientCategory.allCategories;
    const icons = IngredientCategory.categoryIcons;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = categories[index];
            final stocked = allIngredients.where((i) => i.category == category && barIngredientIds.contains(i.id)).length;
            final total = allIngredients.where((i) => i.category == category).length;
            final icon = icons[category] ?? '📦';
            return _CategoryTile(
              category: category,
              icon: icon,
              stocked: stocked,
              total: total,
              onTap: () => onTapCategory(category),
            );
          },
          childCount: categories.length,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY TILE
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryTile extends StatelessWidget {
  final String category;
  final String icon;
  final int stocked;
  final int total;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.icon,
    required this.stocked,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = stocked > 0;
    final isFull = total > 0 && stocked == total;
    final fillFraction = total > 0 ? stocked / total : 0.0;

    final borderColor = isFull
        ? AppTheme.accentGold.withValues(alpha: 0.5)
        : hasAny
            ? AppTheme.accentGold.withValues(alpha: 0.22)
            : AppTheme.surfaceLight.withValues(alpha: 0.6);

    final bgColor = isFull
        ? AppTheme.accentGold.withValues(alpha: 0.08)
        : hasAny
            ? AppTheme.accentGold.withValues(alpha: 0.04)
            : AppTheme.surfaceDark.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              if (fillFraction > 0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2.5,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fillFraction,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: isFull ? AppTheme.accentGold.withValues(alpha: 0.9) : AppTheme.accentGold.withValues(alpha: 0.5),
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 13, 10, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 22)),
                    const Spacer(),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isFull ? AppTheme.textPrimary : AppTheme.textPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total == 0 ? 'None' : '$stocked / $total',
                      style: TextStyle(
                        fontSize: 11,
                        color: hasAny ? AppTheme.accentGold.withValues(alpha: 0.7) : AppTheme.textSecondary.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
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

// ═══════════════════════════════════════════════════════════════════════════
//  CATEGORY DETAIL VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryDetailView extends StatelessWidget {
  final String category;
  final List<Ingredient> ingredients;
  final Set<int> barIngredientIds;
  final Set<int> busyIngredientIds;
  final Map<int, int> unlockDeltas;
  final bool deltaLoading;
  final int stockedCount;
  final int totalCount;
  final Future<void> Function(int) onToggle;
  final void Function(int, BuildContext) onTapWithContext;
  final VoidCallback onBack;

  const _CategoryDetailView({
    required this.category,
    required this.ingredients,
    required this.barIngredientIds,
    required this.busyIngredientIds,
    required this.unlockDeltas,
    required this.deltaLoading,
    required this.stockedCount,
    required this.totalCount,
    required this.onToggle,
    required this.onTapWithContext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final icon = IngredientCategory.categoryIcons[category] ?? '📦';
    final stocked = ingredients.where((i) => barIngredientIds.contains(i.id)).toList();
    final missing = ingredients.where((i) => !barIngredientIds.contains(i.id)).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryDark,
            border: Border(bottom: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.accentGold),
                onPressed: onBack,
                splashRadius: 20,
              ),
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(category, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              Text(
                '$stockedCount / $totalCount',
                style: TextStyle(fontSize: 13, color: stockedCount > 0 ? AppTheme.accentGold.withValues(alpha: 0.8) : AppTheme.textSecondary.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (stocked.isNotEmpty) ...[
                _DetailSectionHeader(label: 'In your bar', count: stocked.length),
                ...stocked.map((ingredient) => _IngredientRow(
                      ingredient: ingredient,
                      isStocked: true,
                      isBusy: busyIngredientIds.contains(ingredient.id),
                      unlockDelta: null,
                      onTap: () => onToggle(ingredient.id),
                      onTapWithContext: (ctx) => onTapWithContext(ingredient.id, ctx),
                    )),
              ],
              if (missing.isNotEmpty) ...[
                _DetailSectionHeader(label: 'Not stocked', count: missing.length, dimmed: true),
                ...missing.map((ingredient) {
                  final delta = unlockDeltas[ingredient.id];
                  return _IngredientRow(
                    ingredient: ingredient,
                    isStocked: false,
                    isBusy: busyIngredientIds.contains(ingredient.id),
                    unlockDelta: deltaLoading ? null : (delta != null && delta > 0 ? delta : null),
                    onTap: () => onToggle(ingredient.id),
                    onTapWithContext: (ctx) => onTapWithContext(ingredient.id, ctx),
                  );
                }),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailSectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool dimmed;

  const _DetailSectionHeader({required this.label, required this.count, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: dimmed ? AppTheme.textSecondary.withValues(alpha: 0.35) : AppTheme.accentGold.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SEARCH RESULTS SLIVER
// ═══════════════════════════════════════════════════════════════════════════

class _SearchResultsSliver extends StatelessWidget {
  final List<Ingredient> results;
  final Set<int> barIngredientIds;
  final Set<int> busyIngredientIds;
  final Future<void> Function(int) onToggle;
  final void Function(int, BuildContext) onTapWithContext;

  const _SearchResultsSliver({
    required this.results,
    required this.barIngredientIds,
    required this.busyIngredientIds,
    required this.onToggle,
    required this.onTapWithContext,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Text('No ingredients found', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary.withValues(alpha: 0.5))),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final ingredient = results[index];
          final isStocked = barIngredientIds.contains(ingredient.id);
          return _IngredientRow(
            ingredient: ingredient,
            isStocked: isStocked,
            isBusy: busyIngredientIds.contains(ingredient.id),
            unlockDelta: null,
            showCategory: true,
            onTap: () => onToggle(ingredient.id),
            onTapWithContext: (ctx) => onTapWithContext(ingredient.id, ctx),
          );
        },
        childCount: results.length,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  INGREDIENT ROW
// ═══════════════════════════════════════════════════════════════════════════

class _IngredientRow extends StatefulWidget {
  final Ingredient ingredient;
  final bool isStocked;
  final bool isBusy;
  final int? unlockDelta;
  final bool showCategory;
  final VoidCallback? onTap;
  final void Function(BuildContext ctx)? onTapWithContext;

  const _IngredientRow({
    required this.ingredient,
    required this.isStocked,
    required this.isBusy,
    required this.unlockDelta,
    this.showCategory = false,
    required this.onTap,
    required this.onTapWithContext,
  });

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 1.0).animate(_scaleController);
  }

  @override
  void didUpdateWidget(covariant _IngredientRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStocked != oldWidget.isStocked) {
      _scaleController.reset();
      _scale = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 60),
      ]).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isStocked ? AppTheme.accentGold.withValues(alpha: 0.05) : Colors.transparent,
            border: const Border(bottom: BorderSide(color: AppTheme.surfaceLight, width: 0.3)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.isBusy ? AppTheme.surfaceDark : widget.isStocked ? AppTheme.accentGold : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
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
                    ? const Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(strokeWidth: 1.7, color: AppTheme.accentGold))
                    : widget.isStocked
                        ? const Icon(Icons.check, color: AppTheme.primaryDark, size: 13)
                        : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: widget.showCategory
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.ingredient.name,
                            style: TextStyle(fontSize: 14, fontWeight: widget.isStocked ? FontWeight.w600 : FontWeight.w400, color: widget.isStocked ? AppTheme.textPrimary : AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 1),
                          Text(widget.ingredient.category, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.45))),
                        ],
                      )
                    : Text(
                        widget.ingredient.name,
                        style: TextStyle(fontSize: 14, fontWeight: widget.isStocked ? FontWeight.w600 : FontWeight.w400, color: widget.isStocked ? AppTheme.textPrimary : AppTheme.textSecondary),
                      ),
              ),
              if (widget.isStocked) ...[
                const SizedBox(width: 8),
                Text('in bar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentGold.withValues(alpha: 0.6))),
              ] else if (widget.unlockDelta != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.25)),
                  ),
                  child: Text('+${widget.unlockDelta}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentGold.withValues(alpha: 0.8))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  UNLOCK PREVIEW CARD
// ═══════════════════════════════════════════════════════════════════════════

class _UnlockPreviewCard extends StatelessWidget {
  final Cocktail cocktail;
  final bool showName;

  const _UnlockPreviewCard({required this.cocktail, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final basePath = cocktail.imagePath ?? ImageUtils.generateBasePathFromName(cocktail.name);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.65)),
        boxShadow: [BoxShadow(color: AppTheme.accentGold.withValues(alpha: 0.18), blurRadius: 20, spreadRadius: 0.6, offset: const Offset(0, 5))],
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
                    child: const Center(child: Icon(Icons.local_bar_rounded, color: AppTheme.textSecondary, size: 22)),
                  );
                }
                return Image.asset(path, fit: BoxFit.cover, width: double.infinity);
              },
            ),
          ),
          if (showName)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(cocktail.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ANIMATED UNLOCK REVEAL
// ═══════════════════════════════════════════════════════════════════════════

class _AnimatedUnlockReveal extends StatelessWidget {
  final Widget child;
  const _AnimatedUnlockReveal({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.97, end: 1.0),
      builder: (context, value, child) => Opacity(opacity: value, child: Transform.scale(scale: value, child: child)),
      child: child,
    );
  }
}