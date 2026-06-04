import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'vault_pill_button.dart';

class VaultUseCaseHint {
  final IconData icon;
  final String label;
  const VaultUseCaseHint({required this.icon, required this.label});
}

class VaultEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final List<VaultUseCaseHint> useCases;

  const VaultEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
    this.useCases = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          // Main empty state card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentGold.withValues(alpha: 0.25),
                    ),
                    color: AppTheme.accentGold.withValues(alpha: 0.06),
                  ),
                  child: Icon(icon, size: 28, color: AppTheme.accentGold),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                if (ctaLabel != null && onCta != null) ...[
                  const SizedBox(height: 24),
                  VaultPillButton(label: ctaLabel!, onTap: onCta!),
                ],
              ],
            ),
          ),

          // Use case hints
          if (useCases.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: useCases.map((uc) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: useCases.indexOf(uc) == 0 ? 0 : 4,
                    right: useCases.indexOf(uc) == useCases.length - 1 ? 0 : 4,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.surfaceLight),
                  ),
                  child: Column(
                    children: [
                      Icon(uc.icon, size: 20, color: AppTheme.accentGold),
                      const SizedBox(height: 6),
                      Text(
                        uc.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
