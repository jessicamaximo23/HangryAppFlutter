import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({Key? key}) : super(key: key);

  @override
  _RestaurantScreen createState() => _RestaurantScreen();
}

class _RestaurantScreen extends State<RestaurantScreen> {

  //SignOut created. Just add to the button you want to use.
  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      Navigator.pushReplacementNamed(context, '/account_screen');
    } catch (e) {
      print("Error to log out: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to logout. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Screen'),
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Text(
          'Hello, World!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}