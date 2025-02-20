import 'package:flutter/material.dart';

class ResetPasswordScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logobackground.png', width: 200, height: 150),
              SizedBox(height: 20),
              Text("Forgot Password"),
              SizedBox(height: 20),
              Text("Enter your email address and we will send reset instructions."),
              SizedBox(height: 20),
              TextField(),
              SizedBox(height: 20),
              ElevatedButton(onPressed: () {}, child: Text("Reset Password")),
            ],
          ),
        ),
      ),
    );
  }
}