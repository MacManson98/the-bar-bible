import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/database.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/user_sync_service.dart';

/// Professional favorite button widget following Instagram/Pinterest pattern
/// - Heart icon (outline when not favorited, filled when favorited)
/// - Instant visual feedback
/// - Haptic feedback on tap
/// - Optional snackbar message
class FavoriteButton extends StatefulWidget {
  final AppDatabase database;
  final String firestoreId;
  final bool showSnackbar;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;
  
  const FavoriteButton({
    super.key,
    required this.database,
    required this.firestoreId,
    this.showSnackbar = true,
    this.activeColor,
    this.inactiveColor,
    this.size = 24,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> 
    with SingleTickerProviderStateMixin {
  bool isFavorited = false;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _checkFavoriteStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    final favorited = await widget.database.isFavorited(widget.firestoreId);
    if (mounted) {
      setState(() {
        isFavorited = favorited;
        isLoading = false;
      });
    }
  }

  Future<void> _pushFavouritesToCloud(String uid) async {
    final synced = await UserSyncService(widget.database).pushFavourites(uid);
    if (!synced && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t sync to cloud — will retry later')),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    setState(() { isFavorited = !isFavorited; });
    _animationController.forward().then((_) { _animationController.reverse(); });
    final uid = context.read<AuthService>().currentUser?.uid;
    try {
      await widget.database.toggleFavorite(widget.firestoreId);

      // Push to Firestore if signed in — don't block success feedback below
      // on the sync result, only surface it if the push fails.
      if (uid != null) {
        _pushFavouritesToCloud(uid);
      }

      // Show snackbar if enabled
      if (widget.showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorited ? '❤️ Added to Favorites' : 'Removed from Favorites',
            ),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isFavorited 
                ? AppTheme.accentGold 
                : AppTheme.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          isFavorited = !isFavorited;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorite'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.textSecondary,
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        onPressed: _toggleFavorite,
        icon: Icon(
          isFavorited ? Icons.favorite : Icons.favorite_border,
          color: isFavorited 
              ? (widget.activeColor ?? AppTheme.accentGold)
              : (widget.inactiveColor ?? AppTheme.textSecondary),
        ),
        iconSize: widget.size,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
