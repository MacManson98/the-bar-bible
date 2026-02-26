import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import '../core/theme/app_theme.dart';
import '../data/database.dart';

class BarContextPill extends StatelessWidget {
  final AppDatabase database;
  final String activeBarName;
  final String? labelText;
  final ValueChanged<int> onBarSwitched;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;
  final double iconSize;
  final double chevronSize;
  final bool showBarIcon;
  final bool showShadow;
  final Color? backgroundColor;
  final Color? borderColor;
  final double maxLabelWidth;
  final double? height;

  const BarContextPill({
    super.key,
    required this.database,
    required this.activeBarName,
    required this.onBarSwitched,
    this.labelText,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    this.borderRadius = 22,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w700,
    this.iconSize = 15,
    this.chevronSize = 16,
    this.showBarIcon = true,
    this.showShadow = true,
    this.backgroundColor,
    this.borderColor,
    this.maxLabelWidth = 140,
    this.height,
  });

  Future<void> _openBarSelector(BuildContext context) async {
    HapticFeedback.selectionClick();

    final bars = await (database.select(database.savedBars)
          ..orderBy([(b) => OrderingTerm.desc(b.lastUsed)]))
        .get();
    final activeBar = await database.getDefaultSavedBar();

    if (!context.mounted || bars.length < 2) return;

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BarSelectorSheet(
        bars: bars,
        activeBarId: activeBar?.id,
      ),
    );

    if (selected != null && selected != activeBar?.id) {
      onBarSwitched(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = labelText ?? activeBarName;
    return GestureDetector(
      onTap: () => _openBarSelector(context),
      child: Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor ?? AppTheme.accentGold.withValues(alpha: 0.25),
          ),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBarIcon)
              Icon(
                Icons.local_bar_rounded,
                size: iconSize,
                color: AppTheme.accentGold.withValues(alpha: 0.9),
              ),
            if (showBarIcon) const SizedBox(width: 7),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: chevronSize,
              color: AppTheme.accentGold.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarSelectorSheet extends StatelessWidget {
  final List<SavedBar> bars;
  final int? activeBarId;

  const _BarSelectorSheet({
    required this.bars,
    required this.activeBarId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SWITCH BAR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 12),
          ...bars.map((bar) {
            final isActive = bar.id == activeBarId;
            return InkWell(
              onTap: () => Navigator.pop(context, bar.id),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.accentGold.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isActive
                      ? Border.all(
                          color: AppTheme.accentGold.withValues(alpha: 0.2),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: isActive
                          ? AppTheme.accentGold
                          : AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        bar.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (isActive)
                      const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppTheme.accentGold,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
