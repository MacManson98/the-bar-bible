import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final Future<void> Function() onReady;
  final Widget child;

  const SplashScreen({
    super.key,
    required this.onReady,
    required this.child,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _ready = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      widget.onReady(),
      Future.delayed(const Duration(milliseconds: 2000)),
    ]);
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentGold.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.local_bar,
                  color: AppTheme.accentGold,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'THE BAR BIBLE',
                style: TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your cocktail reference',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
