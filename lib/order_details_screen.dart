import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'track_order_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String restaurantName;
  final String restaurantId;

  const OrderDetailsScreen({
    Key? key,
    required this.orderId,
    required this.restaurantName,
    required this.restaurantId,
  }) : super(key: key);

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final User? _user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _orderDetails;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
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

      final orderSnapshot = await _databaseRef
          .child('users/${_user!.uid}/profile/orders/${widget.orderId}')
          .get();

      if (!orderSnapshot.exists) {
        setState(() {
          _errorMessage = 'Order not found';
          _isLoading = false;
        });
        return;
      }

      final orderData = orderSnapshot.value as Map<dynamic, dynamic>;
      Map<String, dynamic> orderDetails = {};

      // Extract order information
      orderDetails['orderId'] = widget.orderId;
      orderDetails['restaurantName'] =
          orderData['restaurantName'] ?? widget.restaurantName;
      orderDetails['restaurantId'] =
          orderData['restaurantId'] ?? widget.restaurantId;
      orderDetails['orderDate'] = orderData['orderDate'] ?? '';
      orderDetails['status'] = orderData['status'] ?? 'pending';
      orderDetails['total'] = orderData['total'] ?? 0.0;
      orderDetails['subtotal'] = orderData['subtotal'] ?? 0.0;
      orderDetails['tax'] = orderData['tax'] ?? 0.0;
      orderDetails['deliveryFee'] = orderData['deliveryFee'] ?? 0.0;
      orderDetails['paymentMethod'] = orderData['paymentMethod'] ?? 'Unknown';

      // Extract items
      if (orderData['items'] is Map) {
        Map<String, dynamic> formattedItems = {};
        (orderData['items'] as Map<dynamic, dynamic>).forEach((key, value) {
          if (value is Map) {
            formattedItems[key.toString()] =
                Map<String, dynamic>.from(value as Map);
          }
        });
        orderDetails['items'] = formattedItems;
      } else {
        orderDetails['items'] = {};
      }

      // Extract delivery address
      if (orderData['deliveryAddress'] is Map) {
        orderDetails['deliveryAddress'] =
            Map<String, dynamic>.from(orderData['deliveryAddress'] as Map);
      }

      // Extract tracking information if available
      if (orderData['tracking'] is Map) {
        orderDetails['tracking'] =
            Map<String, dynamic>.from(orderData['tracking'] as Map);
      }

      // Extract driver information if assigned
      if (orderData.containsKey('assignedDriver') &&
          orderData['assignedDriver'] != null) {
        orderDetails['assignedDriver'] = orderData['assignedDriver'];
        // Fetch driver information
        final driverSnapshot = await _databaseRef
            .child('users/${orderData['assignedDriver']}')
            .get();

        if (driverSnapshot.exists) {
          final driverData = driverSnapshot.value as Map<dynamic, dynamic>;
          orderDetails['driverName'] = driverData['name'] ?? 'Driver';

          if (driverData.containsKey('profile') &&
              driverData['profile'] is Map) {
            final profile = driverData['profile'] as Map<dynamic, dynamic>;
            orderDetails['driverPhone'] = profile['phoneNumber'];
            orderDetails['driverVehicle'] = profile['carModel'];
            orderDetails['driverPlate'] = profile['plateNumber'];
          }
        }
      }

      setState(() {
        _orderDetails = orderDetails;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
      print('Error fetching order details: $error');
    }
  }

  String _formatDate(String dateString) {
    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('MMMM d, yyyy - h:mm a').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  void _navigateToTracking() {
    if (_user == null || _orderDetails == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackOrderScreen(
          orderId: widget.orderId,
          userId: _user!.uid,
          restaurantId: _orderDetails!['restaurantId'],
          restaurantName: _orderDetails!['restaurantName'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order Details',
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
                        'Error loading order details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(_errorMessage),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _fetchOrderDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hangryYellow,
                        ),
                        child: Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _orderDetails == null
                  ? Center(child: Text('No order details available'))
                  : _buildOrderDetailsContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget? _buildBottomBar() {
    if (_orderDetails == null) return null;

    final status = _orderDetails!['status'] as String;

    // Only show tracking button if order is being prepared or on the way
    if (status == 'preparing' ||
        status == 'ready_for_pickup' ||
        status == 'on_the_way') {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: Icon(Icons.location_on),
          label: Text('Track Your Order'),
          style: ElevatedButton.styleFrom(
            backgroundColor: hangryBlue,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12),
            minimumSize: Size(double.infinity, 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _navigateToTracking,
        ),
      );
    }

    // Show reorder button for completed orders
    if (status == 'delivered') {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          icon: Icon(Icons.refresh),
          label: Text('Reorder'),
          style: ElevatedButton.styleFrom(
            backgroundColor: hangryYellow,
            foregroundColor: Colors.black,
            padding: EdgeInsets.symmetric(vertical: 12),
            minimumSize: Size(double.infinity, 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            // Implement reorder functionality
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Reorder feature coming soon!')),
            );
          },
        ),
      );
    }

    return null;
  }

  Widget _buildOrderDetailsContent() {
    return RefreshIndicator(
      onRefresh: _fetchOrderDetails,
      color: hangryYellow,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status Header
            _buildStatusHeader(),

            SizedBox(height: 24),

            // Order Info
            _buildSection(
              'Order Information',
              [
                _buildInfoRow(
                    'Order ID', '#${widget.orderId.substring(0, 8)}...'),
                _buildInfoRow('Date', _formatDate(_orderDetails!['orderDate'])),
                _buildInfoRow('Restaurant', _orderDetails!['restaurantName']),
                _buildInfoRow(
                    'Payment Method', _orderDetails!['paymentMethod']),
              ],
            ),

            SizedBox(height: 16),

            // Items list
            _buildOrderItemsList(),

            SizedBox(height: 16),

            // Order summary
            _buildOrderSummary(),

            SizedBox(height: 16),

            // Delivery address
            if (_orderDetails!.containsKey('deliveryAddress'))
              _buildDeliveryAddressSection(),

            SizedBox(height: 16),

            // Driver info (if assigned)
            if (_orderDetails!.containsKey('assignedDriver') &&
                _orderDetails!.containsKey('driverName'))
              _buildDriverInfoSection(),

            // Add padding at the bottom for the bottom bar
            SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final status = _orderDetails!['status'];

    // Define UI elements for each status
    IconData statusIcon;
    Color statusColor;
    String statusText;
    String statusDescription;

    switch (status) {
      case 'pending':
        statusIcon = Icons.receipt;
        statusColor = Colors.grey;
        statusText = 'Order Pending';
        statusDescription =
            'Your order has been received and is waiting for confirmation.';
        break;
      case 'preparing':
        statusIcon = Icons.restaurant;
        statusColor = Colors.orange;
        statusText = 'Preparing Your Order';
        statusDescription = 'The restaurant is preparing your delicious food.';
        break;
      case 'ready_for_pickup':
        statusIcon = Icons.check_circle;
        statusColor = Colors.blue;
        statusText = 'Ready for Pickup';
        statusDescription = 'Your order is prepared and waiting for a driver.';
        break;
      case 'on_the_way':
        statusIcon = Icons.delivery_dining;
        statusColor = Colors.purple;
        statusText = 'On the Way';
        statusDescription = 'Your food is on the way to your location!';
        break;
      case 'delivered':
        statusIcon = Icons.done_all;
        statusColor = Colors.green;
        statusText = 'Delivered';
        statusDescription = 'Your order has been delivered. Enjoy your meal!';
        break;
      case 'cancelled':
        statusIcon = Icons.cancel;
        statusColor = Colors.red;
        statusText = 'Cancelled';
        statusDescription = 'This order has been cancelled.';
        break;
      default:
        statusIcon = Icons.help;
        statusColor = Colors.grey;
        statusText = 'Unknown Status';
        statusDescription = 'The current status of your order is unknown.';
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            size: 40,
            color: statusColor,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  statusDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: hangryBlue,
          ),
        ),
        SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsList() {
    if (!_orderDetails!.containsKey('items') ||
        (_orderDetails!['items'] as Map).isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(child: Text('No items in this order')),
        ),
      );
    }

    final items = _orderDetails!['items'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: hangryBlue,
          ),
        ),
        SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ...items.entries.map((entry) {
                  final item = entry.value;
                  final itemName = item['name'] ?? 'Unknown Item';
                  final quantity = item['quantity'] ?? 1;
                  final price = item['price'] ?? 0.0;
                  final subtotal = item['subtotal'] ?? (price * quantity);
                  final comment = item['comment'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$quantity x $itemName',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${subtotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (comment.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Note: $comment',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        if (entry.key != items.keys.last) Divider(height: 16),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = _orderDetails!['subtotal'] as double;
    final tax = _orderDetails!['tax'] as double;
    final deliveryFee = _orderDetails!['deliveryFee'] as double;
    final total = _orderDetails!['total'] as double;

    return Column(
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
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSummaryRow(
                    'Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
                SizedBox(height: 8),
                _buildSummaryRow('Tax', '\$${tax.toStringAsFixed(2)}'),
                SizedBox(height: 8),
                _buildSummaryRow(
                    'Delivery Fee', '\$${deliveryFee.toStringAsFixed(2)}'),
                SizedBox(height: 8),
                Divider(),
                SizedBox(height: 8),
                _buildSummaryRow('Total', '\$${total.toStringAsFixed(2)}',
                    isTotal: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: isTotal ? hangryBlue : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryAddressSection() {
    final deliveryAddress =
        _orderDetails!['deliveryAddress'] as Map<String, dynamic>;
    final address = deliveryAddress['address'] ?? '';
    final city = deliveryAddress['city'] ?? '';
    final zipCode = deliveryAddress['zipCode'] ?? '';
    final phone = deliveryAddress['phone'] ?? '';

    final formattedAddress = '$address, $city, $zipCode';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Address',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: hangryBlue,
          ),
        ),
        SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: hangryYellow, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formattedAddress,
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (phone.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone, color: hangryYellow, size: 20),
                      SizedBox(width: 8),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverInfoSection() {
    final driverName = _orderDetails!['driverName'] ?? 'Driver';
    final driverPhone = _orderDetails!['driverPhone'] ?? '';
    final driverVehicle = _orderDetails!['driverVehicle'] ?? '';
    final driverPlate = _orderDetails!['driverPlate'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Driver',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: hangryBlue,
          ),
        ),
        SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: hangryYellow.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    color: hangryYellow,
                    size: 30,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (driverPhone.isNotEmpty)
                        Text(
                          'Phone: $driverPhone',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      if (driverVehicle.isNotEmpty && driverPlate.isNotEmpty)
                        Text(
                          '$driverVehicle • $driverPlate',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.phone, color: hangryBlue),
                  onPressed: () {
                    // Implement chat functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Chat driver feature coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
