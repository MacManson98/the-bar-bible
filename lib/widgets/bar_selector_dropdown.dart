import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/database.dart';

typedef BarSelectCallback = FutureOr<void> Function(int barId);
typedef BarActionCallback = FutureOr<void> Function();

class BarSelectorDropdown extends StatelessWidget {
  final String currentBarName;
  final int? currentBarId;
  final List<SavedBar> bars;
  final BarSelectCallback onSelectBar;
  final BarActionCallback onCreateBar;
  final BarActionCallback onClearBar;
  final double maxWidth;
  final bool isCreateInProgress;

  const BarSelectorDropdown({
    super.key,
    required this.currentBarName,
    required this.currentBarId,
    required this.bars,
    required this.onSelectBar,
    required this.onCreateBar,
    required this.onClearBar,
    this.maxWidth = 230,
    this.isCreateInProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final sortedBars = List<SavedBar>.from(bars)
      ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      menuChildren: [
        ...sortedBars.map((bar) {
          final isCurrent = bar.id == currentBarId;
          return MenuItemButton(
            onPressed: () => onSelectBar(bar.id),
            leadingIcon: Icon(
              isCurrent ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: isCurrent
                  ? AppTheme.accentGold
                  : AppTheme.textSecondary.withValues(alpha: 0.65),
            ),
            child: Text(
              bar.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }),
        const Divider(height: 1),
        MenuItemButton(
          onPressed: isCreateInProgress ? null : () => onCreateBar(),
          leadingIcon: const Icon(
            Icons.add_rounded,
            size: 16,
            color: AppTheme.accentGold,
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Create New Bar...',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
              ),
              if (isCreateInProgress)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.4,
                    color: AppTheme.accentGold,
                  ),
                ),
            ],
          ),
        ),
        MenuItemButton(
          onPressed: () => onClearBar(),
          leadingIcon: Icon(
            Icons.delete_outline_rounded,
            size: 16,
            color: Colors.red.shade300,
          ),
          child: Text(
            'Clear Current Bar',
            style: TextStyle(color: Colors.red.shade300),
          ),
        ),
      ],
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppTheme.surfaceDark),
        side: WidgetStateProperty.all(
          BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.55)),
        ),
      ),
      builder: (context, controller, child) {
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentGold.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_bar_rounded,
                  size: 15,
                  color: AppTheme.accentGold,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    currentBarName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  controller.isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppTheme.accentGold.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
