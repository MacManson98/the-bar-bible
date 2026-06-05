import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/theme/app_theme.dart';
import '../data/database.dart';
import '../services/auth_service.dart';
import '../services/purchase_service.dart';
import 'auth_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final AppDatabase database;

  const SettingsScreen({super.key, required this.database});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool useOz = false;
  bool strictMatching = false;
  String defaultSort = 'match';
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
      strictMatching = prefs.getBool('strict_matching') ?? false;
      defaultSort = prefs.getString('default_sort') ?? 'match';
      isLoading = false;
    });
  }

  Future<void> _toggleUnits(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_oz', value);
    setState(() => useOz = value);
  }

  Future<void> _toggleStrictMatching(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('strict_matching', value);
    setState(() => strictMatching = value);
  }

  Future<void> _setDefaultSort(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_sort', value);
    setState(() => defaultSort = value);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
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

  Future<void> _showRevenueCatDebug() async {
    String appUserId = 'unknown';
    String entitlements = 'none';
    String isPremiumRC = 'unknown';
    String error = '';

    try {
      appUserId = await Purchases.appUserID;
      final info = await Purchases.getCustomerInfo();
      isPremiumRC = info.entitlements.active.isNotEmpty.toString();
      entitlements = info.entitlements.active.isEmpty
          ? 'none'
          : info.entitlements.active.keys.join(', ');
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;

    final purchase = context.read<PurchaseService>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'RevenueCat Debug',
          style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DebugRow(label: 'APP USER ID', value: appUserId),
              const SizedBox(height: 12),
              _DebugRow(label: 'IS PREMIUM (LOCAL)', value: purchase.isPremium.toString()),
              const SizedBox(height: 12),
              _DebugRow(label: 'IS PREMIUM (RC)', value: isPremiumRC),
              const SizedBox(height: 12),
              _DebugRow(label: 'ENTITLEMENTS', value: entitlements),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DebugRow(label: 'ERROR', value: error, isError: true),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: appUserId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('App User ID copied')),
              );
            },
            child: const Text('COPY ID', style: TextStyle(color: AppTheme.accentGold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE', style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
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
              'Version 1.2.1 (Build 19)',
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

            // ── Account ───────────────────────────────────────────────────
            const _SectionHeader(title: 'ACCOUNT'),
            Consumer<AuthService>(
              builder: (context, auth, _) {
                if (!auth.isSignedIn || auth.currentUser?.email == null) {
                  return _SettingTile(
                    icon: Icons.person_outline,
                    title: 'Sign in',
                    subtitle: 'Access Back Bar features',
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
                    onTap: () => showAuthSheet(context),
                  );
                }
                return Column(
                  children: [
                    _SettingTile(
                      icon: Icons.person_outline,
                      title: auth.currentUser!.email!,
                      subtitle: 'Signed in',
                      trailing: TextButton(
                        onPressed: () async {
                          await auth.signOut();
                        },
                        child: Text('Sign out', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.8), fontSize: 13)),
                      ),
                    ),
                  ],
                );
              },
            ),

            const _SectionDivider(),

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

            // ── Preferences ───────────────────────────────────────────────
            const _SectionHeader(title: 'PREFERENCES'),
            _SettingTile(
              icon: Icons.tune,
              title: 'Ingredient Matching',
              subtitle: strictMatching
                  ? 'Strict — exact ingredients only'
                  : 'Flexible — allows substitutions',
              trailing: Switch(
                value: strictMatching,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  _toggleStrictMatching(v);
                },
                activeThumbColor: AppTheme.accentGold,
                activeTrackColor: AppTheme.accentGold.withValues(alpha: 0.3),
                inactiveThumbColor: AppTheme.textSecondary,
                inactiveTrackColor: AppTheme.surfaceLight,
              ),
            ),
            _SettingTile(
              icon: Icons.sort,
              title: 'Default Sort',
              subtitle: defaultSort == 'match'
                  ? 'Best Match'
                  : defaultSort == 'name'
                      ? 'A–Z'
                      : 'Difficulty',
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              onTap: () async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: AppTheme.surfaceDark,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Default Sort', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 16),
                        _SortOption(label: 'Best Match', value: 'match', current: defaultSort, onTap: (v) => Navigator.pop(ctx, v)),
                        _SortOption(label: 'A–Z', value: 'name', current: defaultSort, onTap: (v) => Navigator.pop(ctx, v)),
                        _SortOption(label: 'Difficulty', value: 'difficulty', current: defaultSort, onTap: (v) => Navigator.pop(ctx, v)),
                      ],
                    ),
                  ),
                );
                if (picked != null) {
                  HapticFeedback.selectionClick();
                  _setDefaultSort(picked);
                }
              },
            ),

            const _SectionDivider(),

            // ── My Bar ────────────────────────────────────────────────────
            const _SectionHeader(title: 'MY BAR'),
            _SettingTile(
              icon: Icons.history,
              title: 'Clear Recently Viewed',
              subtitle: 'Remove cocktail view history from home screen',
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              onTap: _clearRecentlyViewed,
            ),
            _SettingTile(
              icon: Icons.delete_outline,
              iconColor: Colors.redAccent.withValues(alpha: 0.8),
              title: 'Reset Bar Ingredients',
              subtitle: 'Remove all ingredients from your saved bar',
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              onTap: _resetBarIngredients,
            ),

            const _SectionDivider(),

            // ── Support ───────────────────────────────────────────────────
            const _SectionHeader(title: 'SUPPORT'),
            _SettingTile(
              icon: Icons.star_outline,
              iconColor: AppTheme.accentGold,
              title: 'Rate the App',
              subtitle: 'Enjoying The Bar Bible? Leave a review',
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              onTap: () => _launchUrl('https://apps.apple.com/app/id0000000000'),
            ),
            _SettingTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              onTap: () => _launchUrl('https://thebarbible.app/privacy'),
            ),

            const _SectionDivider(),

            // ── About ─────────────────────────────────────────────────────
            const _SectionHeader(title: 'ABOUT'),
            const _SettingTile(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle: '1.2.1 (Build 19)',
            ),
            const _SettingTile(
              icon: Icons.local_bar_outlined,
              title: 'Cocktail Database',
              subtitle: 'IBA Official Cocktails',
            ),
            _SettingTile(
              icon: Icons.bug_report_outlined,
              iconColor: Colors.orangeAccent,
              title: 'RevenueCat Debug',
              subtitle: 'View SDK status and App User ID',
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              onTap: _showRevenueCatDebug,
            ),
            _SettingTile(
              icon: Icons.favorite_outline,
              title: 'Credits',
              subtitle: 'Built with Flutter & Dart',
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
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
            Icon(icon, color: iconColor ?? AppTheme.textSecondary, size: 22),
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
              color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
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

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isError;

  const _DebugRow({required this.label, required this.value, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isError ? Colors.redAccent : AppTheme.textPrimary,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onTap;

  const _SortOption({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppTheme.accentGold : AppTheme.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: AppTheme.accentGold, size: 18),
          ],
        ),
      ),
    );
  }
}
