import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hangry_app_flutter/splash_screen.dart';
import 'package:hangry_app_flutter/signin_screen.dart';
import 'package:hangry_app_flutter/driver_screen.dart';
import 'package:hangry_app_flutter/user_screen.dart';
import 'package:hangry_app_flutter/restaurant_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove debug banner
      title: 'Hangry App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/', // Set SplashScreen as the initial route
      routes: {
        '/': (context) => SplashScreen(), // SplashScreen route
        '/signin_screen': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as String?;
          return SignInScreen(accountType: args ?? 'user'); // Pass accountType to SignInScreen
        },
        '/driver': (context) => DriverScreen(),
        '/restaurant': (context) => RestaurantScreen(),
        '/user': (context) => UserScreen(),
      },
    );
  }
}