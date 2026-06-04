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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accentGold, width: 1.5),
                ),
                child: const Icon(
                  Icons.local_bar,
                  color: AppTheme.accentGold,
                  size: 40,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              const Text(
                'UNLOCK THE FULL BAR',
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                'One-time purchase. Everything unlocked forever.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 36),

              // Features list
              _FeatureRow(
                icon: Icons.menu_book,
                title: '100+ cocktail recipes',
                subtitle: 'Full specs, methods and history',
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.search,
                title: 'Full Finder access',
                subtitle: 'Match against every cocktail in the library',
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.favorite,
                title: 'Favourites & collections',
                subtitle: 'Save and organise your cocktail library',
              ),

              const Spacer(),

              // Price button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: purchaseService.isLoading
                      ? null
                      : () async {
                          final success =
                              await purchaseService.purchasePremium();
                          if (success && context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🎉 Premium unlocked!'),
                                backgroundColor: AppTheme.accentGold,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: purchaseService.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryDark,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'UNLOCK FOR £4.99',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Restore purchases
              TextButton(
                onPressed: _isRestoring
                    ? null
                    : () async {
                        setState(() => _isRestoring = true);
                        final restored =
                            await purchaseService.restorePurchases();
                        setState(() => _isRestoring = false);
                        if (context.mounted) {
                          if (restored) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✓ Purchase restored'),
                                backgroundColor: AppTheme.accentGold,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No previous purchase found'),
                              ),
                            );
                          }
                        }
                      },
                child: Text(
                  _isRestoring ? 'Restoring...' : 'Restore purchase',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'One-time purchase · No subscription · No expiry',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.accentGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.accentGold, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle, color: AppTheme.accentGold, size: 20),
      ],
    );
  }
}
