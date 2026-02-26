import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class VaultPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isPrimary;
  final EdgeInsets? padding;

  const VaultPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isPrimary = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final Color fillColor = isPrimary
        ? AppTheme.accentGold
        : AppTheme.surfaceLight.withValues(alpha: 0.45);
    final Color contentColor = isPrimary
        ? AppTheme.primaryDark
        : AppTheme.textPrimary;

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: icon == null
              ? Text(
                  label,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: contentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(icon, size: 18, color: contentColor),
                  ],
                ),
        ),
      ),
    );
  }
}
