import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class StripePaymentService {
  // Your Stripe API keys
  static const String _publishableKey = "pk_test_51R6vLbFNw9lp138rinCEx1OsqiOLmXUiMmhMrC25g1cpa1jPFEoG6rWadbyCrTW409h4H6Gt0S038B25bunhtDdk00kXLNh9zk";
  static const String _secretKey = "";

  // API URLs
  static const String _customersUrl = "https://api.stripe.com/v1/customers";
  static const String _ephemeralKeysUrl = "https://api.stripe.com/v1/ephemeral_keys";
  static const String _paymentIntentsUrl = "https://api.stripe.com/v1/payment_intents";

  // Initialize Stripe
  static Future<void> initialize() async {
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
  }

  // Make a Stripe API call
  static Future<Map<String, dynamic>> _callStripeApi({
    required String url,
    required Map<String, dynamic> body,
    String stripeVersion = "2022-11-15",
  }) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Stripe-Version': stripeVersion,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to call Stripe API: ${response.body}');
    }
  }

  // Create a new Stripe customer
  static Future<String> createCustomer() async {
    try {
      final customerId = await FirebaseAuth.instance.currentUser?.uid;
      final email = FirebaseAuth.instance.currentUser?.email;

      final response = await _callStripeApi(
        url: _customersUrl,
        body: {
          'description': 'Customer for Hangry App',
          if (email != null) 'email': email,
          if (customerId != null) 'metadata[firebase_uid]': customerId,
        },
      );

      return response['id'];
    } catch (e) {
      throw Exception('Failed to create customer: $e');
    }
  }

  // Create an ephemeral key
  static Future<String> createEphemeralKey(String customerId) async {
    try {
      final response = await _callStripeApi(
        url: _ephemeralKeysUrl,
        body: {'customer': customerId},
        stripeVersion: "2022-11-15", // Make sure to use the correct Stripe API version
      );

      return response['id'];
    } catch (e) {
      throw Exception('Failed to create ephemeral key: $e');
    }
  }

  // Create a payment intent
  static Future<String> createPaymentIntent(String customerId, int amount, String currency) async {
    try {
      final response = await _callStripeApi(
        url: _paymentIntentsUrl,
        body: {
          'customer': customerId,
          'amount': amount.toString(),
          'currency': currency,
          'automatic_payment_methods[enabled]': 'true',
        },
      );

      return response['client_secret'];
    } catch (e) {
      throw Exception('Failed to create payment intent: $e');
    }
  }

  // Process the payment
  static Future<bool> processPayment(BuildContext context, double amount) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 1. Create a customer
      final customerId = await createCustomer();
      print('Customer created: $customerId');

      // 2. Create an ephemeral key
      final ephemeralKey = await createEphemeralKey(customerId);
      print('Ephemeral key created: $ephemeralKey');

      // 3. Create a payment intent (convert amount to cents)
      final amountInCents = (amount * 100).round();
      final clientSecret = await createPaymentIntent(customerId, amountInCents, 'cad');
      print('Client secret created: $clientSecret');

      // Close loading dialog
      Navigator.pop(context);

      // 4. Show the payment sheet
      final paymentSheetResult = await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Hangry App',
          style: ThemeMode.system,
        ),
      );

      if (paymentSheetResult != null) {
        throw Exception('Failed to initialize payment sheet: $paymentSheetResult');
      }

      // Present the payment sheet to the user
      await Stripe.instance.presentPaymentSheet();

      // Payment succeeded
      return true;
    } on StripeException catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${e.error.localizedMessage}')),
      );

      return false;
    } catch (e) {
      // Close loading dialog if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );

      return false;
    }
  }
}