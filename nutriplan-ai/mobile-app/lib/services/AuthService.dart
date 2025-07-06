import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Auth change user stream
  Stream<User?> get user => _auth.authStateChanges();

  /// Sign in with email & password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Login Error: ${e.message}');
      rethrow;
    }
  }

  /// Register with email & password
  Future<UserCredential?> registerWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Register Error: ${e.message}');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password Reset Error: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return null; // Canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Sign out (email/google)
  Future<void> signOut() async {
    try {
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign Out Error: $e');
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  /// Get user UID
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  /// Get user email
  String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Get display name
  String? getDisplayName() {
    return _auth.currentUser?.displayName;
  }

  /// Get user photo URL
  String? getPhotoUrl() {
    return _auth.currentUser?.photoURL;
  }
}
