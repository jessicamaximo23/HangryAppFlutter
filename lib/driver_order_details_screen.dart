import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hangry_app_flutter/location_service.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';
import 'chat_service.dart';

class DriverOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String restaurantId;
  final String userId;

  const DriverOrderDetailsScreen({
    Key? key,
    required this.orderId,
    required this.restaurantId,
    required this.userId,
  }) : super(key: key);

  @override
  _DriverOrderDetailsScreenState createState() =>
      _DriverOrderDetailsScreenState();
}

class _DriverOrderDetailsScreenState extends State<DriverOrderDetailsScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final User? _user = FirebaseAuth.instance.currentUser;
  final LocationService _locationService = LocationService();

  Map<String, dynamic>? _orderDetails;
  bool _isLoading = true;
  String _errorMessage = '';

  // Map controller and markers
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();

    // Setup listener for order updates
    _setupOrderListener();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _setupOrderListener() {
    _databaseRef
        .child('users/${widget.restaurantId}/orders/${widget.orderId}')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        _fetchOrderDetails();
      }
    });
  }

  Future<void> _fetchOrderDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Get order data from restaurant record
      final orderSnapshot = await _databaseRef
          .child('users/${widget.restaurantId}/orders/${widget.orderId}')
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

      // Basic order information
      orderDetails['orderId'] = widget.orderId;
      orderDetails['userId'] = widget.userId;
      orderDetails['restaurantId'] = widget.restaurantId;
      orderDetails['orderDate'] = orderData['orderDate'] ?? '';
      orderDetails['status'] = orderData['status'] ?? 'pending';
      orderDetails['total'] = orderData['total'] ?? 0.0;
      orderDetails['subtotal'] = orderData['subtotal'] ?? 0.0;
      orderDetails['tax'] = orderData['tax'] ?? 0.0;
      orderDetails['deliveryFee'] = orderData['deliveryFee'] ?? 0.0;
      orderDetails['paymentMethod'] = orderData['paymentMethod'] ?? 'Unknown';
      orderDetails['orderComments'] = orderData['orderComments'] ?? '';

      // Get items
      if (orderData.containsKey('items') && orderData['items'] is Map) {
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

      // Get delivery address
      if (orderData.containsKey('deliveryAddress') &&
          orderData['deliveryAddress'] is Map) {
        orderDetails['deliveryAddress'] =
            Map<String, dynamic>.from(orderData['deliveryAddress'] as Map);
      }

      // Get tracking information
      if (orderData.containsKey('tracking') && orderData['tracking'] is Map) {
        orderDetails['tracking'] =
            Map<String, dynamic>.from(orderData['tracking'] as Map);
      }

      // Get customer information
      final userSnapshot =
          await _databaseRef.child('users/${widget.userId}').get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        orderDetails['customerName'] = userData['name'] ?? 'Customer';
        orderDetails['customerEmail'] = userData['email'] ?? '';

        if (userData.containsKey('profile') && userData['profile'] is Map) {
          final profile = userData['profile'] as Map<dynamic, dynamic>;
          orderDetails['customerPhone'] = profile['phoneNumber'] ?? '';
        }
      }

      // Get restaurant information
      final restaurantSnapshot =
          await _databaseRef.child('users/${widget.restaurantId}').get();
      if (restaurantSnapshot.exists) {
        final restaurantData =
            restaurantSnapshot.value as Map<dynamic, dynamic>;
        orderDetails['restaurantName'] = restaurantData['name'] ?? 'Restaurant';

        if (restaurantData.containsKey('profile') &&
            restaurantData['profile'] is Map) {
          final profile = restaurantData['profile'] as Map<dynamic, dynamic>;
          orderDetails['restaurantAddress'] = profile['address'] ?? '';
          orderDetails['restaurantCity'] = profile['city'] ?? '';
          orderDetails['restaurantPhone'] = profile['phoneNumber'] ?? '';
        }
      }

      setState(() {
        _orderDetails = orderDetails;
        _isLoading = false;

        // Update map markers if we have location data
        _updateMapMarkers();
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
      print('Error fetching order details: $error');
    }
  }

  void _updateMapMarkers() {
    if (_orderDetails == null) return;

    _markers.clear();
    _polylines.clear();

    print("Updating map markers with data: ${_orderDetails!['tracking']}");

    // Restaurant location (use default if not available)
    LatLng restaurantLocation = LatLng(45.5017, -73.5673); // Default: Montreal

    // Add restaurant marker
    if (_orderDetails!.containsKey('tracking') &&
        _orderDetails!['tracking'] is Map &&
        _orderDetails!['tracking'].containsKey('restaurantLocation')) {
      final location = _orderDetails!['tracking']['restaurantLocation']
          as Map<dynamic, dynamic>;

      if (location.containsKey('lat') && location.containsKey('lng')) {
        try {
          // Handle potential types (double, int, string)
          double lat = _safeToDouble(location['lat']);
          double lng = _safeToDouble(location['lng']);

          restaurantLocation = LatLng(lat, lng);
          print("Restaurant location: $lat, $lng");
        } catch (e) {
          print("Error parsing restaurant location: $e");
        }
      }
    } else {
      print("No restaurant location in tracking data");
    }

    _markers.add(
      Marker(
        markerId: MarkerId('restaurant'),
        position: restaurantLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: _orderDetails!['restaurantName'] ?? 'Restaurant',
          snippet: _orderDetails!['restaurantAddress'] ?? '',
        ),
      ),
    );

    // Customer/delivery location
    LatLng deliveryLocation =
        LatLng(45.5030, -73.5700); // Default: Near Montreal

    // First try from tracking data
    if (_orderDetails!.containsKey('tracking') &&
        _orderDetails!['tracking'] is Map &&
        _orderDetails!['tracking'].containsKey('deliveryLocation')) {
      final location = _orderDetails!['tracking']['deliveryLocation']
          as Map<dynamic, dynamic>;

      if (location.containsKey('lat') && location.containsKey('lng')) {
        try {
          double lat = _safeToDouble(location['lat']);
          double lng = _safeToDouble(location['lng']);

          deliveryLocation = LatLng(lat, lng);
          print("Delivery location from tracking: $lat, $lng");
        } catch (e) {
          print("Error parsing delivery location from tracking: $e");
        }
      }
    }
    // If not in tracking, try from deliveryLocation directly
    else if (_orderDetails!.containsKey('deliveryLocation') &&
        _orderDetails!['deliveryLocation'] is Map) {
      final location =
          _orderDetails!['deliveryLocation'] as Map<dynamic, dynamic>;

      // Check if location has lat/lng coordinates
      if (location.containsKey('lat') && location.containsKey('lng')) {
        try {
          double lat = _safeToDouble(location['lat']);
          double lng = _safeToDouble(location['lng']);

          deliveryLocation = LatLng(lat, lng);
          print("Delivery location direct: $lat, $lng");
        } catch (e) {
          print("Error parsing direct delivery location: $e");
        }
      } else {
        print("Delivery location data doesn't contain coordinates");
      }
    } else {
      print("No delivery location found in data");
    }

    _markers.add(
      Marker(
        markerId: MarkerId('customer'),
        position: deliveryLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: _orderDetails!['customerName'] ?? 'Customer',
          snippet: _orderDetails!.containsKey('deliveryAddress')
              ? '${_orderDetails!['deliveryAddress']['address']}, ${_orderDetails!['deliveryAddress']['city']}'
              : '',
        ),
      ),
    );

    // Add polyline between restaurant and customer
    _polylines.add(
      Polyline(
        polylineId: PolylineId('route'),
        points: [restaurantLocation, deliveryLocation],
        color: hangryBlue,
        width: 4,
      ),
    );

    // Update camera position if controller is available
    if (_mapController != null) {
      try {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            _getBounds([restaurantLocation, deliveryLocation]),
            100, // padding
          ),
        );
      } catch (e) {
        print("Error updating camera: $e");
        // Fallback to a fixed zoom level
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                (restaurantLocation.latitude + deliveryLocation.latitude) / 2,
                (restaurantLocation.longitude + deliveryLocation.longitude) / 2,
              ),
              zoom: 12,
            ),
          ),
        );
      }
    }
  }

// Helper method to safely convert various types to double
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01), // Add some padding
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );
  }

  Future<void> _markAsDelivered() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Update status in restaurant's record
      await _databaseRef
          .child('users/${widget.restaurantId}/orders/${widget.orderId}')
          .update({
        'status': 'delivered',
        'deliveredAt': ServerValue.timestamp,
      });

      // Update status in customer's record
      await _databaseRef
          .child('users/${widget.userId}/profile/orders/${widget.orderId}')
          .update({
        'status': 'delivered',
        'deliveredAt': ServerValue.timestamp,
      });

      // Update driver's assignment
      if (_user != null) {
        await _databaseRef
            .child('users/${_user!.uid}/assignments/${widget.orderId}')
            .update({
          'status': 'completed',
          'completedAt': ServerValue.timestamp,
        });

        // Stop location tracking
        _locationService.stopTracking();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Order marked as delivered!'),
            backgroundColor: Colors.green),
      );

      // Go back to orders screen
      Navigator.pop(context);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error marking order as delivered: $error'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
              ? _buildErrorWidget()
              : _orderDetails == null
                  ? Center(child: Text('No order details available'))
                  : _buildOrderDetailsContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget? _buildBottomBar() {
    if (_orderDetails == null) return null;

    final status = _orderDetails!['status'] as String;

    if (status == 'on_the_way') {
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
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _markAsDelivered,
                icon: Icon(Icons.check_circle),
                label: Text('Mark as Delivered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  Widget _buildErrorWidget() {
    return Center(
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
    );
  }

  Widget _buildOrderDetailsContent() {
    return Column(
      children: [
        // Map showing restaurant and customer locations - takes up half the screen
        Expanded(
          flex: 1,
          child: Container(
            margin: EdgeInsets.all(0),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(45.5017, -73.5673), // Montreal default
                zoom: 13,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _updateMapMarkers();
              },
            ),
          ),
        ),

        // Order details
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status bar
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_orderDetails!['status'])
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(_orderDetails!['status'])
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(_orderDetails!['status']),
                        color: _getStatusColor(_orderDetails!['status']),
                      ),
                      SizedBox(width: 8),
                      Text(
                        _getStatusText(_orderDetails!['status']),
                        style: TextStyle(
                          color: _getStatusColor(_orderDetails!['status']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Order ID and date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${widget.orderId.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hangryBlue,
                      ),
                    ),
                    Text(
                      _formatDate(_orderDetails!['orderDate']),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                Divider(height: 24),

                // Customer info
                // _buildSectionTitle('Customer Information'),
                // _buildInfoRow(
                //     'Name', _orderDetails!['customerName'] ?? 'Customer'),
                // if (_orderDetails!.containsKey('customerPhone') &&
                //     _orderDetails!['customerPhone'].toString().isNotEmpty)
                //   _buildInfoRow('Phone', _orderDetails!['customerPhone']),

                _buildCustomerInfoSection(),
                SizedBox(height: 16),

                // Delivery address
                if (_orderDetails!.containsKey('deliveryAddress'))
                  _buildAddressSection(),

                SizedBox(height: 16),

                // Order items
                _buildSectionTitle('Order Items'),
                _buildOrderItemsList(),

                SizedBox(height: 16),

                // Payment info
                _buildSectionTitle('Payment Information'),
                _buildPaymentDetails(),

                SizedBox(height: 16),

                // Notes (if any)
                if (_orderDetails!.containsKey('orderComments') &&
                    _orderDetails!['orderComments'].toString().isNotEmpty)
                  _buildNotesSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Customer Information'),
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
                  backgroundColor: hangryYellow.withOpacity(0.2),
                  child: Icon(Icons.person, color: hangryYellow),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _orderDetails!['customerName'] ?? 'Customer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_orderDetails!.containsKey('customerPhone') &&
                          _orderDetails!['customerPhone'].toString().isNotEmpty)
                        Text(
                          _orderDetails!['customerPhone'],
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.phone, color: Colors.green),
                      onPressed: () {
                        // Phone call functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Call functionality coming soon!')),
                        );
                      },
                    ),
                    _buildChatButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: hangryBlue,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  Widget _buildAddressSection() {
    final deliveryAddress =
        _orderDetails!['deliveryAddress'] as Map<String, dynamic>;
    final address = deliveryAddress['address'] ?? '';
    final city = deliveryAddress['city'] ?? '';
    final zipCode = deliveryAddress['zipCode'] ?? '';
    final phone = deliveryAddress['phone'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Delivery Address'),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, color: hangryYellow, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$address, $city, $zipCode',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (phone.isNotEmpty) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone, color: hangryYellow, size: 18),
                    SizedBox(width: 8),
                    Text(
                      phone,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemsList() {
    if (!_orderDetails!.containsKey('items') ||
        (_orderDetails!['items'] as Map).isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('No items found in this order'),
      );
    }

    final items = _orderDetails!['items'] as Map<String, dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(height: 1),
        itemBuilder: (context, index) {
          final itemEntry = items.entries.elementAt(index);
          final itemData = itemEntry.value;

          return ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            title: Text(
              '${itemData['quantity']}x ${itemData['name']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: itemData['comment'] != null &&
                    itemData['comment'].toString().isNotEmpty
                ? Text(
                    'Note: ${itemData['comment']}',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                  )
                : null,
            trailing: Text(
              '\$${(itemData['price'] * itemData['quantity']).toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentDetails() {
    final subtotal = _orderDetails!['subtotal'] as double;
    final tax = _orderDetails!['tax'] as double;
    final deliveryFee = _orderDetails!['deliveryFee'] as double;
    final total = _orderDetails!['total'] as double;
    final paymentMethod = _orderDetails!['paymentMethod'] as String;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Method:'),
              Text(
                paymentMethod,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal:'),
              Text('\$${subtotal.toStringAsFixed(2)}'),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tax:'),
              Text('\$${tax.toStringAsFixed(2)}'),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Fee:'),
              Text('\$${deliveryFee.toStringAsFixed(2)}'),
            ],
          ),
          Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: hangryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Customer Notes'),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            _orderDetails!['orderComments'],
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'preparing':
        return Colors.orange;
      case 'ready_for_pickup':
        return Colors.blue;
      case 'on_the_way':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.receipt;
      case 'preparing':
        return Icons.restaurant;
      case 'ready_for_pickup':
        return Icons.check_circle;
      case 'on_the_way':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Order Pending';
      case 'preparing':
        return 'Preparing';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'on_the_way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown Status';
    }
  }

  void _navigateToChat(BuildContext context) {
    if (_user != null &&
        widget.orderId != null &&
        widget.userId != null &&
        _orderDetails != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            orderId: widget.orderId,
            receiverId: widget.userId,
            receiverName: _orderDetails != null &&
                    _orderDetails!.containsKey('customerName')
                ? _orderDetails!['customerName']
                : 'Customer',
            orderStatus:
                _orderDetails != null ? _orderDetails!['status'] : 'pending',
            userType: 'driver', // Fixed as driver in this screen
          ),
        ),
      );
    }
  }

  Widget _buildChatButton() {
    final ChatService _chatService = ChatService();

    return StreamBuilder<int>(
      stream: Stream.periodic(Duration(seconds: 5)).asyncMap((_) {
        if (_user != null) {
          return _chatService.getUnreadMessageCount(
            orderId: widget.orderId,
            userId: _user!.uid,
            userType: 'driver',
          );
        }
        return Future.value(0);
      }),
      initialData: 0,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            FloatingActionButton(
              heroTag: 'chatBtn',
              onPressed: () => _navigateToChat(context),
              backgroundColor: hangryYellow,
              child: Icon(Icons.chat, color: Colors.black),
              mini: true,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
