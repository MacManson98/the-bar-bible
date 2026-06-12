import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/image_utils.dart';
import '../data/database.dart';
import '../data/ingredient_data.dart';
import '../services/purchase_service.dart';
import 'cocktail_detail_screen.dart';
import 'paywall_screen.dart';
import 'favorites_screen.dart';
import 'collections_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase database;
  final String activeBarName;
  final VoidCallback onNavigateToBrowse;
  final VoidCallback onNavigateToFinder;
  final Future<void> Function(int barId)? onSwitchBar;

  const HomeScreen({
    super.key,
    required this.database,
    required this.activeBarName,
    required this.onNavigateToBrowse,
    required this.onNavigateToFinder,
    this.onSwitchBar,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Cocktail> _allCocktails = [];
  List<Cocktail> _recentlyViewed = [];
  List<SavedBar> _savedBars = [];
  Cocktail? _tonightsPick;
  String _pickReasoning = '';
  int _favoritesCount = 0;
  int _collectionsCount = 0;
  int _canMakeCount = 0;
  int _ingredientCount = 0;
  int _oneAwayCount = 0;
  bool _isLoading = true;
  String? _loadError;

  static const String _recentlyViewedKey = 'recently_viewed_ids';
  static const Duration _homeLoadTimeout = Duration(seconds: 10);

  late AnimationController _entryController;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnims = List.generate(5, (i) {
      final start = i * 0.12;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
    _slideAnims = List.generate(5, (i) {
      final start = i * 0.12;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });
    _loadData();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() { _isLoading = true; _loadError = null; });
    try {
      final result = await _performHomeLoad().timeout(
        _homeLoadTimeout,
        onTimeout: () => throw TimeoutException('Home load timed out.'),
      );
      if (!mounted) return;
      setState(() {
        _allCocktails = result.cocktails;
        _tonightsPick = result.pick;
        _pickReasoning = result.reasoning;
        _favoritesCount = result.favoritesCount;
        _collectionsCount = result.collectionsCount;
        _recentlyViewed = result.recentlyViewed;
        _canMakeCount = result.canMakeCount;
        _ingredientCount = result.ingredientCount;
        _oneAwayCount = result.oneAwayCount;
        _savedBars = result.savedBars;
        _isLoading = false;
        _loadError = null;
      });
      _entryController.forward(from: 0);
    } catch (error) {
      if (!mounted) return;
      setState(() { _isLoading = false; _loadError = error.toString(); });
    }
  }

  Future<_HomeLoadResult> _performHomeLoad() async {
    final cocktails = await widget.database.select(widget.database.cocktails).get();
    final favorites = await widget.database.getFavoriteCocktails();
    final collections = await widget.database.select(widget.database.collections).get();
    final recentlyViewed = await _loadRecentlyViewed(cocktails);
    final savedBars = await (widget.database.select(widget.database.savedBars)
          ..orderBy([(b) => OrderingTerm.desc(b.lastUsed)]))
        .get();

    // Bar stats
    final bar = await widget.database.getDefaultSavedBar();
    int ingredientCount = 0;
    int canMakeCount = 0;
    int oneAwayCount = 0;

    if (bar != null) {
      final barIngredients = await widget.database.getSavedBarIngredients(bar.id);
      ingredientCount = barIngredients.length;

      if (ingredientCount > 0) {
        final barIds = barIngredients.map((i) => i.id).toSet();
        final barCanonicals = <String>{};
        final allIngredients = await widget.database.select(widget.database.ingredients).get();
        final ingredientMap = {for (final i in allIngredients) i.id: i};

        for (final id in barIds) {
          final name = ingredientMap[id]?.name;
          if (name != null) barCanonicals.add(IngredientEquivalence.normalise(name));
        }

        final barSubCanonicals = <String>{};
        for (final canon in barCanonicals) {
          barSubCanonicals.addAll(IngredientSubstitutions.getSubstitutes(canon));
        }

        final allCi = await widget.database.select(widget.database.cocktailIngredients).get();
        final ciBycocktail = <int, List<CocktailIngredient>>{};
        for (final ci in allCi) {
          ciBycocktail.putIfAbsent(ci.cocktailId, () => []).add(ci);
        }

        for (final cocktail in cocktails) {
          final ciRows = ciBycocktail[cocktail.id] ?? const [];
          if (ciRows.isEmpty) continue;

          final required = <String>{};
          for (final ci in ciRows) {
            final name = ingredientMap[ci.ingredientId]?.name;
            if (name != null) required.add(IngredientEquivalence.normalise(name));
          }
          if (required.isEmpty) continue;

          int missing = 0;
          for (final canon in required) {
            if (!barCanonicals.contains(canon) && !barSubCanonicals.contains(canon)) {
              missing++;
            }
          }
          if (missing == 0) canMakeCount++;
          if (missing == 1) oneAwayCount++;
        }
      }
    }

    // Tonight's pick — prefer free cocktails
    Cocktail? pick;
    String reasoning = '';
    final freeCocktails = cocktails.where((c) => !c.isPremium).toList();
    final pickPool = freeCocktails.isNotEmpty ? freeCocktails : cocktails;

    if (favorites.isNotEmpty) {
      final notFavorited = pickPool.where(
        (c) => !favorites.any((f) => f.id == c.id),
      ).toList();
      if (notFavorited.isNotEmpty) {
        final favSpirits = favorites.map((f) => f.baseSpirit.toLowerCase()).toSet();
        final spiritMatches = notFavorited
            .where((c) => favSpirits.contains(c.baseSpirit.toLowerCase()))
            .toList();
        if (spiritMatches.isNotEmpty) {
          spiritMatches.shuffle();
          pick = spiritMatches.first;
          final matchedFav = favorites.firstWhere(
            (f) => f.baseSpirit.toLowerCase() == pick!.baseSpirit.toLowerCase(),
          );
          reasoning = 'Similar to ${matchedFav.name} · ${pick.baseSpirit}';
        } else {
          notFavorited.shuffle();
          pick = notFavorited.first;
          reasoning = 'Something new to try';
        }
      } else {
        favorites.shuffle();
        pick = favorites.first;
        reasoning = 'One of your favourites';
      }
    } else {
      final classics = ['Negroni', 'Old Fashioned', 'Margarita', 'Daiquiri', 'Manhattan', 'Martini'];
      final classicCocktails = pickPool.where((c) => classics.contains(c.name)).toList();
      if (classicCocktails.isNotEmpty) {
        classicCocktails.shuffle();
        pick = classicCocktails.first;
        reasoning = 'A timeless classic';
      } else if (pickPool.isNotEmpty) {
        pickPool.shuffle();
        pick = pickPool.first;
        reasoning = 'Discover something new';
      }
    }

    return _HomeLoadResult(
      cocktails: cocktails,
      recentlyViewed: recentlyViewed,
      savedBars: savedBars,
      pick: pick,
      reasoning: reasoning,
      favoritesCount: favorites.length,
      collectionsCount: collections.length,
      canMakeCount: canMakeCount,
      ingredientCount: ingredientCount,
      oneAwayCount: oneAwayCount,
    );
  }

  Future<List<Cocktail>> _loadRecentlyViewed(List<Cocktail> allCocktails) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_recentlyViewedKey) ?? [];
      final result = <Cocktail>[];
      for (final idStr in ids) {
        final id = int.tryParse(idStr);
        if (id != null) {
          final cocktail = allCocktails.where((c) => c.id == id).firstOrNull;
          if (cocktail != null) result.add(cocktail);
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> _trackRecentlyViewed(int cocktailId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_recentlyViewedKey) ?? [];
    ids.remove(cocktailId.toString());
    ids.insert(0, cocktailId.toString());
    if (ids.length > 10) ids.removeRange(10, ids.length);
    await prefs.setStringList(_recentlyViewedKey, ids);
  }

  void _shufflePick() {
    if (_allCocktails.length <= 1) return;
    final purchaseService = context.read<PurchaseService>();
    final pool = !purchaseService.isPremium
        ? _allCocktails.where((c) => !c.isPremium).toList()
        : _allCocktails;
    final candidates = (pool.isEmpty ? _allCocktails : pool)
        .where((c) => c.id != _tonightsPick?.id)
        .toList();
    if (candidates.isEmpty) return;
    candidates.shuffle();
    setState(() {
      _tonightsPick = candidates.first;
      _pickReasoning = 'Shuffled for you';
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _showBarSwitcher() async {
    if (_savedBars.length <= 1) return; // nothing to switch to
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SWITCH BAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 16),
            ..._savedBars.map((bar) {
              final isActive = bar.name == widget.activeBarName;
              return InkWell(
                onTap: isActive
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await widget.onSwitchBar?.call(bar.id);
                        await _loadData();
                      },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bar.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive
                                ? AppTheme.accentGold
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (isActive)
                        const Icon(Icons.check,
                            color: AppTheme.accentGold, size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _viewCocktailDetail(Cocktail cocktail) {
    HapticFeedback.lightImpact();
    final purchaseService = context.read<PurchaseService>();
    if (cocktail.isPremium && !purchaseService.isPremium) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const PaywallScreen()));
      return;
    }
    _trackRecentlyViewed(cocktail.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CocktailDetailScreen(
          database: widget.database,
          cocktail: cocktail,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.accentGold, size: 40),
                const SizedBox(height: 12),
                const Text('Failed to load',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_loadError!,
                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, height: 280,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.4,
                  colors: [
                    AppTheme.accentGold.withValues(alpha: 0.06),
                    AppTheme.primaryDark.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [

                // ▸ SECTION 1: Bar context
                _animatedSection(
                  index: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: GestureDetector(
                      onTap: _savedBars.length > 1 ? _showBarSwitcher : null,
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppTheme.accentGold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.activeBarName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (_ingredientCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.accentGold.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                '$_ingredientCount ingredients',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accentGold,
                                ),
                              ),
                            ),
                          ],
                          if (_savedBars.length > 1) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.expand_more,
                              size: 18,
                              color: AppTheme.textSecondary.withValues(alpha: 0.6),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ▸ SECTION 2: Can Make hero card
                _animatedSection(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _CanMakeCard(
                      canMakeCount: _canMakeCount,
                      oneAwayCount: _oneAwayCount,
                      ingredientCount: _ingredientCount,
                      barName: widget.activeBarName,
                      onTap: widget.onNavigateToFinder,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ▸ SECTION 3: Tonight's Pick
                if (_tonightsPick != null)
                  Expanded(
                    flex: 5,
                    child: _animatedSection(
                      index: 2,
                      child: Column(
                        children: [
                          _SectionHeader(
                            label: "TONIGHT'S PICK",
                            accentColor: AppTheme.accentGold,
                            trailing: GestureDetector(
                              onTap: _shufflePick,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 14,
                                      color: AppTheme.accentGold.withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Shuffle',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.accentGold.withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: GestureDetector(
                                onTap: () => _viewCocktailDetail(_tonightsPick!),
                                child: _TonightsPickCard(
                                  cocktail: _tonightsPick!,
                                  reasoning: _pickReasoning,
                                  onTap: () => _viewCocktailDetail(_tonightsPick!),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // ▸ SECTION 4: Recently Viewed
                if (_recentlyViewed.isNotEmpty)
                  _animatedSection(
                    index: 3,
                    child: Column(
                      children: [
                        const _SectionHeader(
                          label: 'RECENTLY VIEWED',
                          accentColor: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 90,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _recentlyViewed.length,
                            itemBuilder: (context, index) {
                              final cocktail = _recentlyViewed[index];
                              return _RecentlyViewedChip(
                                cocktail: cocktail,
                                onTap: () => _viewCocktailDetail(cocktail),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // ▸ SECTION 5: Quick Access
                _animatedSection(
                  index: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _QuickAccessTile(
                            icon: Icons.menu_book_outlined,
                            label: 'Browse',
                            onTap: widget.onNavigateToBrowse,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAccessTile(
                            icon: Icons.favorite_border,
                            label: 'Favourites',
                            count: _favoritesCount,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FavoritesScreen(
                                  database: widget.database,
                                  onNavigateToBrowse: widget.onNavigateToBrowse,
                                ),
                              ),
                            ).then((_) => _loadData()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAccessTile(
                            icon: Icons.bookmark_border,
                            label: 'Collections',
                            count: _collectionsCount,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CollectionsScreen(database: widget.database),
                              ),
                            ).then((_) => _loadData()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedSection({required int index, required Widget child}) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(position: _slideAnims[index], child: child),
    );
  }
}

// ─── Data ────────────────────────────────────────────────────────────────────

class _HomeLoadResult {
  final List<Cocktail> cocktails;
  final List<Cocktail> recentlyViewed;
  final List<SavedBar> savedBars;
  final Cocktail? pick;
  final String reasoning;
  final int favoritesCount;
  final int collectionsCount;
  final int canMakeCount;
  final int ingredientCount;
  final int oneAwayCount;

  const _HomeLoadResult({
    required this.cocktails,
    required this.recentlyViewed,
    required this.savedBars,
    required this.pick,
    required this.reasoning,
    required this.favoritesCount,
    required this.collectionsCount,
    required this.canMakeCount,
    required this.ingredientCount,
    required this.oneAwayCount,
  });
}

// ─── Can Make Card ───────────────────────────────────────────────────────────

class _CanMakeCard extends StatelessWidget {
  final int canMakeCount;
  final int oneAwayCount;
  final int ingredientCount;
  final String barName;
  final VoidCallback onTap;

  const _CanMakeCard({
    required this.canMakeCount,
    required this.oneAwayCount,
    required this.ingredientCount,
    required this.barName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasBar = ingredientCount > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.accentGold.withValues(alpha: 0.18),
              AppTheme.accentGold.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.35)),
        ),
        child: hasBar
            ? Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$canMakeCount',
                              style: const TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentGold,
                                height: 1.0,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'cocktails you\ncan make now',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary.withValues(alpha: 0.9),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (oneAwayCount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGold.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$oneAwayCount more just 1 ingredient away',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.arrow_forward, color: AppTheme.accentGold, size: 20),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'What can you make?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add ingredients to $barName to find out',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: AppTheme.accentGold, size: 20),
                ],
              ),
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color accentColor;
  final Widget? trailing;

  const _SectionHeader({
    required this.label,
    required this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: accentColor == AppTheme.accentGold
                  ? Colors.white
                  : AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── Quick Access Tile ───────────────────────────────────────────────────────

class _QuickAccessTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    this.count,
    required this.onTap,
  });

  @override
  State<_QuickAccessTile> createState() => _QuickAccessTileState();
}

class _QuickAccessTileState extends State<_QuickAccessTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.surfaceLight.withValues(alpha: 0.6)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? AppTheme.accentGold.withValues(alpha: 0.5)
                : AppTheme.surfaceLight.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: AppTheme.accentGold, size: 20),
                if (widget.count != null && widget.count! > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.accentGold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentGold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tonight's Pick Card ─────────────────────────────────────────────────────

class _TonightsPickCard extends StatelessWidget {
  final Cocktail cocktail;
  final String reasoning;
  final VoidCallback onTap;

  const _TonightsPickCard({
    required this.cocktail,
    required this.reasoning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentGold.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageUtils.getCocktailImage(cocktail.imagePath, imageUrl: cocktail.imageUrl),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 20, right: 20, bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cocktail.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        height: 1.1,
                      ),
                    ),
                    if (reasoning.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        reasoning,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 14, right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'VIEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                      letterSpacing: 0.8,
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
}

// ─── Recently Viewed Chip ────────────────────────────────────────────────────

class _RecentlyViewedChip extends StatelessWidget {
  final Cocktail cocktail;
  final VoidCallback onTap;

  const _RecentlyViewedChip({required this.cocktail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: ImageUtils.getCocktailImage(cocktail.imagePath,
                    imageUrl: cocktail.imageUrl),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cocktail.name,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
