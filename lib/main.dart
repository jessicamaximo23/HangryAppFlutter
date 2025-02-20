import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hangry_app_flutter/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Garante que o Flutter está pronto antes da inicialização do Firebase
  await Firebase.initializeApp(); // Inicializa o Firebase
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