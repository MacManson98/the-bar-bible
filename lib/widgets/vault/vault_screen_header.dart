import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'vault_pill_button.dart';

class VaultScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const VaultScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (showBack) ...[
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surfaceDark,
                        border: Border.all(
                          color: AppTheme.accentGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppTheme.accentGold,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: showBack ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (ctaLabel != null && onCta != null)
            VaultPillButton(
              label: ctaLabel!,
              icon: Icons.add,
              onTap: onCta!,
            ),
        ],
      ),
    );
  }
}
