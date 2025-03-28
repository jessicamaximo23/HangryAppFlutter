import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:math';
import 'order_confirmation_screen.dart';
import 'restaurant_menu_screen.dart'; // For CartItem class


class CheckoutScreen extends StatefulWidget {
  final Map<String, CartItem> cartItems;
  final Map<String, dynamic> restaurantData;
  final double subtotal;
  final double taxAmount;
  final double deliveryFee;
  final double total;

  const CheckoutScreen({
    Key? key,
    required this.cartItems,
    required this.restaurantData,
    required this.subtotal,
    required this.taxAmount,
    required this.deliveryFee,
    required this.total,
  }) : super(key: key);