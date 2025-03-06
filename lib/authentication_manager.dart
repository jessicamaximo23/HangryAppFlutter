import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AuthenticationManager extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  User? _user;
  String? _accountType;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  User? get user => _user;
  String? get accountType => _accountType;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  AuthenticationManager() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((user) {
      _user = user;
      _isAuthenticated = user != null;
      notifyListeners();

      if (user != null) {
        _fetchAccountType(user.uid);
      } else {
        _accountType = null;
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _user = result.user;
      _isAuthenticated = true;

      if (_user != null) {
        await _fetchAccountType(_user!.uid);
      }
    } catch (error) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchAccountType(String userId) async {
    try {
      final snapshot = await _database.child('users').child(userId).child('accountType').get(); // Alterado para 'accountType'
      if (snapshot.exists) {
        _accountType = snapshot.value as String?;
      } else {
        _accountType = null;
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Error fetching account type: $error');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      _accountType = null;
      _isAuthenticated = false;
      notifyListeners();
    } catch (error) {
      debugPrint('Error signing out: $error');
      rethrow;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (error) {
      debugPrint('Error resetting password: $error');
      return false;
    }
  }
}
