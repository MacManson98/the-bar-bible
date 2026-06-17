import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_theme.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends State<AdminUserManagementScreen> {
  final _searchCtrl = TextEditingController();
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _hasSearched = true;
    });

    try {
      // Search by username prefix first, then email prefix
      final usernameSnap = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '${query}z')
          .limit(20)
          .get();

      final emailSnap = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThan: '${query}z')
          .limit(20)
          .get();

      // Merge and deduplicate by doc ID
      final merged = <String, Map<String, dynamic>>{};
      for (final doc in [...usernameSnap.docs, ...emailSnap.docs]) {
        final data = doc.data();
        data['_uid'] = doc.id;
        merged[doc.id] = data;
      }

      setState(() {
        _results = merged.values.toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _toggleAdmin(Map<String, dynamic> user) async {
    final uid = user['_uid'] as String;
    final email = user['email'] as String? ?? uid;
    final currentlyAdmin = user['is_admin'] as bool? ?? false;
    final action = currentlyAdmin ? 'Remove admin from' : 'Make admin';
    final actionLabel = currentlyAdmin ? 'REMOVE' : 'GRANT';
    final colour = currentlyAdmin ? Colors.redAccent : AppTheme.accentGold;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          '$action user?',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          email,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel,
                style: TextStyle(
                    color: colour, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'is_admin': !currentlyAdmin,
      });

      // Update local results list
      setState(() {
        final index = _results.indexWhere((u) => u['_uid'] == uid);
        if (index != -1) {
          _results[index] = {..._results[index], 'is_admin': !currentlyAdmin};
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyAdmin
                ? 'Admin removed from $email'
                : 'Admin granted to $email'),
            backgroundColor: currentlyAdmin
                ? AppTheme.surfaceLight
                : Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _togglePremium(Map<String, dynamic> user) async {
    final uid = user['_uid'] as String;
    final email = user['email'] as String? ?? uid;
    final currentlyPremium = user['is_premium'] as bool? ?? false;
    final action = currentlyPremium ? 'Remove premium from' : 'Grant premium to';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          '$action user?',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          email,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              currentlyPremium ? 'REMOVE' : 'GRANT',
              style: TextStyle(
                color: currentlyPremium
                    ? Colors.redAccent
                    : AppTheme.accentGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestore.collection('users').doc(uid).update({
        'is_premium': !currentlyPremium,
      });

      setState(() {
        final index = _results.indexWhere((u) => u['_uid'] == uid);
        if (index != -1) {
          _results[index] = {
            ..._results[index],
            'is_premium': !currentlyPremium
          };
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyPremium
                ? 'Premium removed from $email'
                : 'Premium granted to $email'),
            backgroundColor: currentlyPremium
                ? AppTheme.surfaceLight
                : Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        title: const Text(
          'USER MANAGEMENT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by username or email...',
                      hintStyle: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.textSecondary, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppTheme.textSecondary, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _results = [];
                                  _hasSearched = false;
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.surfaceLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.surfaceLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppTheme.accentGold),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _search(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSearching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primaryDark),
                        )
                      : const Text('Search',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Hint text
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Prefix search — e.g. "john" matches username or email',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          ),

          const Divider(color: AppTheme.surfaceLight, height: 1),

          // Results
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: $_error\n\nYou may need to create a Firestore index on the "email" field.',
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_accounts_outlined,
                size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text(
              'Search for a user by email',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(color: AppTheme.surfaceLight, height: 1),
      itemBuilder: (context, index) {
        final user = _results[index];
        final uid = user['_uid'] as String? ?? '';
        final email = user['email'] as String? ?? 'No email';
        final isAdmin = user['is_admin'] as bool? ?? false;
        final isPremium = user['is_premium'] as bool? ?? false;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username + email + copy UID
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((user['username'] as String? ?? '').isNotEmpty)
                          Text(
                            '@${user['username']}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentGold,
                            ),
                          ),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: uid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UID copied')),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          '${uid.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.6),
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy,
                            size: 13,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Badges + toggles
              Row(
                children: [
                  _StatusBadge(label: 'ADMIN', active: isAdmin),
                  const SizedBox(width: 8),
                  _StatusBadge(label: 'PREMIUM', active: isPremium),
                  const Spacer(),
                  _ActionButton(
                    label: isAdmin ? 'Remove Admin' : 'Make Admin',
                    destructive: isAdmin,
                    onTap: () => _toggleAdmin(user),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: isPremium ? 'Remove Pro' : 'Grant Pro',
                    destructive: isPremium,
                    onTap: () => _togglePremium(user),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool active;

  const _StatusBadge({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.accentGold.withValues(alpha: 0.15)
            : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active
              ? AppTheme.accentGold.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: active ? AppTheme.accentGold : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.destructive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: destructive
              ? Colors.redAccent.withValues(alpha: 0.1)
              : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: destructive
                ? Colors.redAccent.withValues(alpha: 0.4)
                : AppTheme.surfaceLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: destructive ? Colors.redAccent : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
