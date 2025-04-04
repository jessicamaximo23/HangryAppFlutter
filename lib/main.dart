import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hangry_app_flutter/signin_screen.dart';
import 'package:hangry_app_flutter/driver_screen.dart';
// Stripe import?
import 'package:hangry_app_flutter/stripe_payment_service.dart';
import 'package:hangry_app_flutter/admin_panel_screen.dart';
import 'package:hangry_app_flutter/splash_screen.dart';
import 'package:hangry_app_flutter/user_screen.dart';
import 'package:hangry_app_flutter/restaurant_screen.dart';
import 'package:hangry_app_flutter/account_screen.dart';
import 'package:provider/provider.dart';
import 'authentication_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stripe
  await StripePaymentService.initialize();

  // Firebase initialization
  await Firebase.initializeApp();


  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthenticationManager(),
      child: MyApp(),
    ),
  );
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
      home: AuthWrapper(),
      routes: {
        '/signin_screen': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as String?;
          return SignInScreen(accountType: args ?? 'user');
        },
        '/account_screen': (context) => AccountScreen(),
        '/driver': (context) => DriverScreen(),
        '/restaurant': (context) => RestaurantScreen(),
        '/user': (context) => UserScreen(),
        '/admin': (context) => AdminDashboardScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authManager = Provider.of<AuthenticationManager>(context);
    if (authManager.isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (authManager.isAuthenticated) {
      if (authManager.accountType == 'admin') {
        return AdminDashboardScreen();
      }
      switch (authManager.accountType) {
        case 'restaurant':
          return RestaurantScreen();
        case 'driver':
          return DriverScreen();
        case 'user':
          return UserScreen();
        default:
          return AccountScreen();
      }
    } else {
      return SplashScreen();
    }
  }
}