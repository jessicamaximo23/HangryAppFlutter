import 'package:flutter/material.dart';
import 'package:hangry_app_flutter/splash_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(), // Define a SplashScreen como a tela inicial
    );
  }
}