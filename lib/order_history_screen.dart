import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final User? _user = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchOrderHistory();
  }

  Future<void> _fetchOrderHistory() async {
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
          await _databaseRef.child('users/${_user!.uid}/profile/orders').get();

      if (!ordersSnapshot.exists) {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
        return;
      }

      final ordersData = ordersSnapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> fetchedOrders = [];

      ordersData.forEach((orderId, orderData) {
        if (orderData is Map) {
          final Map<String, dynamic> orderMap = {};
          orderMap['orderId'] = orderId;

          // Copy essential information
          orderMap['restaurantName'] =
              orderData['restaurantName'] ?? 'Unknown Restaurant';
          orderMap['restaurantId'] = orderData['restaurantId'] ?? '';
          orderMap['orderDate'] = orderData['orderDate'] ?? '';
          orderMap['status'] = orderData['status'] ?? 'pending';
          orderMap['total'] = orderData['total'] ?? 0.0;
          orderMap['items'] = orderData['items'] ?? {};

          // Parse the order date for sorting
          try {
            orderMap['dateObject'] = DateTime.parse(orderData['orderDate']);
          } catch (e) {
            orderMap['dateObject'] = DateTime.now(); // Fallback
          }

          fetchedOrders.add(orderMap);
        }
      });

      // Sort orders by date (newest first)
      fetchedOrders.sort((a, b) {
        DateTime dateA = a['dateObject'] as DateTime;
        DateTime dateB = b['dateObject'] as DateTime;
        return dateB.compareTo(dateA);
      });

      setState(() {
        _orders = fetchedOrders;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
      print('Error fetching order history: $error');
    }
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order History',
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
                        onPressed: _fetchOrderHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hangryYellow,
                        ),
                        child: Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No Order History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You haven\'t placed any orders yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchOrderHistory,
                      color: hangryYellow,
                      child: ListView.builder(
                        itemCount: _orders.length,
                        padding: EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          return _buildOrderCard(context, order);
                        },
                      ),
                    ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    // Extract order details
    final orderId = order['orderId'] as String;
    final restaurantName = order['restaurantName'] as String;
    final orderDate = _formatDate(order['orderDate'] as String);
    final status = order['status'] as String;
    final total = order['total'] as double;
    final restaurantId = order['restaurantId'] as String;

    // Get item count
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
              builder: (context) => OrderDetailsScreen(
                orderId: orderId,
                restaurantName: restaurantName,
                restaurantId: restaurantId,
              ),
            ),
          );
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
                  Expanded(
                    child: Text(
                      restaurantName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hangryBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Order #${orderId.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                orderDate,
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
                    '\$${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hangryYellow,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.receipt, size: 16),
                    label: Text('View Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: hangryBlue,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderDetailsScreen(
                            orderId: orderId,
                            restaurantName: restaurantName,
                            restaurantId: restaurantId,
                          ),
                        ),
                      );
                    },
                  ),
                  if (status == 'on_the_way')
                    TextButton.icon(
                      icon: Icon(Icons.location_on, size: 16),
                      label: Text('Track Order'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                      onPressed: () {
                        // Navigate to track order screen
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String displayText;

    switch (status) {
      case 'pending':
        color = Colors.grey;
        displayText = 'Pending';
        break;
      case 'preparing':
        color = Colors.orange;
        displayText = 'Preparing';
        break;
      case 'ready_for_pickup':
        color = Colors.blue;
        displayText = 'Ready for Pickup';
        break;
      case 'on_the_way':
        color = Colors.purple;
        displayText = 'On the Way';
        break;
      case 'delivered':
        color = Colors.green;
        displayText = 'Delivered';
        break;
      case 'cancelled':
        color = Colors.red;
        displayText = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        displayText = 'Unknown';
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
