import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';

/// Shows a sign-in bottom sheet. Returns true if the user successfully signed in.
Future<bool> showAuthSheet(BuildContext context, {String? reason}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => AuthSheet(reason: reason),
  );
  return result == true;
}

class AuthSheet extends StatefulWidget {
  final String? reason;
  const AuthSheet({super.key, this.reason});

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  bool _showEmailForm = false;
  bool _isCreatingAccount = false;
  bool _isLoading = false;
  String? _error;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogle() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      await auth.signInWithGoogle();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _error = _friendlyError(e); _isLoading = false; });
    }
  }

  Future<void> _handleApple() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      await auth.signInWithApple();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _error = _friendlyError(e); _isLoading = false; });
    }
  }

  Future<void> _handleEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      if (_isCreatingAccount) {
        await auth.createAccountWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          _usernameController.text.trim().toLowerCase(),
        );
      } else {
        await auth.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _error = _friendlyError(e); _isLoading = false; });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('wrong-password') || msg.contains('invalid-credential') || msg.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('identity token is null')) return 'Apple Sign In failed. Please try again.';
    if (msg.contains('user-disabled')) return 'This account has been disabled.';
    if (msg.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (msg.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (msg.contains('invalid-email')) return 'Please enter a valid email address.';
    if (msg.contains('user-not-found')) return 'No account found with this email.';
    if (msg.contains('cancelled') || msg.contains('canceled')) return '';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.3)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 0, 24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Gold accent line
          Container(
            height: 2, width: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentGold,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            _showEmailForm
                ? (_isCreatingAccount ? 'Create account' : 'Sign in')
                : 'Join The Bar Bible',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.reason ?? 'Create a free account to access Back Bar features.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: AppTheme.accentGold),
            )
          else if (_showEmailForm)
            _buildEmailForm()
          else
            _buildSocialButtons(),

          if (_error != null && _error!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.redAccent.withValues(alpha: 0.9)),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        _SocialButton(
          label: 'Continue with Apple',
          icon: Icons.apple,
          onTap: _handleApple,
          color: AppTheme.textPrimary,
          background: AppTheme.surfaceLight.withValues(alpha: 0.15),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: 'Continue with Google',
          svgLetter: 'G',
          onTap: _handleGoogle,
          color: AppTheme.textPrimary,
          background: AppTheme.surfaceLight.withValues(alpha: 0.08),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: 'Continue with email',
          icon: Icons.mail_outline,
          onTap: () => setState(() => _showEmailForm = true),
          color: AppTheme.textSecondary,
          background: Colors.transparent,
          border: true,
        ),
        const SizedBox(height: 16),
        Text(
          'Free to join · No card required',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_isCreatingAccount) ...[
            TextFormField(
              controller: _usernameController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: _inputDecoration('Username'),
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Choose a username';
                if (v.trim().length < 3) return 'At least 3 characters';
                final validChars = RegExp(r'^[a-zA-Z0-9_]+$');
                if (!validChars.hasMatch(v.trim())) {
                  return 'Letters, numbers and underscores only';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: _inputDecoration('Email'),
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: _inputDecoration('Password'),
            validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
          ),
          if (_isCreatingAccount) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: _inputDecoration('Confirm Password'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password';
                if (v != _passwordController.text) return 'Passwords do not match';
                return null;
              },
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                _isCreatingAccount ? 'Create account' : 'Sign in',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isCreatingAccount ? 'Already have an account? ' : 'No account? ',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _isCreatingAccount = !_isCreatingAccount;
                  _error = null;
                  _usernameController.clear();
                  _confirmPasswordController.clear();
                }),
                child: Text(
                  _isCreatingAccount ? 'Sign in' : 'Create one',
                  style: const TextStyle(fontSize: 13, color: AppTheme.accentGold, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() { _showEmailForm = false; _error = null; }),
            child: Text(
              'Back',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 14),
      filled: true,
      fillColor: AppTheme.primaryDark.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.surfaceLight.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.6)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? svgLetter;
  final VoidCallback onTap;
  final Color color;
  final Color background;
  final bool border;

  const _SocialButton({
    required this.label,
    this.icon,
    this.svgLetter,
    required this.onTap,
    required this.color,
    required this.background,
    this.border = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: border
                ? AppTheme.surfaceLight.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, color: color, size: 20)
            else if (svgLetter != null)
              Text(svgLetter!, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
