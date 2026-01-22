import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool useOz = false;
  bool serviceModeEnabled = false;
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
      serviceModeEnabled = prefs.getBool('service_mode') ?? false;
      isLoading = false;
    });
  }

  Future<void> _toggleUnits(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_oz', value);
    setState(() {
      useOz = value;
    });
  }

  Future<void> _toggleServiceMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('service_mode', value);
    setState(() {
      serviceModeEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SETTINGS'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: const Row(
              children: [
                Icon(Icons.menu_book, color: AppTheme.accentGold, size: 28),
                SizedBox(width: 12),
                Text(
                  'THE BAR BIBLE',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.surfaceLight),

          // Measurements Section
          const _SectionHeader(title: 'MEASUREMENTS'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _UnitButton(
                    label: 'METRIC (ML)',
                    isSelected: !useOz,
                    onTap: () => _toggleUnits(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _UnitButton(
                    label: 'IMPERIAL (OZ)',
                    isSelected: useOz,
                    onTap: () => _toggleUnits(true),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Display Section
          const _SectionHeader(title: 'DISPLAY'),
          _SettingTile(
            icon: Icons.text_fields,
            title: 'Service Mode',
            subtitle: 'Larger text for behind the bar',
            trailing: Switch(
              value: serviceModeEnabled,
              onChanged: _toggleServiceMode,
              activeThumbColor: AppTheme.accentGold,
            ),
          ),

          const SizedBox(height: 20),

          // About Section
          const _SectionHeader(title: 'ABOUT'),
          _SettingTile(
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '1.0.0 (MVP)',
            onTap: () {},
          ),
          _SettingTile(
            icon: Icons.menu_book,
            title: 'Cocktail Database',
            subtitle: 'IBA Official Cocktails',
            onTap: () {},
          ),
          _SettingTile(
            icon: Icons.copyright,
            title: 'Credits',
            subtitle: 'Built with Flutter',
            onTap: () {
              _showCreditsDialog();
            },
          ),

          const SizedBox(height: 40),

          // Footer
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
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
                const SizedBox(height: 8),
                Text(
                  'Essential Cocktail Reference',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
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
              'Version 1.0.0',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            SizedBox(height: 16),
            Text(
              'Essential cocktail reference for bartenders and enthusiasts.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            SizedBox(height: 16),
            Text(
              'Built with Flutter & Dart',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
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
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: AppTheme.accentGold,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppTheme.textSecondary,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
