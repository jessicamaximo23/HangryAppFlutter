import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import './tracking_service.dart';
import '/order_tracking.dart';

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

  // Services
  final TrackingService _trackingService = TrackingService();

  // Map controller
  GoogleMapController? _mapController;

  // State variables
  OrderTracking? _orderTracking;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _driverName = '';
  String _driverVehicle = '';
  String _driverPlate = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupTracking();
  }

  Future<void> _setupTracking() async {
    // First make sure tracking is enabled for this order
    await _trackingService.enableTrackingForOrder(
        widget.orderId, widget.userId, widget.restaurantId);

    // Listen for updates
    _trackingService
        .getOrderUpdates(widget.orderId, widget.userId)
        .listen((orderData) {
      setState(() {
        _orderTracking = OrderTracking.fromMap(orderData);
        _updateMarkers();
        _isLoading = false;
      });

      // If driver is assigned, get driver info
      if (_orderTracking?.assignedDriver != null && _driverName.isEmpty) {
        _loadDriverInfo(_orderTracking!.assignedDriver!);
      }

      // Update map view when driver location changes
      if (_orderTracking?.driverLocation != null && _mapController != null) {
        _updateMapView();
      }
    });
  }

  Future<void> _loadDriverInfo(String driverId) async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref().child('users/$driverId').get();

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
    if (_orderTracking?.restaurantLocation != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('restaurant'),
          position: LatLng(
            _orderTracking!.restaurantLocation!.latitude,
            _orderTracking!.restaurantLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: widget.restaurantName),
        ),
      );
    }

    // Add customer marker
    if (_orderTracking?.deliveryLocation != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('customer'),
          position: LatLng(
            _orderTracking!.deliveryLocation!.latitude,
            _orderTracking!.deliveryLocation!.longitude,
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Delivery Location'),
        ),
      );
    }

    // Add driver marker
    if (_orderTracking?.driverLocation != null) {
      _markers.add(
        Marker(
          markerId: MarkerId('driver'),
          position: LatLng(
            _orderTracking!.driverLocation!.latitude,
            _orderTracking!.driverLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
              title: _driverName.isNotEmpty ? _driverName : 'Driver'),
        ),
      );

      // Update polyline between driver and customer
      if (_orderTracking?.deliveryLocation != null) {
        _polylines = {
          Polyline(
            polylineId: PolylineId('route'),
            points: [
              LatLng(
                _orderTracking!.driverLocation!.latitude,
                _orderTracking!.driverLocation!.longitude,
              ),
              LatLng(
                _orderTracking!.deliveryLocation!.latitude,
                _orderTracking!.deliveryLocation!.longitude,
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
    if (_mapController == null) return;

    // If we have restaurant, customer and driver locations, fit bounds
    if (_orderTracking?.restaurantLocation != null &&
        _orderTracking?.deliveryLocation != null) {
      List<LatLng> points = [
        LatLng(
          _orderTracking!.restaurantLocation!.latitude,
          _orderTracking!.restaurantLocation!.longitude,
        ),
        LatLng(
          _orderTracking!.deliveryLocation!.latitude,
          _orderTracking!.deliveryLocation!.longitude,
        ),
      ];

      // Add driver location if available
      if (_orderTracking?.driverLocation != null) {
        points.add(LatLng(
          _orderTracking!.driverLocation!.latitude,
          _orderTracking!.driverLocation!.longitude,
        ));
      }

      // Calculate bounds
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;

      for (LatLng point in points) {
        minLat = point.latitude < minLat ? point.latitude : minLat;
        maxLat = point.latitude > maxLat ? point.latitude : maxLat;
        minLng = point.longitude < minLng ? point.longitude : minLng;
        maxLng = point.longitude > maxLng ? point.longitude : maxLng;
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
    // If we only have driver location, center on it
    else if (_orderTracking?.driverLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(
          _orderTracking!.driverLocation!.latitude,
          _orderTracking!.driverLocation!.longitude,
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order'),
        backgroundColor: hangryYellow,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: hangryYellow))
          : Column(
              children: [
                // Map takes 2/3 of the screen
                Expanded(
                  flex: 2,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _orderTracking?.deliveryLocation != null
                          ? LatLng(
                              _orderTracking!.deliveryLocation!.latitude,
                              _orderTracking!.deliveryLocation!.longitude,
                            )
                          : LatLng(45.5019, -73.5674), // Default Montreal
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
                          _getStatusDisplay(
                              _orderTracking?.status ?? 'pending'),
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
                        if (_orderTracking?.assignedDriver != null &&
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
                                Column(
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
                              ],
                            ),
                          ),

                        SizedBox(height: 16),

                        // Chat button
                        ElevatedButton.icon(
                          onPressed: _orderTracking?.status == 'delivered'
                              ? null
                              : _openDriverChat,
                          icon: Icon(Icons.chat),
                          label: Text('Chat Driver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hangryBlue,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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

  // Helper method to determine if a status is active based on current status
  bool _isStatusActive(String status) {
    final currentStatus = _orderTracking?.status ?? 'pending';

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
    final status = _orderTracking?.status ?? 'pending';

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
    if (_orderTracking?.estimatedArrival == null) {
      return 'Calculating...';
    }

    final arrival = _orderTracking!.estimatedArrival!;
    final now = DateTime.now();
    final difference = arrival.difference(now);

    if (difference.isNegative) {
      return 'Arriving soon';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes';
    } else {
      final hour = arrival.hour;
      final minute = arrival.minute.toString().padLeft(2, '0');
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

  // Open chat with driver
  void _openDriverChat() {
    // Implement chat functionality or show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Chat functionality coming soon!')),
    );
  }
}
