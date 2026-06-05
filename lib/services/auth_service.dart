import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static const int _freeCreateLimit = 5;
  static const int _freeAiLimit = 1;
  static const int _premiumDailyAiLimit = 20;

  AuthService() {
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  // ── Sign in methods ────────────────────────────────────────────────────────

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(result.user!);
    notifyListeners();
    return result;
  }

  Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final result = await _auth.signInWithCredential(oauthCredential);
    await _ensureUserDoc(result.user!);
    notifyListeners();
    return result;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserDoc(result.user!);
    notifyListeners();
    return result;
  }

  Future<UserCredential> createAccountWithEmail(
    String email,
    String password,
  ) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureUserDoc(result.user!);
    notifyListeners();
    return result;
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── User doc ───────────────────────────────────────────────────────────────

  Future<void> _ensureUserDoc(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'display_name': user.displayName,
        'created_at': FieldValue.serverTimestamp(),
        'creates_used': 0,
        'ai_credits_used': 0,
        'ai_credits_reset_date': DateTime.now().toIso8601String().substring(0, 10),
        'is_premium': false,
      });
    }
  }

  // ── Limit checks ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserLimits() async {
    final user = currentUser;
    if (user == null) return {'creates_used': 0, 'ai_credits_used': 0, 'is_premium': false};

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _ensureUserDoc(user);
      return {'creates_used': 0, 'ai_credits_used': 0, 'is_premium': false};
    }
    return doc.data() ?? {};
  }

  Future<bool> canCreateCocktail(bool isPremium) async {
    if (isPremium) return true;
    final limits = await getUserLimits();
    final used = limits['creates_used'] as int? ?? 0;
    return used < _freeCreateLimit;
  }

  Future<bool> canUseAi(bool isPremium) async {
    if (isPremium) {
      final limits = await getUserLimits();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final resetDate = limits['ai_credits_reset_date'] as String? ?? today;
      final aiUsedToday = resetDate == today
          ? (limits['ai_credits_used_today'] as int? ?? 0)
          : 0;
      return aiUsedToday < _premiumDailyAiLimit;
    }
    final limits = await getUserLimits();
    final used = limits['ai_credits_used'] as int? ?? 0;
    return used < _freeAiLimit;
  }

  Future<int> createsRemaining(bool isPremium) async {
    if (isPremium) return 999;
    final limits = await getUserLimits();
    final used = limits['creates_used'] as int? ?? 0;
    return (_freeCreateLimit - used).clamp(0, _freeCreateLimit);
  }

  Future<int> aiCreditsRemaining(bool isPremium) async {
    if (isPremium) {
      final limits = await getUserLimits();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final resetDate = limits['ai_credits_reset_date'] as String? ?? today;
      final aiUsedToday = resetDate == today
          ? (limits['ai_credits_used_today'] as int? ?? 0)
          : 0;
      return (_premiumDailyAiLimit - aiUsedToday).clamp(0, _premiumDailyAiLimit);
    }
    final limits = await getUserLimits();
    final used = limits['ai_credits_used'] as int? ?? 0;
    return (_freeAiLimit - used).clamp(0, _freeAiLimit);
  }

  Future<void> incrementCreatesUsed() async {
    final user = currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({
      'creates_used': FieldValue.increment(1),
    });
  }

  Future<void> incrementAiCreditsUsed(bool isPremium) async {
    final user = currentUser;
    if (user == null) return;

    if (isPremium) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await _firestore.collection('users').doc(user.uid).update({
        'ai_credits_used_today': FieldValue.increment(1),
        'ai_credits_reset_date': today,
      });
    } else {
      await _firestore.collection('users').doc(user.uid).update({
        'ai_credits_used': FieldValue.increment(1),
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
