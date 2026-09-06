// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../data/database.dart';
import '../services/auth_service.dart';
import 'auth_sheet.dart';
import 'cocktail_creator_screen.dart';
import 'ai_generator_screen.dart';
import 'paywall_screen.dart';

class BackBarScreen extends StatefulWidget {
  final AppDatabase database;

  const BackBarScreen({super.key, required this.database});

  @override
  State<BackBarScreen> createState() => BackBarScreenState();
}

class BackBarScreenState extends State<BackBarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ColoredBox(
      color: AppTheme.primaryDark,
      child: Column(
        children: [
          SizedBox(height: topPadding),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CreateTab(database: widget.database),
                _CommunityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.3)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.accentGold,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppTheme.accentGold,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [Tab(text: 'Create'), Tab(text: 'Community')],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE TAB
// ═══════════════════════════════════════════════════════════════════════════

class _CreateTab extends StatefulWidget {
  final AppDatabase database;
  const _CreateTab({required this.database});

  @override
  State<_CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends State<_CreateTab> {
  List<UserCocktail> _creations = [];
  bool _isLoading = true;
  int _createsRemaining = 0;
  int _aiCreditsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final auth = context.read<AuthService>();
      final creations = auth.isSignedIn
          ? await widget.database.getUserCocktails()
          : <UserCocktail>[];

      if (!auth.isSignedIn) {
        if (mounted) {
          setState(() {
            _creations = creations;
            _createsRemaining = 5;
            _aiCreditsRemaining = 1;
            _isLoading = false;
          });
        }
        return;
      }

      final creates = await auth.createsRemaining(auth.isEffectivelyPremium);
      final ai = await auth.aiCreditsRemaining(auth.isEffectivelyPremium);

      if (mounted) {
        setState(() {
          _creations = creations;
          _createsRemaining = creates;
          _aiCreditsRemaining = ai;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[BackBarScreen] Failed to load data: $e');
      if (mounted) {
        setState(() {
          _creations = [];
          _createsRemaining = 5;
          _aiCreditsRemaining = 1;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCreateTap() async {
    final auth = context.read<AuthService>();

    if (!auth.isSignedIn) {
      final signedIn = await showAuthSheet(context, reason: 'Create a free account to start building your own cocktails.');
      if (!signedIn || !mounted) return;
      await _loadData();
      return;
    }

    bool canCreate;
    try {
      canCreate = await auth.canCreateCocktail(auth.isEffectivelyPremium);
    } catch (e) {
      debugPrint('[BackBarScreen] canCreateCocktail failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not check your create limit. Please try again.')),
        );
      }
      return;
    }
    if (!canCreate && mounted) {
      _showLimitSheet(title: 'Create limit reached', message: 'Free accounts can create up to 5 cocktails. Upgrade to Premium for unlimited creations.');
      return;
    }

    if (mounted) {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => CocktailCreatorScreen(database: widget.database)),
      );
      if (created == true && mounted) await _loadData();
    }
  }

  Future<void> _handleAiTap() async {
    final auth = context.read<AuthService>();

    if (!auth.isSignedIn) {
      final signedIn = await showAuthSheet(context, reason: 'Create a free account to try AI cocktail generation.');
      if (!signedIn || !mounted) return;
      await _loadData();
      return;
    }

    bool canUse;
    try {
      canUse = await auth.canUseAi(auth.isEffectivelyPremium);
    } catch (e) {
      debugPrint('[BackBarScreen] canUseAi failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not check your AI credits. Please try again.')),
        );
      }
      return;
    }
    if (!canUse && mounted) {
      _showLimitSheet(
        title: 'No AI credits remaining',
        message: auth.isEffectivelyPremium
            ? 'You\'ve used your 20 daily AI generations. Resets at midnight.'
            : 'Free accounts get 1 AI generation. Upgrade to Premium for 20 per day.',
      );
      return;
    }

    // TODO removed — navigate to AI generator screen
    if (mounted) {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AiGeneratorScreen(database: widget.database),
        ),
      );
      if (created == true && mounted) {
        await auth.incrementAiCreditsUsed(auth.isEffectivelyPremium);
        await _loadData();
      }
    }
  }

  void _showLimitSheet({required String title, required String message}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.workspace_premium, color: AppTheme.accentGold, size: 26),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.7), height: 1.45)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Upgrade to Premium', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
    }

    final auth = context.watch<AuthService>();
    final isPremium = auth.isEffectivelyPremium;

    if (!auth.isSignedIn) {
      return _SignedOutLanding(onSignIn: () async {
        final signedIn = await showAuthSheet(context);
        if (signedIn && mounted) await _loadData();
      });
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.accentGold,
      backgroundColor: AppTheme.surfaceDark,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          const Text('Back Bar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Your cocktail workshop', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.55))),
          const SizedBox(height: 20),

          if (auth.isSignedIn && !isPremium) ...[
            _UsageCard(createsRemaining: _createsRemaining, aiCreditsRemaining: _aiCreditsRemaining),
            const SizedBox(height: 20),
          ],

          _CreateCTA(onTap: _handleCreateTap),
          const SizedBox(height: 12),

          _AiCTA(onTap: _handleAiTap, creditsRemaining: _aiCreditsRemaining, isPremium: isPremium, isSignedIn: auth.isSignedIn),

          if (_creations.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('MY CREATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.textSecondary.withValues(alpha: 0.4))),
            const SizedBox(height: 12),
            ..._creations.map((c) => _CreationCard(cocktail: c, database: widget.database)),
          ] else if (auth.isSignedIn) ...[
            const SizedBox(height: 48),
            const _EmptyCreations(),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SIGNED OUT LANDING
// ═══════════════════════════════════════════════════════════════════════════

class _SignedOutLanding extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignedOutLanding({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
      children: [
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.lock_open, color: AppTheme.accentGold, size: 32),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Back Bar', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Your personal cocktail workshop — create recipes, generate with AI, and share with the community.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.6), height: 1.5),
        ),
        const SizedBox(height: 32),

        _FeatureRow(icon: Icons.edit_outlined, title: 'Create your own cocktails', subtitle: 'Build custom recipes with your own ingredients, methods and notes.', free: '5 free'),
        const SizedBox(height: 16),
        _FeatureRow(icon: Icons.auto_awesome, title: 'Generate with AI', subtitle: 'Describe a flavour profile and get a fully formed recipe instantly.', free: '1 free try', iridescent: true),
        const SizedBox(height: 16),
        _FeatureRow(icon: Icons.people_outline, title: 'Community', subtitle: 'Share creations and discover cocktails from other bartenders.', free: 'Coming soon'),

        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: Divider(color: AppTheme.surfaceLight.withValues(alpha: 0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Free account includes', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.4), fontWeight: FontWeight.w500)),
            ),
            Expanded(child: Divider(color: AppTheme.surfaceLight.withValues(alpha: 0.3))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FreePill(label: '5 cocktail creates'),
            const SizedBox(width: 8),
            _FreePill(label: '1 AI generation'),
          ],
        ),
        const SizedBox(height: 32),

        GestureDetector(
          onTap: onSignIn,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: AppTheme.accentGold, borderRadius: BorderRadius.circular(14)),
            child: const Text('Create free account', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onSignIn,
          child: Text('Already have an account? Sign in', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.5))),
        ),
        const SizedBox(height: 8),
        Text('No card required · Cancel anytime', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.3))),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String free;
  final bool iridescent;

  const _FeatureRow({required this.icon, required this.title, required this.subtitle, required this.free, this.iridescent = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.accentGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: iridescent ? null : Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.2)),
          ),
          foregroundDecoration: iridescent ? BoxDecoration(borderRadius: BorderRadius.circular(12), border: _IridescentBorder()) : null,
          child: Icon(icon, color: AppTheme.accentGold, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.25)),
                    ),
                    child: Text(free, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentGold.withValues(alpha: 0.8))),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.5), height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FreePill extends StatelessWidget {
  final String label;
  const _FreePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentGold.withValues(alpha: 0.75))),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  USAGE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _UsageCard extends StatelessWidget {
  final int createsRemaining;
  final int aiCreditsRemaining;
  const _UsageCard({required this.createsRemaining, required this.aiCreditsRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          _UsageStat(value: '$createsRemaining', label: 'Creates left'),
          Container(width: 0.5, height: 36, color: AppTheme.accentGold.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 20)),
          _UsageStat(value: '$aiCreditsRemaining', label: 'AI credit left'),
          Container(width: 0.5, height: 36, color: AppTheme.accentGold.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 20)),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
            child: Column(
              children: [
                Text('Go Premium', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentGold.withValues(alpha: 0.85))),
                const SizedBox(height: 2),
                Text('Unlimited', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageStat extends StatelessWidget {
  final String value;
  final String label;
  const _UsageStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.accentGold, height: 1.0)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.45))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE CTA
// ═══════════════════════════════════════════════════════════════════════════

class _CreateCTA extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.accentGold, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit_outlined, color: AppTheme.primaryDark, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create a cocktail', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
                  const SizedBox(height: 2),
                  Text('Build your own recipe from scratch', style: TextStyle(fontSize: 12, color: AppTheme.primaryDark.withValues(alpha: 0.6))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.primaryDark.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  AI CTA
// ═══════════════════════════════════════════════════════════════════════════

class _AiCTA extends StatelessWidget {
  final VoidCallback onTap;
  final int creditsRemaining;
  final bool isPremium;
  final bool isSignedIn;

  const _AiCTA({required this.onTap, required this.creditsRemaining, required this.isPremium, required this.isSignedIn});

  @override
  Widget build(BuildContext context) {
    final creditLabel = isPremium
        ? '$creditsRemaining today'
        : !isSignedIn || creditsRemaining > 0 ? '$creditsRemaining credit' : 'Premium';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.15)),
        ),
        foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: _IridescentBorder()),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome, color: AppTheme.accentGold, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Generate with AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Describe your ideal cocktail', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.55))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
              ),
              child: Text(creditLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentGold.withValues(alpha: 0.9))),
            ),
          ],
        ),
      ),
    );
  }
}

class _IridescentBorder extends BoxBorder {
  @override
  BorderSide get bottom => BorderSide.none;
  @override
  BorderSide get top => BorderSide.none;
  @override
  bool get isUniform => false;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection, BoxShape shape = BoxShape.rectangle, BorderRadius? borderRadius}) {
    final rrect = borderRadius != null
        ? borderRadius.toRRect(rect)
        : RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final paint = Paint()
      ..shader = SweepGradient(
        colors: const [Color(0xFFc9a84c), Color(0xFFb464c8), Color(0xFF50b4c8), Color(0xFFc9a84c)],
        stops: const [0.0, 0.33, 0.66, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rrect, paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATION CARD
// ═══════════════════════════════════════════════════════════════════════════

class _CreationCard extends StatelessWidget {
  final UserCocktail cocktail;
  final AppDatabase database;

  const _CreationCard({required this.cocktail, required this.database});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CocktailCreatorScreen(database: database, existing: cocktail),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            _CreationThumb(isAi: cocktail.isAiGenerated),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cocktail.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 3),
                  Text('${cocktail.baseSpirit} · ${cocktail.method} · ${cocktail.glass}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.5))),
                ],
              ),
            ),
            if (cocktail.isAiGenerated)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.25)),
                ),
                child: Text('AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentGold.withValues(alpha: 0.8))),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.3)),
              ),
              child: Text('Yours', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary.withValues(alpha: 0.6))),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }
}

class _CreationThumb extends StatelessWidget {
  final bool isAi;
  const _CreationThumb({required this.isAi});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: isAi ? null : Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.3)),
      ),
      foregroundDecoration: isAi ? BoxDecoration(borderRadius: BorderRadius.circular(10), border: _IridescentBorder()) : null,
      child: const Icon(Icons.local_bar_rounded, color: AppTheme.accentGold, size: 20),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyCreations extends StatelessWidget {
  const _EmptyCreations();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.local_bar_outlined, size: 44, color: AppTheme.textSecondary.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text('No creations yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary.withValues(alpha: 0.4))),
        const SizedBox(height: 6),
        Text('Your cocktails will appear here once created.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.3))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMMUNITY TAB
// ═══════════════════════════════════════════════════════════════════════════

class _CommunityTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.people_outline, color: AppTheme.accentGold, size: 32),
            ),
            const SizedBox(height: 20),
            const Text('Community', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Share your creations and discover cocktails made by other bartenders. Coming soon.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.55), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
