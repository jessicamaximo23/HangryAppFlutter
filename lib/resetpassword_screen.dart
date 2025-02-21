import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordScreen extends StatefulWidget {
  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _resetPassword() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage("Please enter your email");
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showMessage("Password reset email sent.");
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred.";
      if (e.code == 'user-not-found') {
        message = "Email is not registered.";
      } else {
        message = e.message ?? message;
      }
      _showMessage(message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logobackground.png', width: 200, height: 150),
              SizedBox(height: 20),
              Text("Forgot Password"),
              SizedBox(height: 20),
              Text("Enter your email address and we will send reset instructions."),
              SizedBox(height: 20),
              TextField(),
              SizedBox(height: 20),
              ElevatedButton(onPressed: () {}, child: Text("Reset Password")),
            ],
          ),
        ),
      ),
    );
  }
}