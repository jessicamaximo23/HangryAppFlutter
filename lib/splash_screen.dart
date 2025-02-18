import 'package:flutter/material.dart';
import 'account_screen.dart'; // Importe a tela AccountScreen

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Simula um atraso de 3 segundos antes de navegar para a AccountScreen
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AccountScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Cor de fundo branca
      body: Center(
        child: Image.asset(
          'assets/logobackground.png', // Caminho da imagem
          width: 200, // Largura da imagem
          height: 200, // Altura da imagem
        ),
      ),
    );
  }
}