import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hangry_app_flutter/restaurant_orders_details_screen.dart';
import 'package:intl/intl.dart';

class RestaurantOrdersScreen extends StatefulWidget {
  const RestaurantOrdersScreen({Key? key}) : super(key: key);

  @override
  _RestaurantOrdersScreenState createState() => _RestaurantOrdersScreenState();
}

class _RestaurantOrdersScreenState extends State<RestaurantOrdersScreen>
    with SingleTickerProviderStateMixin {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  late TabController _tabController;
  final User? _user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> _pendingOrders = [];
  List<Map<String, dynamic>> _preparingOrders = [];
  List<Map<String, dynamic>> _readyOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchOrders();

    // Listen for order updates
    _setupOrderListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setupOrderListener() {
    if (_user == null) return;

    _databaseRef.child('users/${_user!.uid}/orders').onValue.listen((event) {
      if (event.snapshot.exists) {
        _fetchOrders();
      }
    });
  }

  Future<void> _fetchOrders() async {
    if (_user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final ordersSnapshot =
          await _databaseRef.child('users/${_user!.uid}/orders').get();

      if (!ordersSnapshot.exists) {
        setState(() {
          _pendingOrders = [];
          _preparingOrders = [];
          _readyOrders = [];
          _completedOrders = [];
          _isLoading = false;
        });
        return;
      }

      final ordersData = ordersSnapshot.value as Map<dynamic, dynamic>;

      List<Map<String, dynamic>> pending = [];
      List<Map<String, dynamic>> preparing = [];
      List<Map<String, dynamic>> ready = [];
      List<Map<String, dynamic>> completed = [];

      ordersData.forEach((orderId, orderData) {
        if (orderData is Map) {
          final Map<String, dynamic> orderMap = {};
          orderMap['orderId'] = orderId;

          // Copy essential information
          orderMap['userId'] = orderData['userId'] ?? '';
          orderMap['orderDate'] = orderData['orderDate'] ?? '';
          orderMap['status'] = orderData['status'] ?? 'pending';
          orderMap['total'] = orderData['total'] ?? 0.0;
          orderMap['items'] = orderData['items'] ?? {};
          orderMap['deliveryAddress'] = orderData['deliveryAddress'] ?? {};
          orderMap['assignedDriver'] = orderData['assignedDriver'];

          // Parse the order date for sorting
          DateTime dateObject;
          try {
            dateObject = DateTime.parse(orderData['orderDate']);
          } catch (e) {
            dateObject = DateTime.now(); // Fallback
          }
          orderMap['dateObject'] = dateObject;

          // Add to appropriate list based on status
          switch (orderMap['status']) {
            case 'pending':
              pending.add(orderMap);
              break;
            case 'preparing':
              preparing.add(orderMap);
              break;
            case 'ready_for_pickup':
              ready.add(orderMap);
              break;
            case 'on_the_way':
            case 'delivered':
              completed.add(orderMap);
              break;
          }
        }
      });

      // Sort orders by date (newest first)
      pending.sort((a, b) =>
          (b['dateObject'] as DateTime).compareTo(a['dateObject'] as DateTime));
      preparing.sort((a, b) =>
          (b['dateObject'] as DateTime).compareTo(a['dateObject'] as DateTime));
      ready.sort((a, b) =>
          (b['dateObject'] as DateTime).compareTo(a['dateObject'] as DateTime));
      completed.sort((a, b) =>
          (b['dateObject'] as DateTime).compareTo(a['dateObject'] as DateTime));

      setState(() {
        _pendingOrders = pending;
        _preparingOrders = preparing;
        _readyOrders = ready;
        _completedOrders = completed;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
      print('Error fetching orders: $error');
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

  Future<void> _updateOrderStatus(
      String orderId, String userId, String status) async {
    try {
      // Update in restaurant's record
      await _databaseRef.child('users/${_user!.uid}/orders/$orderId').update({
        'status': status,
        'statusUpdatedAt': ServerValue.timestamp,
      });

      // Update in user's record
      await _databaseRef.child('users/$userId/profile/orders/$orderId').update({
        'status': status,
        'statusUpdatedAt': ServerValue.timestamp,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to $status')),
      );

      // Refresh orders
      _fetchOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Orders Management',
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
        backgroundColor: hangryYellow,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: hangryBlue,
          labelColor: hangryBlue,
          unselectedLabelColor: Colors.black54,
          tabs: [
            Tab(
              text: 'New (${_pendingOrders.length})',
              icon: Icon(Icons.receipt),
            ),
            Tab(
              text: 'Preparing (${_preparingOrders.length})',
              icon: Icon(Icons.restaurant),
            ),
            Tab(
              text: 'Ready (${_readyOrders.length})',
              icon: Icon(Icons.delivery_dining),
            ),
            Tab(
              text: 'Completed (${_completedOrders.length})',
              icon: Icon(Icons.check_circle),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: hangryYellow))
          : _errorMessage.isNotEmpty
              ? Center(
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
                        onPressed: _fetchOrders,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hangryYellow,
                        ),
                        child: Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // New Orders Tab
                    _buildOrdersList(
                      _pendingOrders,
                      actions: (order) => [
                        _buildActionButton(
                            'Accept',
                            Colors.green,
                            () => _updateOrderStatus(order['orderId'],
                                order['userId'], 'preparing')),
                        _buildActionButton(
                            'Decline',
                            Colors.red,
                            () => _updateOrderStatus(order['orderId'],
                                order['userId'], 'cancelled')),
                      ],
                    ),

                    // Preparing Orders Tab
                    _buildOrdersList(
                      _preparingOrders,
                      actions: (order) => [
                        _buildActionButton(
                            'Ready for Pickup',
                            Colors.blue,
                            () => _updateOrderStatus(order['orderId'],
                                order['userId'], 'ready_for_pickup')),
                      ],
                    ),

                    // Ready Orders Tab
                    _buildOrdersList(
                      _readyOrders,
                      showDriverInfo: true,
                    ),

                    // Completed Orders Tab
                    _buildOrdersList(
                      _completedOrders,
                      showDriverInfo: true,
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchOrders,
        backgroundColor: hangryYellow,
        child: Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildOrdersList(
    List<Map<String, dynamic>> orders, {
    List<Widget> Function(Map<String, dynamic>)? actions,
    bool showDriverInfo = false,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No orders in this category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: hangryYellow,
      child: ListView.builder(
        itemCount: orders.length,
        padding: EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(
            context,
            order,
            actions: actions != null ? actions(order) : null,
            showDriverInfo: showDriverInfo,
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    Map<String, dynamic> order, {
    List<Widget>? actions,
    bool showDriverInfo = false,
  }) {
    // Calculate items count
    int itemCount = 0;
    if (order['items'] is Map) {
      itemCount = (order['items'] as Map).length;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantOrderDetailsScreen(
                orderId: order['orderId'],
                userId: order['userId'],
              ),
            ),
          ).then((_) => _fetchOrders());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order['orderId'].toString().substring(0, Math.min(8, order['orderId'].toString().length))}...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hangryBlue,
                    ),
                  ),
                  _buildStatusBadge(order['status']),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _formatDate(order['orderDate']),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '\$${(order['total'] as num).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hangryYellow,
                    ),
                  ),
                ],
              ),

              // Delivery Address
              if (order.containsKey('deliveryAddress') &&
                  order['deliveryAddress'] is Map &&
                  order['deliveryAddress'].isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    _buildDeliveryAddressRow(order['deliveryAddress']),

                    // Driver info if assigned and requested
                    if (showDriverInfo &&
                        order.containsKey('assignedDriver') &&
                        order['assignedDriver'] != null)
                      Column(
                        children: [
                          SizedBox(height: 8),
                          FutureBuilder(
                            future: _databaseRef
                                .child('users/${order['assignedDriver']}')
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Text('Loading driver info...');
                              }

                              if (snapshot.hasError ||
                                  !snapshot.hasData ||
                                  !snapshot.data!.exists) {
                                return Text('Driver info not available');
                              }

                              final driverData =
                                  snapshot.data!.value as Map<dynamic, dynamic>;
                              final driverName = driverData['name'] ?? 'Driver';

                              String driverPhone = '';
                              String vehicle = '';

                              if (driverData.containsKey('profile') &&
                                  driverData['profile'] is Map) {
                                final profile = driverData['profile']
                                    as Map<dynamic, dynamic>;
                                driverPhone = profile['phoneNumber'] ?? '';

                                final carModel = profile['carModel'] ?? '';
                                final carColor = profile['carColor'] ?? '';
                                final plateNumber =
                                    profile['plateNumber'] ?? '';

                                if (carModel.isNotEmpty &&
                                    plateNumber.isNotEmpty) {
                                  vehicle =
                                      '$carColor $carModel ($plateNumber)';
                                }
                              }

                              return Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.delivery_dining,
                                        color: hangryBlue),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Driver: $driverName',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          if (vehicle.isNotEmpty)
                                            Text(vehicle,
                                                style: TextStyle(fontSize: 12)),
                                          if (driverPhone.isNotEmpty)
                                            Text(driverPhone,
                                                style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),

              // Action buttons if provided
              if (actions != null && actions.isNotEmpty) ...[
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressRow(Map<dynamic, dynamic> deliveryAddress) {
    final address = deliveryAddress['address'] ?? '';
    final city = deliveryAddress['city'] ?? '';
    final zipCode = deliveryAddress['zipCode'] ?? '';
    final phone = deliveryAddress['phone'] ?? '';

    return Row(
      children: [
        Icon(Icons.location_on, color: hangryYellow, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$address, $city, $zipCode',
                style: TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (phone.isNotEmpty)
                Text('📞 $phone', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: TextStyle(fontSize: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String displayText;

    switch (status) {
      case 'pending':
        color = Colors.grey;
        displayText = 'New';
        break;
      case 'preparing':
        color = Colors.orange;
        displayText = 'Preparing';
        break;
      case 'ready_for_pickup':
        color = Colors.blue;
        displayText = 'Ready';
        break;
      case 'on_the_way':
        color = Colors.purple;
        displayText = 'Delivering';
        break;
      case 'delivered':
        color = Colors.green;
        displayText = 'Completed';
        break;
      case 'cancelled':
        color = Colors.red;
        displayText = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        displayText = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
