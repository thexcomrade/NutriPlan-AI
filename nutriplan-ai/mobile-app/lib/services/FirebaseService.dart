import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutriplan_ai/models/UserModel.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registers a new user with email and password
  Future<User?> registerUser(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Registration error: $e");
      return null;
    }
  }

  /// Logs in user with email and password
  Future<User?> loginUser(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }

  /// Sends a password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Password reset error: $e");
    }
  }

  /// Logs out the current user
  Future<void> logoutUser() async {
    await _auth.signOut();
  }

  /// Returns the currently logged-in user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Stores user profile in Firestore
  Future<void> saveUserProfile(UserModel userModel) async {
    try {
      await _firestore.collection('users').doc(userModel.uid).set(userModel.toMap());
    } catch (e) {
      print("Error saving user profile: $e");
    }
  }

  /// Fetches user profile from Firestore
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
    return null;
  }

  /// Realtime updates to user data
  Stream<UserModel?> streamUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
}
