import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../services/purchase_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isRestoring = false;
  int _selectedPlan = 1; // 0=weekly, 1=monthly, 2=annual

  static const _plans = [
    _Plan(label: 'Weekly', price: '£1.49', period: '/ week', badge: null),
    _Plan(label: 'Monthly', price: '£3.99', period: '/ month', badge: null),
    _Plan(label: 'Annual', price: '£24.99', period: '/ year', badge: 'BEST VALUE'),
  ];

  @override
  Widget build(BuildContext context) {
    final purchaseService = context.watch<PurchaseService>();

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          children: [
            // Icon
            Center(
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentGold, width: 1.5),
                ),
                child: const Icon(Icons.workspace_premium, color: AppTheme.accentGold, size: 36),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'UNLOCK THE FULL BAR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.accentGold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Everything a serious bartender needs.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
            ),

            const SizedBox(height: 16),

            // Feature list
            const _FeatureRow(icon: Icons.menu_book, title: '102+ premium cocktail recipes', subtitle: 'Full specs, methods, history and tasting notes'),
            const SizedBox(height: 10),
            const _FeatureRow(icon: Icons.search, title: 'Unlimited Finder access', subtitle: 'Match every cocktail in the library to your bar'),
            const SizedBox(height: 10),
            const _FeatureRow(icon: Icons.favorite, title: 'Favourites & collections', subtitle: 'Save and organise your personal cocktail library'),
            const SizedBox(height: 10),
            const _FeatureRow(icon: Icons.edit_outlined, title: 'Unlimited cocktail creator', subtitle: 'Build and save as many recipes as you like'),
            const SizedBox(height: 10),
            const _FeatureRow(icon: Icons.auto_awesome, title: '20 AI generations per day', subtitle: 'Describe a flavour and get a full recipe instantly'),
            const SizedBox(height: 10),
            const _FeatureRow(icon: Icons.people_outline, title: 'Community access', subtitle: 'Share creations and discover others — coming soon'),

            const SizedBox(height: 20),

            // Plan selector
            Row(
              children: List.generate(_plans.length, (i) {
                final plan = _plans[i];
                final selected = i == _selectedPlan;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPlan = i),
                    child: Container(
                      margin: EdgeInsets.only(right: i < _plans.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.accentGold.withValues(alpha: 0.12)
                            : AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppTheme.accentGold : AppTheme.surfaceLight.withValues(alpha: 0.4),
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (plan.badge != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(plan.badge!, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.primaryDark, letterSpacing: 0.5)),
                            )
                          else
                            const SizedBox(height: 20),
                          Text(
                            plan.price,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: selected ? AppTheme.accentGold : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(plan.period, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
                          const SizedBox(height: 4),
                          Text(plan.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? AppTheme.accentGold.withValues(alpha: 0.8) : AppTheme.textSecondary.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 8),
            Center(
              child: Text(
                _selectedPlan == 0
                    ? 'Billed weekly · Cancel anytime'
                    : _selectedPlan == 1
                        ? 'Billed monthly · Cancel anytime'
                        : 'Billed annually · Save vs monthly',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.45)),
              ),
            ),

            const SizedBox(height: 20),

            // CTA button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: purchaseService.isLoading
                    ? null
                    : () async {
                        final success = await purchaseService.purchasePremium(planIndex: _selectedPlan);
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🎉 Premium unlocked!'), backgroundColor: AppTheme.accentGold),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Purchase failed. Please try again.')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: purchaseService.isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.primaryDark, strokeWidth: 2))
                    : Text(
                        _selectedPlan == 0
                            ? 'START FOR £1.49 / WEEK'
                            : _selectedPlan == 1
                                ? 'START FOR £3.99 / MONTH'
                                : 'START FOR £24.99 / YEAR',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Restore
            Center(
              child: TextButton(
                onPressed: _isRestoring
                    ? null
                    : () async {
                        setState(() => _isRestoring = true);
                        final restored = await purchaseService.restorePurchases();
                        if (!context.mounted) return;
                        setState(() => _isRestoring = false);
                        if (restored) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Purchase restored'), backgroundColor: AppTheme.accentGold));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No previous purchase found')));
                        }
                      },
                child: Text(
                  _isRestoring ? 'Restoring...' : 'Restore purchase',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
            ),

            const SizedBox(height: 4),
            Text(
              'Prices in GBP · Subscription auto-renews unless cancelled',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.35)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Plan model ────────────────────────────────────────────────────────────

class _Plan {
  final String label;
  final String price;
  final String period;
  final String? badge;
  const _Plan({required this.label, required this.price, required this.period, required this.badge});
}

// ─── Feature row ───────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accentGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.accentGold, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 12, height: 1.3)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle, color: AppTheme.accentGold, size: 18),
        ),
      ],
    );
  }
}
