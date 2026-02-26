import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vault_pill_button.dart';

class VaultEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const VaultEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 28),
              VaultPillButton(
                label: ctaLabel!,
                onTap: onCta!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
