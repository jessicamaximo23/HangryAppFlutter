import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  final _formKey = GlobalKey<FormState>();

  // User information
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  // Payment method selection
  String _selectedPaymentMethod = 'Cash on Delivery';
  final List<String> _paymentMethods = [
    'Cash on Delivery',
    'Credit Card (Coming Soon)',
  ];

  bool _isLoading = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DatabaseReference ref = FirebaseDatabase.instance.ref('users/${currentUser.uid}');
        DatabaseEvent event = await ref.once();

        if (event.snapshot.exists) {
          Map<dynamic, dynamic> userData = event.snapshot.value as Map<dynamic, dynamic>;

          if (userData.containsKey('profile') && userData['profile'] is Map) {
            Map<dynamic, dynamic> profile = userData['profile'] as Map<dynamic, dynamic>;

            setState(() {
              _userProfile = Map<String, dynamic>.from(profile);

              // Pre-fill form with user data if available
              _addressController.text = _userProfile?['address'] ?? '';
              _cityController.text = _userProfile?['city'] ?? '';
              _zipCodeController.text = _userProfile?['zipCode'] ?? '';
              _phoneController.text = _userProfile?['phoneNumber'] ?? '';
            });
          }
        }
      }
    } catch (error) {
      print('Error loading user profile: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPaymentMethod == 'Credit Card (Coming Soon)') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credit card payments will be available soon!')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      // Generate a unique order ID
      String orderId = _generateOrderId();

      // Format current date
      String orderDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      // Convert cart items to a format suitable for the database
      Map<String, dynamic> orderItems = {};
      widget.cartItems.forEach((itemId, cartItem) {
        orderItems[itemId] = {
          'name': cartItem.name,
          'price': cartItem.price,
          'quantity': cartItem.quantity,
          'subtotal': cartItem.price * cartItem.quantity,
        };
      });

      // Create the order data
      Map<String, dynamic> orderData = {
        'userId': currentUser.uid,
        'restaurantId': widget.restaurantData['uid'],
        'restaurantName': widget.restaurantData['name'],
        'orderDate': orderDate,
        'items': orderItems,
        'subtotal': widget.subtotal,
        'tax': widget.taxAmount,
        'deliveryFee': widget.deliveryFee,
        'total': widget.total,
        'status': 'pending',
        'paymentMethod': _selectedPaymentMethod,
        'paymentStatus': 'pending',
        'deliveryAddress': {
          'address': _addressController.text,
          'city': _cityController.text,
          'zipCode': _zipCodeController.text,
          'phone': _phoneController.text,
        },
        'notes': _notesController.text,
      };

      // Save to user's orders in the database
      await FirebaseDatabase.instance
          .ref('users/${currentUser.uid}/orders/$orderId')
          .set(orderData);

      // Also save to restaurant's orders
      await FirebaseDatabase.instance
          .ref('users/${widget.restaurantData['uid']}/orders/$orderId')
          .set(orderData);

      // Save to global orders collection for admin
      await FirebaseDatabase.instance
          .ref('orders/$orderId')
          .set(orderData);

      // Navigate to order confirmation screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => OrderConfirmationScreen(
            orderId: orderId,
            orderTotal: widget.total,
            restaurantName: widget.restaurantData['name'],
          ),
        ),
            (route) => false,
      );

    } catch (error) {
      _showErrorSnackBar('Failed to place order: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _generateOrderId() {
    // Generate a random 8-character alphanumeric order ID
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

    String prefix = DateFormat('yyyyMMdd').format(DateTime.now());
    String randomPart = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();

    return '${prefix}_$randomPart';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
        backgroundColor: hangryYellow,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: hangryYellow))
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Delivery Address'),
              _buildTextFormField(
                controller: _addressController,
                labelText: 'Street Address',
                hintText: 'Enter your street address',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your street address';
                  }
                  return null;
                },
                icon: Icons.home,
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextFormField(
                      controller: _cityController,
                      labelText: 'City',
                      hintText: 'Enter your city',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your city';
                        }
                        return null;
                      },
                      icon: Icons.location_city,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildTextFormField(
                      controller: _zipCodeController,
                      labelText: 'Zip Code',
                      hintText: 'Enter zip code',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter zip code';
                        }
                        if (!RegExp(r'^\d{5}(?:[-\s]\d{4})?$').hasMatch(value)) {
                          return 'Invalid zip code';
                        }
                        return null;
                      },
                      icon: Icons.pin_drop,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildTextFormField(
                controller: _phoneController,
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (!RegExp(r'^\(\d{3}\) \d{3}-\d{4}$|^\d{10}$|^\d{3}-\d{3}-\d{4}$').hasMatch(value)) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12),
              _buildTextFormField(
                controller: _notesController,
                labelText: 'Delivery Notes (Optional)',
                hintText: 'Any special instructions for delivery?',
                validator: null,
                icon: Icons.note,
                maxLines: 3,
              ),
              SizedBox(height: 24),

              _buildSectionTitle('Payment Method'),
              _buildPaymentMethodSelection(),
              SizedBox(height: 24),

              _buildSectionTitle('Order Summary'),
              SizedBox(height: 12),

              _buildOrderSummaryItem('Items (${widget.cartItems.length})', '\$${widget.subtotal.toStringAsFixed(2)}'),
              _buildOrderSummaryItem('Tax', '\$${widget.taxAmount.toStringAsFixed(2)}'),
              _buildOrderSummaryItem('Delivery Fee', '\$${widget.deliveryFee.toStringAsFixed(2)}'),
              Divider(height: 24),
              _buildOrderSummaryItem(
                'Total',
                '\$${widget.total.toStringAsFixed(2)}',
                isBold: true,
              ),
              SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hangryYellow,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'Place Order',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: hangryBlue,
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: hangryBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: hangryBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: hangryYellow, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Column(
      children: _paymentMethods.map((method) {
        return RadioListTile<String>(
          title: Text(method),
          value: method,
          groupValue: _selectedPaymentMethod,
          activeColor: hangryYellow,
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value!;
            });
          },
          contentPadding: EdgeInsets.symmetric(horizontal: 0),
        );
      }).toList(),
    );
  }

  Widget _buildOrderSummaryItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? hangryBlue : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? hangryBlue : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}