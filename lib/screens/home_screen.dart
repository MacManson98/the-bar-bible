import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/image_utils.dart';
import '../data/database.dart';
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

  const HomeScreen({
    super.key,
    required this.database,
    required this.activeBarName,
    required this.onNavigateToBrowse,
    required this.onNavigateToFinder,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Cocktail> _allCocktails = [];
  List<Cocktail> _recentlyViewed = [];
  Cocktail? _tonightsPick;
  String _pickReasoning = '';
  int _favoritesCount = 0;
  int _collectionsCount = 0;
  bool _isLoading = true;
  String? _loadError;

  static const String _recentlyViewedKey = 'recently_viewed_ids';
  static const Duration _homeLoadTimeout = Duration(seconds: 10);

  // Entry animations
  late AnimationController _entryController;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();

    // Staggered entry: 4 sections, each offset by ~100ms
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnims = List.generate(4, (i) {
      final start = i * 0.15;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnims = List.generate(4, (i) {
      final start = i * 0.15;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(
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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    debugPrint('[HomeScreen] _loadData: started');

    try {
      final _HomeLoadResult result = await _performHomeLoad().timeout(
        _homeLoadTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Home load timed out after ${_homeLoadTimeout.inSeconds} seconds.',
          );
        },
      );

      debugPrint('[HomeScreen] _loadData: complete');

      if (!mounted) return;

      setState(() {
        _allCocktails = result.cocktails;
        _tonightsPick = result.pick;
        _pickReasoning = result.reasoning;
        _favoritesCount = result.favoritesCount;
        _collectionsCount = result.collectionsCount;
        _recentlyViewed = result.recentlyViewed;
        _isLoading = false;
        _loadError = null;
      });

      _entryController.forward(from: 0);
    } catch (error, stackTrace) {
      debugPrint('[HomeScreen] _loadData: failed -> $error');
      debugPrintStack(
        label: '[HomeScreen] _loadData stack',
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<_HomeLoadResult> _performHomeLoad() async {
    debugPrint('[HomeScreen] load step: cocktails query');
    final cocktails = await widget.database.select(widget.database.cocktails).get();
    debugPrint('[HomeScreen] load step complete: cocktails (${cocktails.length})');

    debugPrint('[HomeScreen] load step: favorites query');
    final favorites = await widget.database.getFavoriteCocktails();
    debugPrint('[HomeScreen] load step complete: favorites (${favorites.length})');

    debugPrint('[HomeScreen] load step: collections query');
    final collections = await widget.database.select(widget.database.collections).get();
    debugPrint('[HomeScreen] load step complete: collections (${collections.length})');

    debugPrint('[HomeScreen] load step: recently viewed');
    final recentlyViewed = await _loadRecentlyViewed(cocktails);
    debugPrint('[HomeScreen] load step complete: recently viewed (${recentlyViewed.length})');

    Cocktail? pick;
    String reasoning = '';

    // Prefer non-premium cocktails for the pick pool
    final freeCocktails = cocktails.where((c) => !c.isPremium).toList();
    final pickPool = freeCocktails.isNotEmpty ? freeCocktails : cocktails;

    if (favorites.isNotEmpty) {
      final notFavorited = pickPool.where(
        (c) => !favorites.any((f) => f.id == c.id),
      ).toList();

      if (notFavorited.isNotEmpty) {
        final favSpirits = favorites.map((f) => f.baseSpirit.toLowerCase()).toSet();
        final spiritMatches = notFavorited.where(
          (c) => favSpirits.contains(c.baseSpirit.toLowerCase()),
        ).toList();

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
      pick: pick,
      reasoning: reasoning,
      favoritesCount: favorites.length,
      collectionsCount: collections.length,
    );
  }

  Future<List<Cocktail>> _loadRecentlyViewed(List<Cocktail> allCocktails) async {
    try {
      debugPrint('[HomeScreen] _loadRecentlyViewed: fetching prefs');
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
      debugPrint('[HomeScreen] _loadRecentlyViewed: complete (${result.length})');
      return result;
    } catch (error, stackTrace) {
      debugPrint('[HomeScreen] _loadRecentlyViewed: failed -> $error');
      debugPrintStack(
        label: '[HomeScreen] _loadRecentlyViewed stack',
        stackTrace: stackTrace,
      );
      rethrow;
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
    // Prefer free cocktails for free users; fall back to all if needed
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

  void _viewCocktailDetail(Cocktail cocktail) {
    HapticFeedback.lightImpact();
    final purchaseService = context.read<PurchaseService>();
    if (cocktail.isPremium && !purchaseService.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PaywallScreen()),
      );
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final rng = Random(DateTime.now().day); // Same greeting per day

    if (hour < 12) {
      const greetings = [
        'What are we making today?',
        'Morning. Time to prep.',
        'Rise and shake.',
        'Fresh start. Fresh pour.',
      ];
      return greetings[rng.nextInt(greetings.length)];
    } else if (hour < 17) {
      const greetings = [
        'What are we pouring?',
        'Afternoon. Let\'s build something.',
        'Ready when you are.',
        'Time to get creative.',
      ];
      return greetings[rng.nextInt(greetings.length)];
    } else {
      const greetings = [
        'What are we making tonight?',
        'Evening. Let\'s pour.',
        'Ready to pour?',
        'The bar is open.',
        'Service time.',
      ];
      return greetings[rng.nextInt(greetings.length)];
    }
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
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.accentGold,
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load Home',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
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
          // ── Subtle background gradient (warm glow at top) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
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
          // ── Content ──
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // ▸ SECTION 1: Greeting
                _animatedSection(
                  index: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.2,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.activeBarName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary.withValues(alpha: 0.75),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                    
                const SizedBox(height: 24),
                
                // ▸ SECTION 2: Tonight's Pick (hero)
                if (_tonightsPick != null)
                  _animatedSection(
                    index: 1,
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
                                Icon(Icons.refresh, size: 14, color: AppTheme.accentGold.withValues(alpha: 0.7)),
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
                        const SizedBox(height: 14),
                        _TonightsPickCard(
                          cocktail: _tonightsPick!,
                          reasoning: _pickReasoning,
                          onTap: () => _viewCocktailDetail(_tonightsPick!),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 28),
                
                // ▸ SECTION 3: Quick Access Grid
                _animatedSection(
                  index: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _QuickAccessTile(
                                icon: Icons.local_bar_outlined,
                                label: 'Browse All',
                                onTap: widget.onNavigateToBrowse,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickAccessTile(
                                icon: Icons.search,
                                label: 'What Can I Make',
                                onTap: widget.onNavigateToFinder,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickAccessTile(
                                icon: Icons.bookmark_border,
                                label: 'Collections',
                                count: _collectionsCount,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CollectionsScreen(database: widget.database),
                                    ),
                                  ).then((_) => _loadData());
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickAccessTile(
                                icon: Icons.favorite_border,
                                label: 'Favourites',
                                count: _favoritesCount,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FavoritesScreen(
                            database: widget.database,
                            onNavigateToBrowse: widget.onNavigateToBrowse,
                          ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // ▸ SECTION 4: Recently Viewed
                if (_recentlyViewed.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _animatedSection(
                    index: 3,
                    child: Column(
                      children: [
                        const _SectionHeader(
                          label: 'RECENTLY VIEWED',
                          accentColor: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 100,
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
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps a section in fade + slide animation
  Widget _animatedSection({required int index, required Widget child}) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(
        position: _slideAnims[index],
        child: child,
      ),
    );
  }
}

class _HomeLoadResult {
  final List<Cocktail> cocktails;
  final List<Cocktail> recentlyViewed;
  final Cocktail? pick;
  final String reasoning;
  final int favoritesCount;
  final int collectionsCount;

  const _HomeLoadResult({
    required this.cocktails,
    required this.recentlyViewed,
    required this.pick,
    required this.reasoning,
    required this.favoritesCount,
    required this.collectionsCount,
  });
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
            width: 3,
            height: 16,
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
        height: 88,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.surfaceLight.withValues(alpha: 0.6)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? AppTheme.accentGold.withValues(alpha: 0.5)
                : AppTheme.surfaceLight.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: AppTheme.accentGold, size: 22),
                const Spacer(),
                if (widget.count != null && widget.count! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.accentGold.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentGold,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: 0.2,
              ),
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
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.accentGold.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentGold.withValues(alpha: 0.1),
              blurRadius: 40,
              spreadRadius: 0,
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
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cocktail.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        height: 1.1,
                      ),
                    ),
                    if (reasoning.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        reasoning,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
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
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: ImageUtils.getCocktailImage(cocktail.imagePath, imageUrl: cocktail.imageUrl),
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
