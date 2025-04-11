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

  // Cache for storing complete order data
  final Map<String, Map<String, dynamic>> _completeOrdersCache = {};

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

    // Listen to orders under the restaurant/orders path
    _databaseRef.child('users/${_user!.uid}/orders').onValue.listen((event) {
      if (event.snapshot.exists) {
        _fetchOrders();
      }
    });

    // Also listen to orders under the restaurant/profile/orders path for Android compatibility
    _databaseRef
        .child('users/${_user!.uid}/profile/orders')
        .onValue
        .listen((event) {
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

      Map<String, Map<String, dynamic>> allOrders = {};

      // Clear the cache when refreshing orders
      _completeOrdersCache.clear();

      // 1. Primary path: orders directly under restaurant user node
      final standardOrdersSnapshot =
          await _databaseRef.child('users/${_user!.uid}/orders').get();

      if (standardOrdersSnapshot.exists) {
        final ordersData =
            standardOrdersSnapshot.value as Map<dynamic, dynamic>;
        ordersData.forEach((orderId, orderData) {
          if (orderData is Map) {
            Map<String, dynamic> normalizedOrder =
                _normalizeOrderData(orderId.toString(), orderData);
            allOrders[orderId.toString()] = normalizedOrder;
          } else {
            // This could be just a status string, create minimal order object
            allOrders[orderId.toString()] = {
              'orderId': orderId.toString(),
              'status': orderData,
            };
          }
        });
      }

      // 2. CRITICAL: Also look in profile/orders for Android compatibility
      final profileOrdersSnapshot =
          await _databaseRef.child('users/${_user!.uid}/profile/orders').get();

      if (profileOrdersSnapshot.exists) {
        final ordersData = profileOrdersSnapshot.value as Map<dynamic, dynamic>;
        ordersData.forEach((orderId, orderData) {
          if (orderData is Map) {
            Map<String, dynamic> normalizedOrder =
                _normalizeOrderData(orderId.toString(), orderData);

            // If we already have this order, merge with any new information
            if (allOrders.containsKey(orderId.toString())) {
              // Update status from profile if it exists (likely more up-to-date)
              if (orderData['status'] != null) {
                allOrders[orderId.toString()]!['status'] = orderData['status'];
              }

              // If the profile version has items but our existing one doesn't, use the profile version
              if ((normalizedOrder['items'] is Map &&
                      (normalizedOrder['items'] as Map).isNotEmpty) &&
                  (!(allOrders[orderId.toString()]!['items'] is Map) ||
                      (allOrders[orderId.toString()]!['items'] as Map)
                          .isEmpty)) {
                allOrders[orderId.toString()]!['items'] =
                    normalizedOrder['items'];
              }
            } else {
              // Otherwise add as a new order
              allOrders[orderId.toString()] = normalizedOrder;
            }
          } else if (!allOrders.containsKey(orderId.toString())) {
            // This could be just a status string, create minimal order object
            allOrders[orderId.toString()] = {
              'orderId': orderId.toString(),
              'status': orderData,
            };
          }
        });
      }

      // 2. Look in global orders collection as well
      final globalOrdersSnapshot = await _databaseRef.child('orders').get();

      if (globalOrdersSnapshot.exists) {
        final globalOrders =
            globalOrdersSnapshot.value as Map<dynamic, dynamic>;
        globalOrders.forEach((orderId, orderData) {
          if (orderData is Map &&
              orderData['restaurantId'] == _user!.uid &&
              !allOrders.containsKey(orderId.toString())) {
            allOrders[orderId.toString()] =
                _normalizeOrderData(orderId.toString(), orderData);
          }
        });
      }

      // Now process all found orders
      List<Map<String, dynamic>> pending = [];
      List<Map<String, dynamic>> preparing = [];
      List<Map<String, dynamic>> ready = [];
      List<Map<String, dynamic>> completed = [];

      allOrders.forEach((orderId, orderData) {
        // Sort into appropriate category based on status
        String status = orderData['status']?.toString() ?? '';

        // Handle iOS/Android status values which might be different
        status = status.toLowerCase();
        if (status == "processing") status = "pending";

        switch (status) {
          case 'pending':
            pending.add(orderData);
            break;
          case 'preparing':
            preparing.add(orderData);
            break;
          case 'ready_for_pickup':
            ready.add(orderData);
            break;
          case 'on_the_way':
          case 'delivered':
          case 'completed':
            completed.add(orderData);
            break;
        }
      });

      // Sort each list by date (newest first)
      final sortByDate = (Map<String, dynamic> a, Map<String, dynamic> b) {
        // Try to extract date in multiple formats
        DateTime? aDate = _parseOrderDate(a['orderDate']);
        DateTime? bDate = _parseOrderDate(b['orderDate']);

        return (bDate ?? DateTime.now()).compareTo(aDate ?? DateTime.now());
      };

      pending.sort(sortByDate);
      preparing.sort(sortByDate);
      ready.sort(sortByDate);
      completed.sort(sortByDate);

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

  // Helper method to normalize order data from different sources
  Map<String, dynamic> _normalizeOrderData(
      String orderId, Map<dynamic, dynamic> data) {
    // Create a standardized order map that will work with your UI
    Map<String, dynamic> standardOrder = {
      'orderId': orderId,
    };

    // Copy all fields as-is
    data.forEach((key, value) {
      standardOrder[key.toString()] = value;
    });

    // Ensure userId is never null
    standardOrder['userId'] = standardOrder['userId'] ?? 'unknown';

    // Handle iOS/Android specific formats

    // Convert restaurantId from array to string if needed
    if (standardOrder['restaurantId'] is List) {
      standardOrder['restaurantId'] =
          (standardOrder['restaurantId'] as List).isNotEmpty
              ? standardOrder['restaurantId'][0]
              : '';
    }

    // Convert restaurantName from array to string if needed
    if (standardOrder['restaurantName'] is List) {
      standardOrder['restaurantName'] =
          (standardOrder['restaurantName'] as List).isNotEmpty
              ? standardOrder['restaurantName'][0]
              : '';
    }

    // Handle items in different formats
    if (standardOrder['items'] is List) {
      // Convert iOS/Android list of items to Flutter map format
      Map<String, dynamic> itemsMap = {};
      List items = standardOrder['items'] as List;
      for (int i = 0; i < items.length; i++) {
        itemsMap['item$i'] = {
          'name': items[i],
          'price': 0.0, // You might need to extract this from elsewhere
          'quantity': 1, // Default
          'subtotal': 0.0,
          'comment': '',
        };
      }
      standardOrder['items'] = itemsMap;
    } else if (standardOrder['items'] == null) {
      // If items is null, set it to an empty map
      standardOrder['items'] = <String, dynamic>{};
    }

    // Ensure we have total set
    if (standardOrder['total'] == null) {
      standardOrder['total'] = standardOrder['totalPrice'] ?? 0.0;
    }

    return standardOrder;
  }

  // Helper to enrich simplified order data with complete details
  Map<String, dynamic> _enrichOrderData(
      Map<String, dynamic> order, String orderId) {
    // If the order already has items and total, it's complete
    if ((order.containsKey('items') &&
            order['items'] != null &&
            order['items'] is Map &&
            (order['items'] as Map).isNotEmpty) &&
        (order.containsKey('total') && order['total'] != null)) {
      return order;
    }

    // This is a simplified order, try to find complete data
    String userId = order['userId']?.toString() ?? '';

    // First check if we can get complete data from cache
    if (_completeOrdersCache.containsKey(orderId)) {
      // Start with cached data
      Map<String, dynamic> completeOrder =
          Map.from(_completeOrdersCache[orderId]!);
      // Update with the latest status from the simplified data
      if (order.containsKey('status')) {
        completeOrder['status'] = order['status'];
      }
      if (order.containsKey('statusUpdatedAt')) {
        completeOrder['statusUpdatedAt'] = order['statusUpdatedAt'];
      }
      return completeOrder;
    }

    // Otherwise, we'll need to fetch it asynchronously and update later
    _fetchCompleteOrderData(orderId, userId);

    // Return what we have for now
    return order;
  }

  // Asynchronously fetch complete order data and update the UI
  Future<void> _fetchCompleteOrderData(String orderId, String userId) async {
    try {
      // Look in several possible places for the complete order data
      List<String> potentialPaths = [
        'users/${_user!.uid}/orders/$orderId',
      ];

      // Only check user path if we have a valid userId
      if (userId.isNotEmpty && userId != 'unknown') {
        potentialPaths.add('users/$userId/profile/orders/$orderId');
      }

      // Add global path as last resort
      potentialPaths.add('orders/$orderId');

      for (String path in potentialPaths) {
        final snapshot = await _databaseRef.child(path).get();
        if (snapshot.exists && snapshot.value is Map) {
          Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

          // Normalize the data
          Map<String, dynamic> normalizedData =
              _normalizeOrderData(orderId, data);

          // Store in cache
          _completeOrdersCache[orderId] = normalizedData;

          // If we're still mounted, refresh the UI
          if (mounted) {
            setState(() {
              // Force a rebuild - the cached data will now be used
            });
          }

          return;
        }
      }
    } catch (e) {
      print('Error fetching complete order data: $e');
    }
  }

  // Helper to parse dates in different formats
  DateTime? _parseOrderDate(dynamic dateStr) {
    if (dateStr == null) return null;

    // Try various date formats
    try {
      // Format: "2025-04-10 15:30:45"
      return DateTime.parse(dateStr.toString());
    } catch (_) {
      try {
        // Format: "Apr 10, 2025 15:30"
        return DateFormat('MMM d, yyyy HH:mm').parse(dateStr.toString());
      } catch (_) {
        try {
          // Format: "2025-04-10, 3:30 PM"
          return DateFormat('yyyy-MM-dd, h:mm a').parse(dateStr.toString());
        } catch (_) {
          return null;
        }
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'No date available';

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
      // Create update data with timestamp
      Map<String, dynamic> updateData = {
        'status': status,
        'statusUpdatedAt': ServerValue.timestamp,
      };

      // Track which paths we updated successfully
      bool anyUpdateSuccessful = false;

      // Update in all potential locations to keep data in sync

      // 1. Update in restaurant's direct orders
      try {
        await _databaseRef
            .child('users/${_user!.uid}/orders/$orderId')
            .update(updateData);
        anyUpdateSuccessful = true;
      } catch (e) {
        print('Error updating restaurant orders: $e');
      }

      // 2. CRITICAL: Also update in restaurant's profile/orders for Android compatibility
      try {
        await _databaseRef
            .child('users/${_user!.uid}/profile/orders/$orderId')
            .update(updateData);
        anyUpdateSuccessful = true;
      } catch (e) {
        print('Error updating restaurant profile orders: $e');
      }

      // 2. Update in user's record if valid userId
      if (userId.isNotEmpty && userId != 'unknown') {
        try {
          await _databaseRef
              .child('users/$userId/profile/orders/$orderId')
              .update(updateData);
          anyUpdateSuccessful = true;
        } catch (e) {
          print('Error updating user order: $e');
        }
      }

      // 3. Update in global orders if it exists
      try {
        final globalOrderRef = _databaseRef.child('orders/$orderId');
        final snapshot = await globalOrderRef.get();
        if (snapshot.exists) {
          await globalOrderRef.update(updateData);
          anyUpdateSuccessful = true;
        }
      } catch (e) {
        print('Error updating global order: $e');
      }

      if (anyUpdateSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $status')),
        );

        // Also update the cache if we have this order
        if (_completeOrdersCache.containsKey(orderId)) {
          _completeOrdersCache[orderId]!['status'] = status;
          _completeOrdersCache[orderId]!['statusUpdatedAt'] =
              DateTime.now().millisecondsSinceEpoch;
        }

        // Refresh orders
        _fetchOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating order status. Please try again.')),
        );
      }
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
                            () => _updateOrderStatus(
                                order['orderId']?.toString() ?? '',
                                order['userId']?.toString() ?? '',
                                'preparing')),
                        _buildActionButton(
                            'Decline',
                            Colors.red,
                            () => _updateOrderStatus(
                                order['orderId']?.toString() ?? '',
                                order['userId']?.toString() ?? '',
                                'cancelled')),
                      ],
                    ),

                    // Preparing Orders Tab
                    _buildOrdersList(
                      _preparingOrders,
                      actions: (order) => [
                        _buildActionButton(
                            'Ready for Pickup',
                            Colors.blue,
                            () => _updateOrderStatus(
                                order['orderId']?.toString() ?? '',
                                order['userId']?.toString() ?? '',
                                'ready_for_pickup')),
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
    // Get order ID and enrich with complete data if needed
    final orderId = order['orderId']?.toString() ?? '';

    // Enrich with complete data if this is a simplified order
    Map<String, dynamic> enrichedOrder = _enrichOrderData(order, orderId);

    // Calculate items count
    int itemCount = 0;
    if (enrichedOrder['items'] is Map) {
      itemCount = (enrichedOrder['items'] as Map).length;
    } else if (enrichedOrder['items'] is List) {
      itemCount = (enrichedOrder['items'] as List).length;
    }

    // Safely get orderId and handle null or empty
    final String orderIdDisplay = orderId.isNotEmpty
        ? 'Order #${orderId.substring(0, Math.min(8, orderId.length))}...'
        : 'Order #unknown';

    // Get total amount - use a default if not available
    final String totalAmount =
        '\$${(enrichedOrder['total'] as num?)?.toStringAsFixed(2) ?? (enrichedOrder['totalPrice'] as num?)?.toStringAsFixed(2) ?? '0.00'}';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (orderId.isNotEmpty) {
            String userId = enrichedOrder['userId']?.toString() ?? '';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RestaurantOrderDetailsScreen(
                  orderId: orderId,
                  userId: userId,
                ),
              ),
            ).then((_) => _fetchOrders());
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Cannot view details: Order ID is missing')),
            );
          }
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
                    orderIdDisplay,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hangryBlue,
                    ),
                  ),
                  _buildStatusBadge(enrichedOrder['status']?.toString() ?? ''),
                ],
              ),
              SizedBox(height: 8),
              Text(
                _formatDate(enrichedOrder['orderDate']?.toString()),
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
                    totalAmount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hangryYellow,
                    ),
                  ),
                ],
              ),

              // Delivery Address
              if (enrichedOrder.containsKey('deliveryAddress') &&
                  enrichedOrder['deliveryAddress'] is Map &&
                  (enrichedOrder['deliveryAddress'] as Map).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    _buildDeliveryAddressRow(enrichedOrder['deliveryAddress']
                        as Map<dynamic, dynamic>),

                    // Driver info if assigned and requested
                    if (showDriverInfo &&
                        enrichedOrder.containsKey('assignedDriver') &&
                        enrichedOrder['assignedDriver'] != null)
                      Column(
                        children: [
                          SizedBox(height: 8),
                          FutureBuilder(
                            future: _databaseRef
                                .child(
                                    'users/${enrichedOrder['assignedDriver']}')
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
    final address = deliveryAddress['address']?.toString() ?? '';
    final city = deliveryAddress['city']?.toString() ?? '';
    final zipCode = deliveryAddress['zipCode']?.toString() ?? '';
    final phone = deliveryAddress['phone']?.toString() ?? '';

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

    switch (status.toLowerCase()) {
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
