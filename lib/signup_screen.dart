import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hangry_app_flutter/signin_screen.dart';

class SignUpScreen extends StatefulWidget {
  final String accountType;

  const SignUpScreen({Key? key, required this.accountType}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  void _validateFields() {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    //logic to make sure registration of user is valid
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showToast("Please fill in all fields");
      return;
    }

    if (!RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email)) {
      _showToast("Invalid email address");
      return;
    }

    if (password.length < 6) {
      _showToast("Password must be at least 6 characters");
      return;
    }

      _registerUser(name, email, password);

  }


    //implemented logic to register user name, email and password
  void _registerUser(String name, String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        String userId = userCredential.user!.uid;

        Map<String, dynamic> userData = {
          "name": name,
          "email": email,
          "accountType": widget.accountType,
          "status": "active",
          "createdAt": DateTime.now().millisecondsSinceEpoch,
        };

        await _databaseRef.child("users").child(userId).set(userData);

        _showToast("Sign up successful!");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SignInScreen(accountType: widget.accountType,)),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showToast("Sign up failed: ${e.message}");
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Image.asset(
              'images/assets/logobackground.png',
              width: 200,
              height: 150,
            ),
            SizedBox(height: 8),
            Text(
              'Create Account',
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: Colors.black, // Correspondente ao azul
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'Enter your email and password to create your account.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignInScreen(accountType: widget.accountType)),
                );
              },
              child: Text(
                'Already have an account?',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFFFC107), // Correspondente ao amarelo
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),

            SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 50,
            child: ElevatedButton(
              onPressed: _validateFields,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFC107),
              ),
              child: Text('Sign Up'),
            ),
          ),
          ],
        ),
      ),
    );
  }
}