import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// All achievement milestones.
/// Thresholds match the popup logic in my_bar_screen.dart.
class _Milestone {
  final String key;
  final String name;
  final String description;
  final String emoji;
  final int threshold;

  const _Milestone(this.key, this.name, this.description, this.emoji, this.threshold);
}

const List<_Milestone> _allMilestones = [
  _Milestone('first_pour',     'First Pour',     'Add your first ingredient',   '\u{1F943}', 1),
  _Milestone('getting_started','Getting Started', 'Stock 5 ingredients',         '\u{1F949}', 5),
  _Milestone('home_bartender', 'Home Bartender',  'Stock 16 ingredients',        '\u{1F948}', 16),
  _Milestone('well_stocked',   'Well Stocked',    'Stock 30 ingredients',        '\u{1F947}', 30),
  _Milestone('professional',   'Professional',    'Stock 40+ ingredients',       '\u{1F48E}', 40),
  _Milestone('completionist',  'Completionist',   'Stock every ingredient',      '\u{1F3C6}', -1), // -1 = uses totalIngredients
];

class AchievementsScreen extends StatelessWidget {
  /// Current number of stocked ingredients in the active bar.
  final int ingredientCount;
  /// Total number of ingredients in the database (for Completionist).
  final int totalIngredients;

  const AchievementsScreen({
    super.key,
    required this.ingredientCount,
    required this.totalIngredients,
  });

  List<_BadgeData> _computeBadges() {
    final badges = <_BadgeData>[];
    for (final m in _allMilestones) {
      final threshold = m.threshold < 0 ? totalIngredients : m.threshold;
      final earned = threshold > 0 && ingredientCount >= threshold;
      badges.add(_BadgeData(m.name, m.description, m.emoji, earned));
    }
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    final badges = _computeBadges();
    final earned = badges.where((b) => b.earned).toList();
    final locked = badges.where((b) => !b.earned).toList();

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${earned.length} of ${badges.length} Earned',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      earned.length == badges.length
                          ? 'All achievements unlocked!'
                          : 'Keep stocking to unlock more',
                      style: const TextStyle(
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

          if (earned.isNotEmpty) ...[
            _buildSectionLabel('Earned'),
            const SizedBox(height: 10),
            _buildBadgeGrid(earned),
            const SizedBox(height: 24),
          ],

          if (locked.isNotEmpty) ...[
            _buildSectionLabel('Locked'),
            const SizedBox(height: 10),
            _buildBadgeGrid(locked),
          ],
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
