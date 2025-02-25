import 'package:flutter/material.dart';
import 'package:hangry_app_flutter/signin_screen.dart';
import 'package:hangry_app_flutter/signup_screen.dart';
import 'package:hangry_app_flutter/resetpassword_screen.dart';

void main() {
  runApp(AccountScreen());
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({Key? key}) : super(key: key);

  //Same colors for all apps
  final Color hangryYellow = const Color(0xFFFCBF49);
  final Color hangryBlue = const Color(0xFF003049);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Container(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(
                  'images/assets/logobackground.png',
                  width: 200,
                  height: 150,
                ),
                SizedBox(height: 16.0),
                Image.asset(
                  'images/assets/image1.png',
                  width: 200,
                  height: 200,
                ),
                SizedBox(height: 16.0),

                // Choose your account Text
                Text(
                  'Choose your account',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontFamily: 'RammettoOne-Regular',
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _buildAccountButton(context, 'Driver', 'driver'),
                    const SizedBox(width: 16.0),
                    _buildAccountButton(context, 'User', 'user'),
                    const SizedBox(width: 16.0),
                    _buildAccountButton(context, 'Restaurant', 'restaurant'),
                  ],
                ),
                SizedBox(height: 24.0),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        //IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                        //need to find a way to not pass accountType here.
                        builder: (context) => SignInScreen(accountType: "",),
                      ),
                    );
                  },
                  child: Text(
                    'Already have an account? Sign In',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: hangryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountButton(BuildContext context, String title, String accountType) {
    return ElevatedButton(
      onPressed: () => _redirectToSignUp(context, accountType),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: hangryYellow,
        textStyle: const TextStyle(
          fontSize: 16,
          fontFamily: 'RammettoOne-Regular',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      child: Text(title),
    );
  }

  void _redirectToSignUp(BuildContext context, String accountType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignUpScreen(accountType: accountType),
      ),
    );
  }
}
