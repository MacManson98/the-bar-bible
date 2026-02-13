import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Stub Achievements/Badges screen.
/// Placeholder data — replace with real badge logic later.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        title: const Text(
          'Achievements',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.surfaceDark, Color(0xFF252218)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentGold.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.military_tech,
                      color: AppTheme.accentGold, size: 26),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3 of 12 Earned',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Keep stocking to unlock more',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Badge grid
          _buildSectionLabel('Earned'),
          const SizedBox(height: 10),
          _buildBadgeGrid(_earnedBadges),

          const SizedBox(height: 24),
          _buildSectionLabel('Locked'),
          const SizedBox(height: 10),
          _buildBadgeGrid(_lockedBadges),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppTheme.accentGold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 0.5, color: AppTheme.surfaceLight),
        ),
      ],
    );
  }

  Widget _buildBadgeGrid(List<_BadgeData> badges) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return _BadgeCard(badge: badge);
      },
    );
  }

  static final _earnedBadges = [
    const _BadgeData('First Pour', 'Added your first ingredient', '🥃', true),
    const _BadgeData('Getting Started', 'Stocked 5 ingredients', '🥉', true),
    const _BadgeData('Spirit Forward', 'Added 3 spirits', '🍸', true),
  ];

  static final _lockedBadges = [
    const _BadgeData('Home Bartender', 'Stock 16 core ingredients', '🥈', false),
    const _BadgeData('Citrus Club', 'Add all citrus', '🍋', false),
    const _BadgeData('Bitter Truth', 'Add 3+ bitters', '💧', false),
    const _BadgeData('Sweet Tooth', 'Add all sweeteners', '🍯', false),
    const _BadgeData('Well Stocked', 'Stock 30 ingredients', '🥇', false),
    const _BadgeData('Professional', 'Stock 40+ ingredients', '💎', false),
    const _BadgeData('Mixologist', 'Unlock 50 cocktails', '🎯', false),
    const _BadgeData('Cocktail Master', 'Unlock 100 cocktails', '👑', false),
    const _BadgeData('Completionist', 'Stock every ingredient', '🏆', false),
  ];
}

class _BadgeData {
  final String name;
  final String description;
  final String emoji;
  final bool earned;

  const _BadgeData(this.name, this.description, this.emoji, this.earned);
}

class _BadgeCard extends StatelessWidget {
  final _BadgeData badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: badge.earned
            ? AppTheme.accentGold.withValues(alpha: 0.08)
            : AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badge.earned
              ? AppTheme.accentGold.withValues(alpha: 0.3)
              : AppTheme.surfaceLight.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            badge.emoji,
            style: TextStyle(
              fontSize: 26,
              color: badge.earned ? null : null,
            ),
          ),
          if (!badge.earned)
            // Greyed overlay effect via reduced opacity
            Opacity(
              opacity: 0.0, // emoji above handles it; this is a spacer
              child: Container(),
            ),
          const SizedBox(height: 6),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badge.earned
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary.withValues(alpha: 0.6),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              color: badge.earned
                  ? AppTheme.textSecondary
                  : AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
