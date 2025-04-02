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
  String? _authErrorMessage;

  VoidCallback? _onLogoutCallback;

  User? get user => _user;
  String? get accountType => _accountType;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get authErrorMessage => _authErrorMessage;

  AuthenticationManager() {

    _auth.authStateChanges().listen((user) async {
      _user = user;

      if (user != null) {
    bool isValid = await _validateUserStatus(user.uid);

    if (!isValid) {

    await signOut();
    return;
      }

    _isAuthenticated = true;
    await _fetchAccountType(user.uid);
      } else {
        _accountType = null;
        _isAuthenticated = false;
        // Call the logout callback if the user logs out
        _onLogoutCallback?.call();
      }

      notifyListeners();
    });
  }



  //     _isAuthenticated = user != null;
  //     notifyListeners();
  //
  //     if (user != null) {
  //       _fetchAccountType(user.uid);
  //     } else {
  //       _accountType = null;
  //       _onLogoutCallback?.call();
  //     }
  //   });
  // }


  void setOnLogoutCallback(VoidCallback callback) {
    _onLogoutCallback = callback;
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _authErrorMessage = null;
    notifyListeners();

    try {
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _user = result.user;

      if (_user != null) {
        // Validate user status before considering them authenticated
        bool isValid = await _validateUserStatus(_user!.uid);

        if (!isValid) {
          // If not valid, sign out and don't set as authenticated
          await _auth.signOut();
          _user = null;
          _isAuthenticated = false;
          return;
        }

        _isAuthenticated = true;
        await _fetchAccountType(_user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      _authErrorMessage = e.message;
      rethrow;
    } catch (error) {
      _authErrorMessage = 'An error occurred during sign in';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  //     if (_user != null) {
  //       await _fetchAccountType(_user!.uid);
  //     }
  //   } catch (error) {
  //     rethrow;
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }
  Future<bool> _validateUserStatus(String userId) async {
    try {
      print("Validating user status for: $userId");
      final userSnapshot = await _database.child('users').child(userId).get();

      if (!userSnapshot.exists) {
        print("User data not found");
        _authErrorMessage = 'User data not found';
        return false;
      }

      Map<dynamic, dynamic> userData = userSnapshot.value as Map<dynamic, dynamic>;
      print("User data: $userData");

      // Check if account is active
      String status = userData['status'] ?? 'active';
      print("User status: $status");
      if (status != 'active') {
        print("User is inactive");
        _authErrorMessage = 'Your account has been deactivated. Please contact support.';
        return false;
      }

      // For drivers and restaurants, also check if they are approved
      String accountType = userData['accountType'] ?? '';
      print("Account type: $accountType");
      bool isApproved = userData['isApproved'] ?? false;
      print("Is approved: $isApproved");
      if ((accountType == 'driver' || accountType == 'restaurant') && !isApproved) {
        print("User is not approved");
        _authErrorMessage = 'Your account is pending approval. Please check back later.';
        return false;
      }

      print("User validation successful");
      return true;
    } catch (error) {
      print("Error validating user: $error");
      debugPrint('Error validating user status: $error');
      _authErrorMessage = 'Error validating user account';
      return false;
    }
  }

  Future<void> _fetchAccountType(String userId) async {
    try {
      final snapshot = await _database.child('users').child(userId).child('accountType').get();
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
    _authErrorMessage = null;
    notifyListeners();
    // Call the logout callback after logout is completed
    _onLogoutCallback?.call();
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