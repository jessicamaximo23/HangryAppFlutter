import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

import 'order_tracking.dart';

class TrackOrderScreen extends StatefulWidget {
  final String orderId;
  final String userId;
  final String restaurantId;
  final String restaurantName;

  const TrackOrderScreen({
    Key? key,
    required this.orderId,
    required this.userId,
    required this.restaurantId,
    required this.restaurantName,
  }) : super(key: key);

  @override
  _TrackOrderScreenState createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  // Colors
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  // Database references
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription? _orderSubscription;

  // Map controller
  GoogleMapController? _mapController;

  // State variables
  Map<String, dynamic>? _orderData;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _driverName = '';
  String _driverVehicle = '';
  String _driverPlate = '';
  bool _isLoading = true;
  String _errorMessage = '';
  DateTime? _estimatedArrival;

  @override
  void initState() {
    super.initState();
    _setupTracking();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  Future<void> _setupTracking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // First enable tracking if not already enabled
      await _enableOrderTracking();

      // Setup listener for order updates
      _orderSubscription = _database
          .child('users/${widget.userId}/profile/orders/${widget.orderId}')
          .onValue
          .listen((event) {
        if (!event.snapshot.exists) {
          setState(() {
            _errorMessage = 'Order not found';
            _isLoading = false;
          });
          return;
        }

        Map<dynamic, dynamic> orderData = event.snapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> formattedData = _formatOrderData(orderData);

        setState(() {
          _orderData = formattedData;
          _updateMarkers();
          _isLoading = false;
        });

        // If driver is assigned, get driver info
        if (_orderData!.containsKey('assignedDriver') && _driverName.isEmpty) {
          _loadDriverInfo(_orderData!['assignedDriver']);
        }

        // Update map view when driver location changes
        if (_mapController != null) {
          _updateMapView();
        }

        // Update estimated arrival time
        if (orderData.containsKey('tracking') &&
            orderData['tracking'] is Map &&
            orderData['tracking'].containsKey('estimatedArrivalTime')) {
          final arrivalTimeMs = orderData['tracking']['estimatedArrivalTime'] as int;
          setState(() {
            _estimatedArrival = DateTime.fromMillisecondsSinceEpoch(arrivalTimeMs);
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error setting up tracking: $e';
        _isLoading = false;
      });
      print('Error setting up tracking: $e');
    }
  }

  // Format the order data from Firebase into a more usable structure
  Map<String, dynamic> _formatOrderData(Map<dynamic, dynamic> data) {
    Map<String, dynamic> formatted = {};

    // Basic order info
    formatted['orderId'] = widget.orderId;
    formatted['status'] = data['status'] ?? 'pending';
    formatted['assignedDriver'] = data['assignedDriver'];
    formatted['assignedAt'] = data['assignedAt'];

    // Process tracking data
    if (data.containsKey('tracking') && data['tracking'] is Map) {
      final tracking = data['tracking'] as Map<dynamic, dynamic>;
      formatted['isTracking'] = tracking['isTracking'] ?? false;

      // Driver location
      if (tracking.containsKey('driverLocation') && tracking['driverLocation'] is Map) {
        final location = tracking['driverLocation'] as Map<dynamic, dynamic>;
        formatted['driverLocation'] = {
          'lat': location['lat'] as double,
          'lng': location['lng'] as double,
        };
      }

      // Estimated times
      if (tracking.containsKey('estimatedArrivalTime')) {
        formatted['estimatedArrivalTime'] = tracking['estimatedArrivalTime'];
      }

      if (tracking.containsKey('estimatedDistance')) {
        formatted['estimatedDistance'] = tracking['estimatedDistance'];
      }

      if (tracking.containsKey('estimatedDuration')) {
        formatted['estimatedDuration'] = tracking['estimatedDuration'];
      }
    }

    // Process location data
    if (data.containsKey('restaurantLocation') && data['restaurantLocation'] is Map) {
      final location = data['restaurantLocation'] as Map<dynamic, dynamic>;
      formatted['restaurantLocation'] = {
        'lat': location['lat'] as double,
        'lng': location['lng'] as double,
      };
    }

    if (data.containsKey('deliveryLocation') && data['deliveryLocation'] is Map) {
      final location = data['deliveryLocation'] as Map<dynamic, dynamic>;
      formatted['deliveryLocation'] = {
        'lat': location['lat'] as double,
        'lng': location['lng'] as double,
      };
    }

    return formatted;
  }

  Future<void> _enableOrderTracking() async {
    try {
      // Check if tracking is already enabled
      final trackingSnapshot = await _database
          .child('users/${widget.userId}/profile/orders/${widget.orderId}/tracking')
          .get();

      if (trackingSnapshot.exists) {
        print('Tracking already enabled');
        return;
      }

      // Get delivery address
      final deliveryAddressSnapshot = await _database
          .child('users/${widget.userId}/profile/orders/${widget.orderId}/deliveryAddress')
          .get();

      if (!deliveryAddressSnapshot.exists) {
        setState(() {
          _errorMessage = 'Delivery address not found';
        });
        return;
      }

      final deliveryAddress = deliveryAddressSnapshot.value as Map<dynamic, dynamic>;
      final addressString = '${deliveryAddress['address']}, ${deliveryAddress['city'] ?? ''}, ${deliveryAddress['zipCode'] ?? ''}';

      // Default location (Montreal) in case geocoding fails
      Map<String, dynamic> deliveryLocation = {
        'lat': 45.5019,
        'lng': -73.5674,
        'address': addressString,
      };

      // Default restaurant location
      Map<String, dynamic> restaurantLocation = {
        'lat': 45.5080,
        'lng': -73.5800,
      };

      // Try to get actual restaurant location
      final restaurantSnapshot = await _database
          .child('users/${widget.restaurantId}/profile')
          .get();

      if (restaurantSnapshot.exists) {
        final restaurantProfile = restaurantSnapshot.value as Map<dynamic, dynamic>?;

        if (restaurantProfile != null && restaurantProfile.containsKey('location')) {
          restaurantLocation = Map<String, dynamic>.from(
              restaurantProfile['location'] as Map);
        } else if (restaurantProfile != null &&
            restaurantProfile.containsKey('address') &&
            restaurantProfile.containsKey('city')) {
          // Use restaurant address as fallback
          restaurantLocation['address'] = '${restaurantProfile['address']}, ${restaurantProfile['city']}';
        }
      }

      // Setup tracking data structure
      final Map<String, dynamic> trackingData = {
        'tracking': {
          'isTracking': true,
          'lastUpdated': ServerValue.timestamp,
        },
        'deliveryLocation': deliveryLocation,
        'restaurantLocation': restaurantLocation,
      };

      // Update in user's order
      await _database
          .child('users/${widget.userId}/profile/orders/${widget.orderId}')
          .update(trackingData);

      // Update in restaurant's order
      await _database
          .child('users/${widget.restaurantId}/orders/${widget.orderId}')
          .update(trackingData);

      print('Tracking enabled for order ${widget.orderId}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error enabling tracking: $e';
      });
      print('Error enabling tracking: $e');
    }
  }

  Future<void> _loadDriverInfo(String driverId) async {
    try {
      final snapshot = await _database.child('users/$driverId').get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _driverName = data['name'] ?? 'Driver';

          if (data.containsKey('profile')) {
            final profile = data['profile'] as Map<dynamic, dynamic>;
            _driverVehicle = profile['carModel'] ?? '';
            _driverPlate = profile['plateNumber'] ?? '';
          }
        });
      }
    } catch (e) {
      print('Error loading driver info: $e');
    }
  }

  void _updateMarkers() {
    _markers = {};

    // Add restaurant marker
    if (_orderData != null &&
        _orderData!.containsKey('restaurantLocation')) {
      final restaurantLocation = _orderData!['restaurantLocation'] as Map<String, dynamic>;
      _markers.add(
        Marker(
          markerId: MarkerId('restaurant'),
          position: LatLng(
            restaurantLocation['lat'],
            restaurantLocation['lng'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: widget.restaurantName),
        ),
      );
    }

    // Add customer marker
    if (_orderData != null &&
        _orderData!.containsKey('deliveryLocation')) {
      final deliveryLocation = _orderData!['deliveryLocation'] as Map<String, dynamic>;
      _markers.add(
        Marker(
          markerId: MarkerId('customer'),
          position: LatLng(
            deliveryLocation['lat'],
            deliveryLocation['lng'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Delivery Location'),
        ),
      );
    }

    // Add driver marker
    if (_orderData != null &&
        _orderData!.containsKey('driverLocation')) {
      final driverLocation = _orderData!['driverLocation'] as Map<String, dynamic>;
      _markers.add(
        Marker(
          markerId: MarkerId('driver'),
          position: LatLng(
            driverLocation['lat'],
            driverLocation['lng'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
              title: _driverName.isNotEmpty ? _driverName : 'Driver'),
        ),
      );

      // Update polyline between driver and customer
      if (_orderData!.containsKey('deliveryLocation')) {
        final deliveryLocation = _orderData!['deliveryLocation'] as Map<String, dynamic>;
        _polylines = {
          Polyline(
            polylineId: PolylineId('route'),
            points: [
              LatLng(
                driverLocation['lat'],
                driverLocation['lng'],
              ),
              LatLng(
                deliveryLocation['lat'],
                deliveryLocation['lng'],
              ),
            ],
            color: hangryBlue,
            width: 5,
          ),
        };
      }
    }
  }

  void _updateMapView() {
    if (_mapController == null || _orderData == null) return;

    List<LatLng> points = [];

    // Add restaurant location if available
    if (_orderData!.containsKey('restaurantLocation')) {
      final location = _orderData!['restaurantLocation'] as Map<String, dynamic>;
      points.add(LatLng(location['lat'], location['lng']));
    }

    // Add delivery location if available
    if (_orderData!.containsKey('deliveryLocation')) {
      final location = _orderData!['deliveryLocation'] as Map<String, dynamic>;
      points.add(LatLng(location['lat'], location['lng']));
    }

    // Add driver location if available
    if (_orderData!.containsKey('driverLocation')) {
      final location = _orderData!['driverLocation'] as Map<String, dynamic>;
      points.add(LatLng(location['lat'], location['lng']));
    }

    if (points.isEmpty) return;

    // If we only have one point, center on it
    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points[0], 15),
      );
      return;
    }

    // Calculate bounds for multiple points
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (LatLng point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    // Add padding
    final double latPadding = (maxLat - minLat) * 0.2;
    final double lngPadding = (maxLng - minLng) * 0.2;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - latPadding, minLng - lngPadding),
          northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
        ),
        50, // padding
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Track Order',
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
              'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(_errorMessage),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _setupTracking,
              style: ElevatedButton.styleFrom(
                backgroundColor: hangryYellow,
              ),
              child: Text('Try Again'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Map takes 2/3 of the screen
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _getInitialMapPosition(),
                zoom: 13,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _updateMapView();
              },
            ),
          ),

          // Order info takes 1/3 of the screen
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status text
                  Text(
                    _getStatusDisplay(_orderData?['status'] ?? 'pending'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: hangryBlue,
                    ),
                  ),

                  SizedBox(height: 8),

                  // Estimated arrival
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.teal),
                      SizedBox(width: 8),
                      Text(
                        'Estimated arrival: ${_formatArrivalTime()}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Progress bar
                  LinearProgressIndicator(
                    value: _getProgressValue(),
                    backgroundColor: Colors.grey[300],
                    valueColor:
                    AlwaysStoppedAnimation<Color>(hangryYellow),
                  ),

                  SizedBox(height: 16),

                  // Status steps
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusStep(
                        'Preparing',
                        Icons.restaurant,
                        _isStatusActive('preparing'),
                      ),
                      _buildStatusStep(
                        'On the way',
                        Icons.delivery_dining,
                        _isStatusActive('on_the_way'),
                      ),
                      _buildStatusStep(
                        'Delivered',
                        Icons.home,
                        _isStatusActive('delivered'),
                      ),
                    ],
                  ),

                  Spacer(),

                  // Driver info (if assigned)
                  if (_orderData?['assignedDriver'] != null &&
                      _driverName.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                            hangryYellow.withOpacity(0.2),
                            child: Icon(
                              Icons.person,
                              color: hangryYellow,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _driverName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_driverVehicle.isNotEmpty &&
                                    _driverPlate.isNotEmpty)
                                  Text(
                                    '$_driverVehicle • $_driverPlate',
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Call functionality coming soon!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _getInitialMapPosition() {
    // Try to use delivery location
    if (_orderData != null && _orderData!.containsKey('deliveryLocation')) {
      final deliveryLocation = _orderData!['deliveryLocation'] as Map<String, dynamic>;
      return LatLng(deliveryLocation['lat'], deliveryLocation['lng']);
    }

    // Fallback to restaurant location
    if (_orderData != null && _orderData!.containsKey('restaurantLocation')) {
      final restaurantLocation = _orderData!['restaurantLocation'] as Map<String, dynamic>;
      return LatLng(restaurantLocation['lat'], restaurantLocation['lng']);
    }

    // Default to Montreal
    return LatLng(45.5019, -73.5674);
  }

  // Helper method to determine if a status is active based on current status
  bool _isStatusActive(String status) {
    final currentStatus = _orderData?['status'] ?? 'pending';

    switch (status) {
      case 'preparing':
        return currentStatus == 'preparing' ||
            currentStatus == 'ready_for_pickup' ||
            currentStatus == 'on_the_way' ||
            currentStatus == 'delivered';
      case 'on_the_way':
        return currentStatus == 'on_the_way' || currentStatus == 'delivered';
      case 'delivered':
        return currentStatus == 'delivered';
      default:
        return false;
    }
  }

  // Get progress value for progress bar
  double _getProgressValue() {
    final status = _orderData?['status'] ?? 'pending';

    switch (status) {
      case 'pending':
        return 0.1;
      case 'preparing':
        return 0.3;
      case 'ready_for_pickup':
        return 0.5;
      case 'on_the_way':
        return 0.7;
      case 'delivered':
        return 1.0;
      default:
        return 0.0;
    }
  }

  // Convert status to user-friendly text
  String _getStatusDisplay(String status) {
    switch (status) {
      case 'pending':
        return 'Order Received';
      case 'preparing':
        return 'Preparing';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'on_the_way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Processing';
    }
  }

  // Format arrival time
  String _formatArrivalTime() {
    if (_estimatedArrival == null) {
      return 'Calculating...';
    }

    final now = DateTime.now();
    final difference = _estimatedArrival!.difference(now);

    if (difference.isNegative) {
      return 'Arriving soon';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes';
    } else {
      final hour = _estimatedArrival!.hour;
      final minute = _estimatedArrival!.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }
  }

  // Create a status step widget
  Widget _buildStatusStep(String label, IconData icon, bool isActive) {
    return Column(
      children: [
        Icon(
          icon,
          color: isActive ? hangryYellow : Colors.grey[400],
          size: 28,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? hangryBlue : Colors.grey[400],
          ),
        ),
      ],
    );
  }
}