import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/image_utils.dart';
import '../data/database.dart';
import '../widgets/vault/vault_widgets.dart';
import 'cocktail_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final AppDatabase database;

  const FavoritesScreen({super.key, required this.database});

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

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            VaultScreenHeader(
              title: 'MY FAVORITES',
              subtitle:
                  '${_favorites.length} ${_favorites.length == 1 ? 'cocktail' : 'cocktails'}',
              showBack: isPushedRoute,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accentGold),
                    )
                  : _favorites.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) {
                            final cocktail = _favorites[index];
                            return _buildFavoriteCard(cocktail);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const VaultEmptyState(
      icon: Icons.favorite_border,
      title: 'NO FAVORITES YET',
      body: 'Start liking cocktails to build\nyour personal collection',
    );
  }

  Widget _buildFavoriteCard(Cocktail cocktail) {
    return VaultCocktailRow(
      cocktail: cocktail,
      resolvedImagePath: _resolvedImagePathByCocktailId[cocktail.id],
      onTap: () => _viewCocktailDetail(cocktail),
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
