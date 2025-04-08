import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import 'dart:math';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final Location _location = Location();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Timer? _locationUpdateTimer;
  StreamSubscription<LocationData>? _locationSubscription;
  String? _driverId;
  String? _orderId;
  String? _userId;
  String? _restaurantId;

  // Start tracking driver location
  Future<bool> startTracking({
    required String driverId,
    required String orderId,
    required String userId,
    required String restaurantId,
  }) async {
    _driverId = driverId;
    _orderId = orderId;
    _userId = userId;
    _restaurantId = restaurantId;

    // Request permission
    bool permissionGranted = await _requestPermission();
    if (!permissionGranted) {
      return false;
    }

    // Configure location service
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000, // 10 seconds
      distanceFilter: 10, // 10 meters
    );

    // Start tracking
    _locationSubscription = _location.onLocationChanged.listen((locationData) {
      _updateLocation(locationData);
    });

    // Backup timer in case location updates are slow
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      try {
        final locationData = await _location.getLocation();
        _updateLocation(locationData);
      } catch (e) {
        print('Error getting location: $e');
      }
    });

    return true;
  }

  // Stop tracking
  void stopTracking() {
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _locationSubscription = null;
    _locationUpdateTimer = null;
    _driverId = null;
    _orderId = null;
    _userId = null;
    _restaurantId = null;
  }

  // Update location in Firebase
  Future<void> _updateLocation(LocationData locationData) async {
    if (_driverId == null ||
        _orderId == null ||
        _userId == null ||
        _restaurantId == null) return;

    try {
      // Update driver's current location
      await _database.child('users/$_driverId').update({
        'currentLocation': {
          'lat': locationData.latitude,
          'lng': locationData.longitude,
        },
        'lastLocationUpdate': ServerValue.timestamp,
      });

      // Update location in restaurant's order
      await _database
          .child('users/$_restaurantId/orders/$_orderId/tracking')
          .update({
        'driverLocation': {
          'lat': locationData.latitude,
          'lng': locationData.longitude,
        },
        'lastUpdated': ServerValue.timestamp,
      });

      // Update location in user's order
      await _database
          .child('users/$_userId/profile/orders/$_orderId/tracking')
          .update({
        'driverLocation': {
          'lat': locationData.latitude,
          'lng': locationData.longitude,
        },
        'lastUpdated': ServerValue.timestamp,
      });

      // Calculate and update ETA
      await _calculateAndUpdateETA(locationData);
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // Request location permission
  Future<bool> _requestPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }

    return true;
  }

  // Calculate ETA
  Future<void> _calculateAndUpdateETA(LocationData driverLocation) async {
    try {
      // Get delivery location
      final snapshot = await _database
          .child('users/$_userId/profile/orders/$_orderId/deliveryLocation')
          .get();

      if (!snapshot.exists) return;

      final deliveryLocation = snapshot.value as Map<dynamic, dynamic>;
      final destLat = deliveryLocation['lat'] as double;
      final destLng = deliveryLocation['lng'] as double;

      // Calculate distance
      final double distance = _calculateDistance(driverLocation.latitude!,
          driverLocation.longitude!, destLat, destLng);

      // Assume average speed of 30 km/h
      final double duration = (distance / 30) * 60; // minutes

      // Calculate arrival time
      final now = DateTime.now();
      final arrivalTime = now.add(Duration(minutes: duration.round()));

      // Update ETA in restaurant's order
      await _database
          .child('users/$_restaurantId/orders/$_orderId/tracking')
          .update({
        'estimatedArrivalTime': arrivalTime.millisecondsSinceEpoch,
        'estimatedDistance': distance,
        'estimatedDuration': duration,
      });

      // Update ETA in user's order
      await _database
          .child('users/$_userId/profile/orders/$_orderId/tracking')
          .update({
        'estimatedArrivalTime': arrivalTime.millisecondsSinceEpoch,
        'estimatedDistance': distance,
        'estimatedDuration': duration,
      });
    } catch (e) {
      print('Error calculating ETA: $e');
    }
  }

  // Distance calculation
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180

    // Don't try to assign the cos function to a constant
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
