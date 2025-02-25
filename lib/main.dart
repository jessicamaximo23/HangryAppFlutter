import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hangry_app_flutter/splash_screen.dart';
import 'package:hangry_app_flutter/signin_screen.dart';
import 'package:hangry_app_flutter/driver_screen.dart';
import 'package:hangry_app_flutter/restaurant_screen.dart'; // Adicionei o import para RestaurantScreen, caso necessário

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hangry App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/signin_screen', // Set the initial route
      routes: {
        // '/signin_screen': (context) => SignInScreen(),
        '/driver': (context) => DriverScreen(),
        '/restaurant': (context) => RestaurantScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/signin_screen') {
          final args = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (context) => SignInScreen(accountType: args ?? 'user'), // Passa o accountType para SignInScreen
          );
        }
        // Adicione condições de rota para Driver e Restaurant, se necessário.
        return null;
      },
    );
  }
}
