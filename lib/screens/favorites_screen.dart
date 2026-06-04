import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/image_utils.dart';
import '../data/database.dart';
import '../widgets/vault/vault_widgets.dart';
import 'cocktail_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final AppDatabase database;
  final VoidCallback? onNavigateToBrowse;

  const FavoritesScreen({super.key, required this.database, this.onNavigateToBrowse});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Cocktail> _favorites = [];
  Map<int, String?> _resolvedImagePathByCocktailId = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await widget.database.getFavoriteCocktails();

    final uniqueBasePaths = <String>{};
    for (final cocktail in favorites) {
      uniqueBasePaths.add(_cocktailImageBasePath(cocktail.imagePath, cocktail.name));
    }

    final resolvedByBasePath = <String, String?>{};
    await Future.wait(uniqueBasePaths.map((basePath) async {
      resolvedByBasePath[basePath] = await ImageUtils.findCocktailImage(basePath);
    }));

    final resolvedByCocktailId = <int, String?>{};
    for (final cocktail in favorites) {
      final basePath = _cocktailImageBasePath(cocktail.imagePath, cocktail.name);
      resolvedByCocktailId[cocktail.id] = resolvedByBasePath[basePath];
    }

    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _resolvedImagePathByCocktailId = resolvedByCocktailId;
      _isLoading = false;
    });
  }

  void _viewCocktailDetail(Cocktail cocktail) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CocktailDetailScreen(
          database: widget.database,
          cocktail: cocktail,
        ),
      ),
    ).then((_) => _loadFavorites());
  }

  @override
  Widget build(BuildContext context) {
    final isPushedRoute = Navigator.of(context).canPop();
    final freeCount = _favorites.where((c) => !c.isPremium).length;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            VaultScreenHeader(
              title: 'My Favourites',
              subtitle: '${_favorites.length} ${_favorites.length == 1 ? 'cocktail' : 'cocktails'}',
              showBack: isPushedRoute,
            ),
            if (!_isLoading && _favorites.isNotEmpty) _buildStatsRow(freeCount),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
                  : _favorites.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) {
                            final cocktail = _favorites[index];
                            return VaultCocktailRow(
                              cocktail: cocktail,
                              resolvedImagePath: _resolvedImagePathByCocktailId[cocktail.id],
                              onTap: () => _viewCocktailDetail(cocktail),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int freeCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _StatCard(value: '${_favorites.length}', label: 'SAVED'),
          const SizedBox(width: 8),
          _StatCard(value: '$freeCount', label: 'FREE'),
          const SizedBox(width: 8),
          _StatCard(value: '${_favorites.length - freeCount}', label: 'PREMIUM'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return VaultEmptyState(
      icon: Icons.favorite_border,
      title: 'No Favourites Yet',
      body: 'Tap the heart on any cocktail to save it here. Perfect for specs you return to again and again.',
      ctaLabel: 'Browse Cocktails',
      onCta: () {
        Navigator.pop(context);
        widget.onNavigateToBrowse?.call();
      },
      useCases: const [
        VaultUseCaseHint(icon: Icons.replay, label: 'Your go-to recipes'),
        VaultUseCaseHint(icon: Icons.bolt, label: 'Quick access mid-shift'),
        VaultUseCaseHint(icon: Icons.menu_book, label: 'Personal spec book'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cocktailImageBasePath(String? imagePath, String cocktailName) {
  final raw = imagePath?.trim();
  if (raw != null && raw.isNotEmpty) {
    if (raw.contains('.')) {
      return raw.substring(0, raw.lastIndexOf('.'));
    }
    return raw;
  }
  return ImageUtils.generateBasePathFromName(cocktailName);
}
