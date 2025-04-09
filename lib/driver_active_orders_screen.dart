import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'driver_order_details_screen.dart';

class DriverActiveOrdersScreen extends StatefulWidget {
  const DriverActiveOrdersScreen({Key? key}) : super(key: key);

  @override
  _DriverActiveOrdersScreenState createState() =>
      _DriverActiveOrdersScreenState();
}

class _DriverActiveOrdersScreenState extends State<DriverActiveOrdersScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final User? _user = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchOrders();

    // Setup real-time listener for driver assignments
    if (_user != null) {
      _databaseRef
          .child('users/${_user!.uid}/assignments')
          .onValue
          .listen((event) {
        if (event.snapshot.exists) {
          _fetchOrders();
        }
      });
    }
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

      // Get driver's assignments
      final assignmentsSnapshot =
          await _databaseRef.child('users/${_user!.uid}/assignments').get();

      if (!assignmentsSnapshot.exists) {
        setState(() {
          _activeOrders = [];
          _completedOrders = [];
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> active = [];
      List<Map<String, dynamic>> completed = [];

      final Map<dynamic, dynamic> assignments =
          assignmentsSnapshot.value as Map<dynamic, dynamic>;

      await Future.forEach(assignments.entries, (MapEntry assignment) async {
        final String orderId = assignment.key;
        final Map<dynamic, dynamic> assignmentData =
            assignment.value as Map<dynamic, dynamic>;

        final String restaurantId = assignmentData['restaurantId'] ?? '';
        final String userId = assignmentData['userId'] ?? '';
        final String status = assignmentData['status'] ?? '';

        // Get order details from restaurant's records
        final orderSnapshot = await _databaseRef
            .child('users/$restaurantId/orders/$orderId')
            .get();

        if (orderSnapshot.exists) {
          final Map<dynamic, dynamic> orderData =
              orderSnapshot.value as Map<dynamic, dynamic>;

          // Get restaurant info
          final restaurantSnapshot =
              await _databaseRef.child('users/$restaurantId').get();

          String restaurantName = 'Unknown Restaurant';
          if (restaurantSnapshot.exists) {
            final restaurantData =
                restaurantSnapshot.value as Map<dynamic, dynamic>;
            restaurantName = restaurantData['name'] ?? 'Unknown Restaurant';
          }

          // Format order data
          Map<String, dynamic> orderInfo = {
            'orderId': orderId,
            'restaurantId': restaurantId,
            'restaurantName': restaurantName,
            'userId': userId,
            'status': orderData['status'] ?? 'unknown',
            'orderDate': orderData['orderDate'] ?? '',
            'total': orderData['total'] ?? 0.0,
          };

          // Add delivery address if available
          if (orderData.containsKey('deliveryAddress')) {
            orderInfo['deliveryAddress'] = Map<String, dynamic>.from(
                orderData['deliveryAddress'] as Map<dynamic, dynamic>);
          }

          // Sort into active or completed based on status
          if (status == 'completed' || orderData['status'] == 'delivered') {
            completed.add(orderInfo);
          } else {
            active.add(orderInfo);
          }
        }
      });

      // Sort by most recent first
      active.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['orderDate']);
          final dateB = DateTime.parse(b['orderDate']);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      completed.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['orderDate']);
          final dateB = DateTime.parse(b['orderDate']);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _activeOrders = active;
        _completedOrders = completed;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
      print('Error fetching driver orders: $error');
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'My Deliveries',
            style: TextStyle(
              fontFamily: 'RammettoOne-Regular',
              color: Colors.black,
            ),
          ),
          backgroundColor: hangryYellow,
          bottom: TabBar(
            indicatorColor: hangryBlue,
            labelColor: hangryBlue,
            unselectedLabelColor: Colors.black54,
            tabs: [
              Tab(text: 'Active (${_activeOrders.length})'),
              Tab(text: 'Completed (${_completedOrders.length})'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: hangryYellow))
            : _errorMessage.isNotEmpty
                ? _buildErrorWidget()
                : TabBarView(
                    children: [
                      // Active orders tab
                      _activeOrders.isEmpty
                          ? _buildEmptyState('No active deliveries',
                              'You don\'t have any active deliveries at the moment.')
                          : _buildOrdersList(_activeOrders),

                      // Completed orders tab
                      _completedOrders.isEmpty
                          ? _buildEmptyState('No completed deliveries',
                              'Your delivery history will appear here.')
                          : _buildOrdersList(_completedOrders,
                              isCompleted: true),
                    ],
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
            onPressed: _fetchOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: hangryYellow,
            ),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchOrders,
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

  Widget _buildOrdersList(List<Map<String, dynamic>> orders,
      {bool isCompleted = false}) {
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: hangryYellow,
      child: ListView.builder(
        itemCount: orders.length,
        padding: EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(context, order, isCompleted);
        },
      ),
    );
  }

  Widget _buildOrderCard(
      BuildContext context, Map<String, dynamic> order, bool isCompleted) {
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
              builder: (context) => DriverOrderDetailsScreen(
                orderId: order['orderId'],
                restaurantId: order['restaurantId'],
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
              // Header with order ID and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order['orderId'].toString().substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: hangryBlue,
                    ),
                  ),
                  _buildStatusBadge(order['status']),
                ],
              ),
              SizedBox(height: 12),

              // Restaurant info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.restaurant, color: hangryYellow, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order['restaurantName'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Delivery address
              if (order.containsKey('deliveryAddress')) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: hangryYellow, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${order['deliveryAddress']['address']}, ${order['deliveryAddress']['city']}',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],

              // Date and total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(order['orderDate']),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '\$${(order['total'] as num).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hangryBlue,
                    ),
                  ),
                ],
              ),

              if (!isCompleted) ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverOrderDetailsScreen(
                                orderId: order['orderId'],
                                restaurantId: order['restaurantId'],
                                userId: order['userId'],
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.delivery_dining),
                        label: Text('Continue Delivery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hangryYellow,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'pending':
        color = Colors.grey;
        text = 'Pending';
        break;
      case 'preparing':
        color = Colors.orange;
        text = 'Preparing';
        break;
      case 'ready_for_pickup':
        color = Colors.blue;
        text = 'Ready';
        break;
      case 'on_the_way':
        color = Colors.purple;
        text = 'On the Way';
        break;
      case 'delivered':
        color = Colors.green;
        text = 'Delivered';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
