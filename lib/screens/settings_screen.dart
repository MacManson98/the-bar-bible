import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../data/database.dart';

class SettingsScreen extends StatefulWidget {
  final AppDatabase database;

  const SettingsScreen({super.key, required this.database});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool useOz = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useOz = prefs.getBool('use_oz') ?? false;
      isLoading = false;
    });
  }

  Future<void> _toggleUnits(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_oz', value);
    setState(() => useOz = value);
  }

  Future<void> _clearRecentlyViewed() async {
    final confirmed = await _showConfirmDialog(
      title: 'Clear History',
      message: 'Remove all recently viewed cocktails from your home screen?',
      confirmLabel: 'Clear',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recently_viewed_ids');
    HapticFeedback.mediumImpact();
    messenger.showSnackBar(
      const SnackBar(content: Text('Recently viewed cleared')),
    );
  }

  Future<void> _resetBarIngredients() async {
    final bars = await widget.database.select(widget.database.savedBars).get();
    if (!mounted) return;

    if (bars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved bars found')),
      );
      return;
    }

    int totalCount = 0;
    for (final bar in bars) {
      final ingredients = await (widget.database
              .select(widget.database.savedBarIngredients)
            ..where((bi) => bi.savedBarId.equals(bar.id)))
          .get();
      totalCount += ingredients.length;
    }

    if (!mounted) return;

    if (totalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your bar is already empty')),
      );
      return;
    }

    final barLabel = bars.length == 1 ? 'your bar' : 'all ${bars.length} bars';
    final confirmed = await _showConfirmDialog(
      title: 'Reset Bar',
      message:
          'Remove all $totalCount ingredient${totalCount == 1 ? '' : 's'} from $barLabel? This cannot be undone.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await widget.database.delete(widget.database.savedBarIngredients).go();
    HapticFeedback.heavyImpact();
    messenger.showSnackBar(
      const SnackBar(content: Text('Bar ingredients cleared')),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? Colors.redAccent : AppTheme.accentGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.primaryDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentGold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: ListView(
          children: [
            _buildHeader(),

            // ── Measurements ──────────────────────────────────────────────
            const _SectionHeader(title: 'MEASUREMENTS'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: _UnitButton(
                      label: 'METRIC (ML)',
                      isSelected: !useOz,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _toggleUnits(false);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _UnitButton(
                      label: 'IMPERIAL (OZ)',
                      isSelected: useOz,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _toggleUnits(true);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const _SectionDivider(),

            // ── My Bar ────────────────────────────────────────────────────
            const _SectionHeader(title: 'MY BAR'),
            _SettingTile(
              icon: Icons.history,
              title: 'Clear Recently Viewed',
              subtitle: 'Remove cocktail view history from home screen',
              trailing: const Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onTap: _clearRecentlyViewed,
            ),
            _SettingTile(
              icon: Icons.delete_outline,
              iconColor: Colors.redAccent.withValues(alpha: 0.8),
              title: 'Reset Bar Ingredients',
              subtitle: 'Remove all ingredients from your saved bar',
              trailing: const Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onTap: _resetBarIngredients,
            ),

            const _SectionDivider(),

            // ── About ─────────────────────────────────────────────────────
            const _SectionHeader(title: 'ABOUT'),
            const _SettingTile(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle: '1.0.0 (Build 9)',
            ),
            const _SettingTile(
              icon: Icons.local_bar_outlined,
              title: 'Cocktail Database',
              subtitle: 'IBA Official Cocktails',
            ),
            _SettingTile(
              icon: Icons.favorite_outline,
              title: 'Credits',
              subtitle: 'Built with Flutter & Dart',
              trailing: const Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onTap: _showCreditsDialog,
            ),

            const SizedBox(height: 40),
            _buildFooter(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.accentGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.0,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          'THE BAR BIBLE',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Essential Cocktail Reference',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  void _showCreditsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'THE BAR BIBLE',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: AppTheme.accentGold,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version 1.0.0 (Build 9)',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Essential cocktail reference for bartenders and enthusiasts.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            Divider(color: AppTheme.surfaceLight),
            SizedBox(height: 12),
            _CreditRow(label: 'Framework', value: 'Flutter & Dart'),
            SizedBox(height: 8),
            _CreditRow(label: 'Database', value: 'IBA Official Cocktails'),
            SizedBox(height: 8),
            _CreditRow(label: 'Developer', value: 'MacManson98'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                color: AppTheme.accentGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
          color: AppTheme.accentGold,
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: AppTheme.surfaceLight,
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppTheme.accentGold.withValues(alpha: 0.05),
      highlightColor: AppTheme.accentGold.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _UnitButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentGold : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentGold : AppTheme.surfaceLight,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color:
                  isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final String label;
  final String value;

  const _CreditRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
