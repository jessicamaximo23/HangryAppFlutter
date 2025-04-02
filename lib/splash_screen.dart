import 'package:flutter/material.dart';
import 'account_screen.dart';
import 'package:provider/provider.dart';
import 'authentication_manager.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(seconds: 2), () {
      checkAuthAndRedirect();
    });
  }

  void checkAuthAndRedirect() {
    if (!mounted) return;


    final authManager = Provider.of<AuthenticationManager>(context, listen: false);
    if (!authManager.isAuthenticated) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AccountScreen(),
    ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
      Image.asset(
          'images/assets/logobackground.png',
          width: 200,
          height: 200,
        ),
        SizedBox(height: 20),
        CircularProgressIndicator(),
  ],
        ),
      ),
    );
  }
}