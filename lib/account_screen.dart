import 'package:flutter/material.dart';
import 'package:hangry_app_flutter/signin_screen.dart';
import 'package:hangry_app_flutter/signup_screen.dart';
import 'package:hangry_app_flutter/resetpassword_screen.dart';

void main() {
  runApp(AccountScreen());
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Container(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Logo Image
                Image.asset(
                  'images/assets/logobackground.png', // Caminho da imagem
                  width: 200,
                  height: 150,
                ),
                SizedBox(height: 24.0), // Espaçamento

                // Central Image
                Image.asset(
                  'images/assets/image1.png', // Caminho da imagem
                  width: 200,
                  height: 200,
                ),
                SizedBox(height: 16.0), // Espaçamento

                // Choose your account Text
                Text(
                  'Choose your account',
                  style: TextStyle(
                    fontSize: 20.0,
                    color: Colors.blue, // Substitua pela cor correta
                  ),
                ),
                SizedBox(height: 16.0), // Espaçamento

                // Horizontal Scroll View with Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      // Driver Button
                      ElevatedButton(
                        onPressed: () => _redirectToSignUp(context, "driver"),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.blue, backgroundColor: Colors.yellow, // Substitua pela cor correta
                          minimumSize: Size(120, 36),
                        ),
                        child: Text('Driver'),
                      ),
                      SizedBox(width: 16.0), // Espaçamento

                      // User Button
                      ElevatedButton(
                        onPressed: ()=> _redirectToSignUp(context, "user"),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.blue, backgroundColor: Colors.yellow, // Substitua pela cor correta
                          minimumSize: Size(120, 36),
                        ),
                        child: Text('User'),
                      ),
                      SizedBox(width: 16.0), // Espaçamento

                      // Restaurant Button
                      ElevatedButton(
                        onPressed: ()=> _redirectToSignUp(context, "restaurant"),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.blue, backgroundColor: Colors.yellow, // Substitua pela cor correta
                          minimumSize: Size(150, 36),
                        ),
                        child: Text('Restaurant'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.0),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        //IMPORTANT !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                        //need to find a way to not pass accountType here.
                        builder: (context) => SignInScreen(accountType: "user",),
                      ),
                    );
                  },
                  child: Text(
                    'Already have an account? Sign In',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.blue, // Substitua pela cor correta
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
  void _redirectToSignUp(BuildContext context, String accountType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignUpScreen(accountType: accountType),
      ),
    );
  }
}
