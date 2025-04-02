import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'checkout_screen.dart';
import 'restaurant_menu_screen.dart'; // For CartItem class

class CartScreen extends StatefulWidget {
  final Map<String, CartItem> cartItems;
  final Map<String, dynamic> restaurantData;
  final Function(Map<String, CartItem>) onCartUpdate;

  const CartScreen({
    Key? key,
    required this.cartItems,
    required this.restaurantData,
    required this.onCartUpdate,
  }) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  Map<String, CartItem> _currentCartItems = {};
  double _subtotal = 0.0;
  double _taxAmount = 0.0;
  double _deliveryFee = 3.99;
  double _total = 0.0;
  final double _taxRate = 0.15; // 15% tax rate

  @override
  void initState() {
    super.initState();
    // Create a copy of the cart items
    _currentCartItems = Map.from(widget.cartItems);
    _calculateTotals();
  }

  void _calculateTotals() {
    _subtotal = 0.0;

    _currentCartItems.forEach((key, item) {
      _subtotal += item.price * item.quantity;
    });

    _taxAmount = _subtotal * _taxRate;
    _total = _subtotal + _taxAmount + _deliveryFee;
  }

  void _updateItemQuantity(String itemId, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        _currentCartItems.remove(itemId);
      } else {
        _currentCartItems[itemId]!.quantity = newQuantity;
      }
      _calculateTotals();
    });

    // Notify parent widget about the updated cart
    widget.onCartUpdate(_currentCartItems);
  }

  void _clearCart() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear Cart'),
          content:
              Text('Are you sure you want to remove all items from your cart?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentCartItems.clear();
                  _calculateTotals();
                });
                widget.onCartUpdate(_currentCartItems);
                Navigator.of(context).pop();
              },
              child: Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _proceedToCheckout() {
    if (_currentCartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartItems: _currentCartItems,
          restaurantData: widget.restaurantData,
          subtotal: _subtotal,
          taxAmount: _taxAmount,
          deliveryFee: _deliveryFee,
          total: _total,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Cart',
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
        backgroundColor: hangryYellow,
        actions: [
          if (_currentCartItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: _clearCart,
              tooltip: 'Clear cart',
            ),
        ],
      ),
      body: _currentCartItems.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                _buildRestaurantInfo(),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _currentCartItems.length,
                    itemBuilder: (context, index) {
                      String itemId = _currentCartItems.keys.elementAt(index);
                      CartItem item = _currentCartItems[itemId]!;
                      return _buildCartItem(itemId, item);
                    },
                  ),
                ),
                _buildOrderSummary(),
              ],
            ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add some items to your cart',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hangryYellow,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: Icon(Icons.arrow_back),
            label: Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.restaurantData['profileImageUrl'] != null &&
                    widget.restaurantData['profileImageUrl'].isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.restaurantData['profileImageUrl'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: hangryYellow,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.restaurant,
                        color: hangryYellow,
                      ),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.restaurant,
                      color: hangryYellow,
                    ),
                  ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.restaurantData['name'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hangryBlue,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ordering from ${widget.restaurantData['address'] ?? 'this restaurant'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(String itemId, CartItem item) {
    return Dismissible(
      key: Key(itemId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        color: Colors.red,
        child: Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Remove Item'),
              content: Text(
                  'Are you sure you want to remove ${item.name} from your cart?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Remove', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _updateItemQuantity(itemId, 0);
      },
      child: Card(
        margin: EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey[300],
                          child: Center(
                            child: CircularProgressIndicator(
                              color: hangryYellow,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.fastfood,
                            color: hangryYellow,
                          ),
                        ),
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.fastfood,
                          color: hangryYellow,
                        ),
                      ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hangryBlue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Subtotal: \$${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onPressed: () =>
                            _updateItemQuantity(itemId, item.quantity - 1),
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        icon: Icons.add,
                        onPressed: () =>
                            _updateItemQuantity(itemId, item.quantity + 1),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: hangryYellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          size: 18,
          color: hangryBlue,
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: hangryBlue,
            ),
          ),
          SizedBox(height: 12),
          _buildSummaryRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
          _buildSummaryRow('Tax (15%)', '\$${_taxAmount.toStringAsFixed(2)}'),
          _buildSummaryRow(
              'Delivery Fee', '\$${_deliveryFee.toStringAsFixed(2)}'),
          Divider(height: 24),
          _buildSummaryRow(
            'Total',
            '\$${_total.toStringAsFixed(2)}',
            isTotal: true,
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proceedToCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: hangryYellow,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Proceed to Checkout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? hangryBlue : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? hangryBlue : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
