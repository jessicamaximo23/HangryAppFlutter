import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangry_app_flutter/signup_screen.dart';
import 'package:hangry_app_flutter/main.dart';
import 'package:hangry_app_flutter/resetpassword_screen.dart';
import 'package:hangry_app_flutter/activity_main.dart';

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Image.asset(
            'assets/logobackground.png',
            width: 200,
            height: 150,
          ),
          SizedBox(height: 20),
          Text(
            'Sign in',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue, // Cor personalizada
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Enter your email address to sign in.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            'Enjoy your food.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              hintText: 'Enter your email',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              hintText: 'Enter your password',
            ),
            obscureText: true,
          ),
          SizedBox(height: 10),
          TextButton(
            onPressed: () {
              // Navegar para a tela de resetar senha
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResetPasswordScreen(),
                ),
              );
            },
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: Colors.blue, // Cor personalizada
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow, // Cor personalizada
              minimumSize: Size(250, 50),
            ),
              child: Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
          ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () {
                // Navegar para a tela de Sign Up
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignUpScreen(accountType: "user"),
                  ),
                );
              },
              child: Text(
                'Don\'t have an account? Click here',
                style: TextStyle(
                  color: Colors.yellow, // Cor personalizada
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  // function to authenticate user
  void _signIn() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields'),
        ),
      );
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Navegar para a tela principal após o login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'An error occurred'),
        ),
      );
    }
  }
}