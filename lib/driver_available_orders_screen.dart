import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hangry_app_flutter/location_service.dart';
import 'package:intl/intl.dart';
import 'driver_available_orders_screen.dart';
import 'driver_order_details_screen.dart';

class DriverAvailableOrdersScreen extends StatefulWidget {
  const DriverAvailableOrdersScreen({Key? key}) : super(key: key);

  @override
  _DriverAvailableOrdersScreenState createState() => _DriverAvailableOrdersScreenState();
}

class _DriverAvailableOrdersScreenState extends State<DriverAvailableOrdersScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final User? _user = FirebaseAuth.instance.currentUser;
  final LocationService _locationService = LocationService();

  List<Map<String, dynamic>> _availableOrders = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchAvailableOrders();
  }

  Future<void> _fetchAvailableOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Query all users with accountType = restaurant
      final restaurantsSnapshot = await _databaseRef
          .child('users')
          .orderByChild('accountType')
          .equalTo('restaurant')
          .get();

      if (!restaurantsSnapshot.exists) {
        setState(() {
          _availableOrders = [];
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> availableOrders = [];
      final Map<dynamic, dynamic> restaurants = restaurantsSnapshot.value as Map<dynamic, dynamic>;

      // For each restaurant, check their orders
      await Future.forEach(restaurants.entries, (MapEntry restaurant) async {
        final restaurantId = restaurant.key;
        final restaurantName = (restaurant.value as Map<dynamic, dynamic>)['name'] ?? 'Unknown Restaurant';

        // Get restaurant profile for address
        Map<String, dynamic> restaurantProfile = {};
        final restaurantProfileSnapshot = await _databaseRef
            .child('users/$restaurantId/profile')
            .get();

        if (restaurantProfileSnapshot.exists) {
          restaurantProfile = Map<String, dynamic>.from(
              restaurantProfileSnapshot.value as Map<dynamic, dynamic>);
        }

        // Get orders for this restaurant
        final ordersSnapshot = await _databaseRef
            .child('users/$restaurantId/orders')
            .get();

        if (ordersSnapshot.exists) {
          final Map<dynamic, dynamic> orders = ordersSnapshot.value as Map<dynamic, dynamic>;

          orders.forEach((orderId, orderData) {
            if (orderData is Map &&
                orderData['status'] == 'ready_for_pickup' &&
                !orderData.containsKey('assignedDriver')) {

              // Calculate approximate distance (can be enhanced with actual geolocation)
              double distance = 0.0;

              Map<String, dynamic> formattedOrder = {
                'orderId': orderId,
                'restaurantId': restaurantId,
                'restaurantName': restaurantName,
                'userId': orderData['userId'] ?? '',
                'orderDate': orderData['orderDate'] ?? '',
                'total': orderData['total'] ?? 0.0,
                'items': orderData['items'] ?? {},
                'distance': distance,
                'estimatedTime': '15-25 min', // Could be calculated based on distance
                'restaurantAddress': restaurantProfile['address'] ?? 'No address available',
              };

              if (orderData.containsKey('deliveryAddress')) {
                formattedOrder['deliveryAddress'] = Map<String, dynamic>.from(
                    orderData['deliveryAddress'] as Map<dynamic, dynamic>);
              }

              availableOrders.add(formattedOrder);
            }
          });
        }
      });

      // Sort by closest distance (placeholder for now)
      availableOrders.sort((a, b) => a['distance'].compareTo(b['distance']));

      setState(() {
        _availableOrders = availableOrders;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
      print('Error fetching available orders: $error');
    }
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    if (_user == null) {
      _showErrorSnackBar('You must be logged in to accept orders');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final String orderId = order['orderId'];
      final String restaurantId = order['restaurantId'];
      final String userId = order['userId'];

      // Update order in restaurant's database
      await _databaseRef.child('users/$restaurantId/orders/$orderId').update({
        'status': 'on_the_way',
        'assignedDriver': _user!.uid,
        'assignedAt': ServerValue.timestamp,
      });

      // Update order in user's database
      await _databaseRef.child('users/$userId/profile/orders/$orderId').update({
        'status': 'on_the_way',
        'assignedDriver': _user!.uid,
        'assignedAt': ServerValue.timestamp,
      });

      // Add to driver's assignments
      await _databaseRef.child('users/${_user!.uid}/assignments/$orderId').set({
        'orderId': orderId,
        'restaurantId': restaurantId,
        'userId': userId,
        'status': 'accepted',
        'acceptedAt': ServerValue.timestamp,
      });

      // Start location tracking
      await _locationService.startTracking(
        driverId: _user!.uid,
        orderId: orderId,
        userId: userId,
        restaurantId: restaurantId,
      );

      _showSuccessSnackBar('Order accepted! Starting delivery...');

      // Refresh the list
      _fetchAvailableOrders();

      // Navigate to order details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverOrderDetailsScreen(
            orderId: orderId,
            restaurantId: restaurantId,
            userId: userId,
          ),
        ),
      ).then((_) => _fetchAvailableOrders());

    } catch (error) {
      _showErrorSnackBar('Error accepting order: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _declineOrder(Map<String, dynamic> order) async {
    // Not actually declining in database, just removing from local view
    setState(() {
      _availableOrders.remove(order);
    });

    _showSuccessSnackBar('Order removed from your available list');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Available Orders',
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
        backgroundColor: hangryYellow,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: hangryYellow))
          : _errorMessage.isNotEmpty
          ? _buildErrorWidget()
          : _availableOrders.isEmpty
          ? _buildEmptyStateWidget()
          : RefreshIndicator(
        onRefresh: _fetchAvailableOrders,
        color: hangryYellow,
        child: ListView.builder(
          itemCount: _availableOrders.length,
          padding: EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final order = _availableOrders[index];
            return _buildOrderCard(context, order);
          },
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Error loading orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(_errorMessage),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchAvailableOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: hangryYellow,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No available orders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Check back soon for new delivery requests',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchAvailableOrders,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hangryYellow,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Restaurant info section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: hangryYellow.withOpacity(0.2),
                  child: Icon(Icons.restaurant, color: hangryYellow),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['restaurantName'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        order['restaurantAddress'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order details section
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order['orderId'].toString().substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDate(order['orderDate']),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Divider(height: 20),

                // Delivery details
                if (order.containsKey('deliveryAddress'))
                  _buildAddressSection('Delivery address', order['deliveryAddress']),

                SizedBox(height: 12),

                // Payment & Time info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.payments, size: 16, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              '\$${(order['total'] as num).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Distance',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: hangryBlue),
                            SizedBox(width: 4),
                            Text(
                              order['estimatedTime'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _declineOrder(order),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Decline'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptOrder(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hangryYellow,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(String title, Map<dynamic, dynamic> addressData) {
    final address = addressData['address'] ?? '';
    final city = addressData['city'] ?? '';
    final zipCode = addressData['zipCode'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: hangryYellow),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                '$address, $city, $zipCode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}