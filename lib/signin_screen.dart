import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hangry_app_flutter/admin_panel_screen.dart';
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


  final List<String> adminEmails = [
    'jessicamaximo23@gmail.com',
    'wandrey.wic@gmail.com',
    'villantijulien@gmail.com',

  ];
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
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
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
              border: InputBorder.none,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
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
              backgroundColor: hangryYellow
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
                  SizedBox(width: 10),
                  Text(
                    'Create one here!',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
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
      if (adminEmails.contains(email)) {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDashboardScreen(),
          ),
        );
        return;
      }

      String uid = userCredential.user!.uid;
      DatabaseReference ref = FirebaseDatabase.instance.ref('users/$uid');
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
        case 'admin':
          nextScreen = AdminDashboardScreen();
          break;
        default:
          nextScreen = SignInScreen(accountType: accountType);
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