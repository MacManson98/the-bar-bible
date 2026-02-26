import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database.dart';

class VaultCocktailRow extends StatelessWidget {
  final Cocktail cocktail;
  final String? resolvedImagePath;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const VaultCocktailRow({
    super.key,
    required this.cocktail,
    required this.resolvedImagePath,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [cocktail.baseSpirit, cocktail.method, cocktail.glass]
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.surfaceLight.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: resolvedImagePath != null
                  ? Image.asset(
                      resolvedImagePath!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 72,
                          height: 72,
                          color: AppTheme.surfaceLight,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.local_bar,
                            color: AppTheme.accentGold,
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 72,
                      height: 72,
                      color: AppTheme.surfaceLight,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.local_bar,
                        color: AppTheme.accentGold,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cocktail.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
