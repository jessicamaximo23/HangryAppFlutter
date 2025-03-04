import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangry_app_flutter/restaurant_screen.dart';
import 'package:hangry_app_flutter/signup_screen.dart';
import 'package:hangry_app_flutter/resetpassword_screen.dart';
import 'package:hangry_app_flutter/user_screen.dart';

import 'driver_screen.dart';


class SignInScreen extends StatefulWidget {
  final String accountType;

  SignInScreen({required this.accountType});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}


class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
            Image.asset(
            'images/assets/logobackground.png',
            width: 200,
            height: 150,
          ),
          SizedBox(height: 20),
          Text(
            'Sign in',
            style: TextStyle(
              fontFamily: 'RammettoOne-Regular',
              fontSize: 35,
              fontWeight: FontWeight.bold,
              color: hangryBlue,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Enter your email address to sign in.',
            style: TextStyle(
              fontFamily: 'RammettoOne-Regular',
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.left,
          ),
          Text(
            'Enjoy your food.',
            style: TextStyle(
              fontFamily: 'RammettoOne-Regular',
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.left,
          ),
          SizedBox(height: 20),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email Adress',
              hintText: 'Enter your email',
              border: InputBorder.none,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey), // Linha simples
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue), // Cor da linha quando o campo estiver focado
              ),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              border: InputBorder.none, // Removendo a borda
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey), // Linha simples
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue), // Cor da linha quando o campo estiver focado
              ),
            ),
            obscureText: true,
          ),
          SizedBox(height: 10),
          TextButton(
            onPressed: () {
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
                color: Colors.grey,
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SignUpScreen(accountType: widget.accountType),
                  ),
                );
              },
              child: Wrap(
                alignment: WrapAlignment.center, // Garante que o Row ocupe apenas o espaço necessário
                children: [
                  Text(
                    'Don\'t have an account? ',
                    style: TextStyle(
                      fontSize: 25,
                      color: Colors.black, // Cor personalizada
                    ),
                  ),
                  SizedBox(width: 10), // Espaçamento entre as duas partes do texto
                  Text(
                    'Create one here!',
                    style: TextStyle(
                      color: Colors.orange, // Cor personalizada
                      fontSize: 25,
                      fontWeight: FontWeight.bold, // Deixar a segunda parte mais destacada, se desejar
                      ),
                    ),
                  ],
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
      // get user UID
      String uid = userCredential.user!.uid;
      // Referencing user in database
      DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid');
      // Search for user data on database
      DatabaseEvent event = await ref.once();
      DataSnapshot snapshot = event.snapshot;

      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data not found')),
        );
        return;
      }

      Map<dynamic, dynamic> userData = snapshot.value as Map<dynamic, dynamic>;
      String accountType = userData['accountType'];

      // Direcionamento com base no accountType
      Widget nextScreen;
      switch (accountType) {
        case 'user':
          nextScreen = UserScreen();
          break;
        case 'driver':
          nextScreen = DriverScreen();
          break;
        case 'restaurant':
          nextScreen = RestaurantScreen();
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid account type')),
          );
          return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => nextScreen),
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