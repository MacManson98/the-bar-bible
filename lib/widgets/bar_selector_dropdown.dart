import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/database.dart';

typedef BarSelectCallback = FutureOr<void> Function(int barId);
typedef BarActionCallback = FutureOr<void> Function();
typedef BarDeleteCallback = FutureOr<void> Function(SavedBar bar);

class BarSelectorDropdown extends StatelessWidget {
  final String currentBarName;
  final int? currentBarId;
  final List<SavedBar> bars;
  final BarSelectCallback onSelectBar;
  final BarActionCallback onCreateBar;
  final BarActionCallback onClearBar;
  final BarDeleteCallback onDeleteBar;
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
    required this.onDeleteBar,
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
        MenuItemButton(
          onPressed: sortedBars.length <= 1
              ? null
              : () async {
                  final selectedBar = await showModalBottomSheet<SavedBar>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => _DeleteBarPickerSheet(
                      bars: sortedBars,
                      currentBarId: currentBarId,
                    ),
                  );
                  if (selectedBar == null) return;
                  await onDeleteBar(selectedBar);
                },
          leadingIcon: Icon(
            Icons.delete_forever_rounded,
            size: 16,
            color: sortedBars.length <= 1
                ? AppTheme.textSecondary.withValues(alpha: 0.5)
                : Colors.red.shade300,
          ),
          child: Text(
            'Delete Bar...',
            style: TextStyle(
              color: sortedBars.length <= 1
                  ? AppTheme.textSecondary.withValues(alpha: 0.6)
                  : Colors.red.shade300,
            ),
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

class _DeleteBarPickerSheet extends StatelessWidget {
  final List<SavedBar> bars;
  final int? currentBarId;

  const _DeleteBarPickerSheet({
    required this.bars,
    required this.currentBarId,
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
          Text(
            'DELETE BAR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Colors.red.shade300,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a bar to delete.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...bars.map((bar) {
            final isCurrent = bar.id == currentBarId;
            return InkWell(
              onTap: () => Navigator.pop(context, bar),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.surfaceLight.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bar.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent)
                      const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
