import 'package:firebase_database/firebase_database.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:math';

class TrackingService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Add tracking to an existing order
  Future<void> enableTrackingForOrder(
      String orderId, String userId, String restaurantId) async {
    try {
      // Check if tracking already exists
      final trackingSnapshot = await _database
          .child('users/$userId/profile/orders/$orderId/tracking')
          .get();

      if (trackingSnapshot.exists) {
        print('Tracking already enabled for this order');
        return;
      }

      // Get delivery address
      final deliveryAddressSnapshot = await _database
          .child('users/$userId/profile/orders/$orderId/deliveryAddress')
          .get();

      if (!deliveryAddressSnapshot.exists) {
        print('Delivery address not found');
        return;
      }

      final deliveryAddress =
          deliveryAddressSnapshot.value as Map<dynamic, dynamic>;
      final addressString = deliveryAddress['address'] +
          ', ' +
          (deliveryAddress['city'] ?? '') +
          ', ' +
          (deliveryAddress['zipCode'] ?? '');

      // Convert address to coordinates (geocoding)
      List<Location> locations;
      try {
        locations = await locationFromAddress(addressString);
      } catch (e) {
        print('Error geocoding address: $e');
        // Fallback to default coordinates
        locations = [
          Location(
              latitude: 45.5019, longitude: -73.5674, timestamp: DateTime.now())
        ];
      }

      Location location = locations.first;

      // Get restaurant location (from restaurant profile or a default location)
      final restaurantSnapshot =
          await _database.child('users/$restaurantId/profile').get();

      Map<String, dynamic> restaurantLocation = {
        'lat':
            45.5080, // Default coordinates (slightly different from delivery location)
        'lng': -73.5800
      };

      // If restaurant has location stored, use it
      if (restaurantSnapshot.exists) {
        final restaurantProfile =
            restaurantSnapshot.value as Map<dynamic, dynamic>?;
        if (restaurantProfile != null &&
            restaurantProfile.containsKey('location')) {
          restaurantLocation =
              Map<String, dynamic>.from(restaurantProfile['location'] as Map);
        } else if (restaurantProfile != null &&
            restaurantProfile.containsKey('address') &&
            restaurantProfile.containsKey('city')) {
          // Try to geocode restaurant address
          try {
            final restaurantAddress = restaurantProfile['address'] +
                ', ' +
                restaurantProfile['city'] +
                ', ' +
                (restaurantProfile['zipCode'] ?? '');

            final restaurantLocations =
                await locationFromAddress(restaurantAddress);
            if (restaurantLocations.isNotEmpty) {
              restaurantLocation = {
                'lat': restaurantLocations.first.latitude,
                'lng': restaurantLocations.first.longitude,
                'address': restaurantAddress,
              };
            }
          } catch (e) {
            print('Error geocoding restaurant address: $e');
            // Keep default coordinates
          }
        }
      }

      // Create tracking data structure
      final Map<String, dynamic> trackingData = {
        'tracking': {
          'isTracking': true,
          'lastUpdated': ServerValue.timestamp,
        },
        'deliveryLocation': {
          'address': addressString,
          'lat': location.latitude,
          'lng': location.longitude,
        },
        'restaurantLocation': restaurantLocation,
      };

      // Update the order in restaurant's records
      await _database
          .child('users/$restaurantId/orders/$orderId')
          .update(trackingData);

      // Update the order in user's records
      await _database
          .child('users/$userId/profile/orders/$orderId')
          .update(trackingData);

      print('Tracking enabled for order $orderId');

      // Simulate driver location updates if in development/testing
      if (restaurantSnapshot.exists) {
        _simulateDriverLocation(orderId, userId, restaurantId,
            location.latitude, location.longitude);
      }
    } catch (e) {
      print('Error enabling tracking: $e');
    }
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, String status,
      {required String restaurantId, required String userId}) async {
    try {
      final now = ServerValue.timestamp;

      // Update in restaurant's records
      await _database.child('users/$restaurantId/orders/$orderId').update({
        'status': status,
        'statusUpdatedAt': now,
      });

      // Update in user's records
      await _database.child('users/$userId/profile/orders/$orderId').update({
        'status': status,
        'statusUpdatedAt': now,
      });

      print('Updated order $orderId status to $status');

      // If status is ready_for_pickup, try to assign a driver
      if (status == 'ready_for_pickup') {
        await _assignDriverToOrder(orderId, restaurantId, userId);
      }
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  // Find and assign a driver
  Future<void> _assignDriverToOrder(
      String orderId, String restaurantId, String userId) async {
    try {
      // Find available drivers
      final driversSnapshot = await _database
          .child('users')
          .orderByChild('accountType')
          .equalTo('driver')
          .get();

      if (!driversSnapshot.exists) {
        print('No drivers found');
        return;
      }

      final drivers = driversSnapshot.value as Map<dynamic, dynamic>;
      String? selectedDriverId;

      // Find an active and approved driver
      drivers.forEach((key, value) {
        if (value is Map &&
            value['status'] == 'active' &&
            value['isApproved'] == true &&
            selectedDriverId == null) {
          selectedDriverId = key;
        }
      });

      if (selectedDriverId == null) {
        print('No available drivers found');

        // For testing/development, create a simulated driver
        await _createSimulatedDriver(orderId, restaurantId, userId);
        return;
      }

      // Assign driver
      final assignedAt = ServerValue.timestamp;

      // Update restaurant's order record
      await _database.child('users/$restaurantId/orders/$orderId').update({
        'assignedDriver': selectedDriverId,
        'assignedAt': assignedAt,
        'status': 'on_the_way', // Update status to on_the_way
      });

      // Update user's order record
      await _database.child('users/$userId/profile/orders/$orderId').update({
        'assignedDriver': selectedDriverId,
        'assignedAt': assignedAt,
        'status': 'on_the_way', // Update status to on_the_way
      });

      // Create assignment for driver
      await _database
          .child('users/$selectedDriverId/assignments/$orderId')
          .set({
        'orderId': orderId,
        'restaurantId': restaurantId,
        'userId': userId,
        'assignedAt': assignedAt,
        'status': 'assigned',
      });

      print('Assigned driver $selectedDriverId to order $orderId');

      // Start driver location updates
      _startDriverLocationUpdates(
          selectedDriverId!, orderId, userId, restaurantId);
    } catch (e) {
      print('Error assigning driver: $e');
    }
  }

  // Start driver location updates
  Future<void> _startDriverLocationUpdates(String driverId, String orderId,
      String userId, String restaurantId) async {
    try {
      // Get restaurant and delivery locations
      final orderSnapshot =
          await _database.child('users/$userId/profile/orders/$orderId').get();

      if (!orderSnapshot.exists) return;

      final orderData = orderSnapshot.value as Map<dynamic, dynamic>;

      if (!orderData.containsKey('restaurantLocation') ||
          !orderData.containsKey('deliveryLocation')) {
        return;
      }

      final restaurantLocation =
          orderData['restaurantLocation'] as Map<dynamic, dynamic>;
      final deliveryLocation =
          orderData['deliveryLocation'] as Map<dynamic, dynamic>;

      double startLat = restaurantLocation['lat'];
      double startLng = restaurantLocation['lng'];
      double endLat = deliveryLocation['lat'];
      double endLng = deliveryLocation['lng'];

      // Create initial driver location at restaurant
      await _database
          .child('users/$restaurantId/orders/$orderId/tracking/driverLocation')
          .set({
        'lat': startLat,
        'lng': startLng,
        'lastUpdated': ServerValue.timestamp,
      });

      await _database
          .child(
              'users/$userId/profile/orders/$orderId/tracking/driverLocation')
          .set({
        'lat': startLat,
        'lng': startLng,
        'lastUpdated': ServerValue.timestamp,
      });

      // Calculate ETA
      await _calculateAndUpdateETA(
          orderId, userId, restaurantId, startLat, startLng, endLat, endLng);
    } catch (e) {
      print('Error starting driver location updates: $e');
    }
  }

  // For testing/development - create a simulated driver if no real drivers are available
  Future<void> _createSimulatedDriver(
      String orderId, String restaurantId, String userId) async {
    try {
      // Generate a unique ID for the simulated driver
      final simDriverId = 'sim_driver_${DateTime.now().millisecondsSinceEpoch}';

      // Create simulated driver in database
      await _database.child('users/$simDriverId').set({
        'name': 'Test Driver',
        'email': 'test@example.com',
        'accountType': 'driver',
        'status': 'active',
        'isApproved': true,
        'profile': {
          'fullName': 'Test Driver',
          'phoneNumber': '555-123-4567',
          'carModel': 'Test Car',
          'carColor': 'Blue',
          'plateNumber': 'TEST123',
        }
      });

      // Assign this driver to the order
      final assignedAt = ServerValue.timestamp;

      // Update restaurant's order record
      await _database.child('users/$restaurantId/orders/$orderId').update({
        'assignedDriver': simDriverId,
        'assignedAt': assignedAt,
        'status': 'on_the_way',
      });

      // Update user's order record
      await _database.child('users/$userId/profile/orders/$orderId').update({
        'assignedDriver': simDriverId,
        'assignedAt': assignedAt,
        'status': 'on_the_way',
      });

      print(
          'Created and assigned simulated driver $simDriverId to order $orderId');

      // Start simulated driver location updates
      _startDriverLocationUpdates(simDriverId, orderId, userId, restaurantId);
    } catch (e) {
      print('Error creating simulated driver: $e');
    }
  }

  // For testing/development - simulate driver location updates
  void _simulateDriverLocation(String orderId, String userId,
      String restaurantId, double destLat, double destLng) async {
    try {
      // Check if order is in the right state
      final orderSnapshot =
          await _database.child('users/$userId/profile/orders/$orderId').get();

      if (!orderSnapshot.exists) return;

      final orderData = orderSnapshot.value as Map<dynamic, dynamic>;

      // Only proceed if the order has an assigned driver
      if (!orderData.containsKey('assignedDriver') ||
          orderData['assignedDriver'] == null) {
        // If not assigned, try to assign a driver
        updateOrderStatus(orderId, 'ready_for_pickup',
            restaurantId: restaurantId, userId: userId);
        return;
      }

      // Get restaurant location
      if (!orderData.containsKey('restaurantLocation')) return;
      final restaurantLocation =
          orderData['restaurantLocation'] as Map<dynamic, dynamic>;

      double startLat = restaurantLocation['lat'];
      double startLng = restaurantLocation['lng'];

      // Calculate number of steps for simulation (more steps = smoother movement)
      int steps = 20;
      double latStep = (destLat - startLat) / steps;
      double lngStep = (destLng - startLng) / steps;

      // Simulate driver moving from restaurant to delivery location
      for (int i = 0; i <= steps; i++) {
        // Add some randomness to the path
        double randomLat =
            Random().nextDouble() * 0.001 * (Random().nextBool() ? 1 : -1);
        double randomLng =
            Random().nextDouble() * 0.001 * (Random().nextBool() ? 1 : -1);

        double currentLat = startLat + (latStep * i) + randomLat;
        double currentLng = startLng + (lngStep * i) + randomLng;

        // Update driver location
        await _database
            .child(
                'users/$restaurantId/orders/$orderId/tracking/driverLocation')
            .set({
          'lat': currentLat,
          'lng': currentLng,
          'lastUpdated': ServerValue.timestamp,
        });

        await _database
            .child(
                'users/$userId/profile/orders/$orderId/tracking/driverLocation')
            .set({
          'lat': currentLat,
          'lng': currentLng,
          'lastUpdated': ServerValue.timestamp,
        });

        // Calculate and update ETA
        await _calculateAndUpdateETA(orderId, userId, restaurantId, currentLat,
            currentLng, destLat, destLng);

        // Wait before next update
        await Future.delayed(Duration(seconds: 3));

        // Check if order still exists (might have been cancelled or updated)
        final currentOrderStatus = await _database
            .child('users/$userId/profile/orders/$orderId/status')
            .get();

        if (!currentOrderStatus.exists ||
            currentOrderStatus.value != 'on_the_way') {
          break;
        }

        // Deliver the order when we reach the destination
        if (i == steps) {
          await updateOrderStatus(orderId, 'delivered',
              restaurantId: restaurantId, userId: userId);
        }
      }
    } catch (e) {
      print('Error simulating driver location: $e');
    }
  }

  // Calculate ETA based on distance
  Future<void> _calculateAndUpdateETA(
      String orderId,
      String userId,
      String restaurantId,
      double driverLat,
      double driverLng,
      double destLat,
      double destLng) async {
    try {
      // Calculate distance
      final double distance =
          _calculateDistance(driverLat, driverLng, destLat, destLng);

      // Assume average speed of 30 km/h
      final double duration = (distance / 30) * 60; // minutes

      // Calculate arrival time
      final now = DateTime.now();
      final arrivalTime = now.add(Duration(minutes: duration.round()));

      // Update ETA in restaurant's order
      await _database
          .child('users/$restaurantId/orders/$orderId/tracking')
          .update({
        'estimatedArrivalTime': arrivalTime.millisecondsSinceEpoch,
        'estimatedDistance': distance,
        'estimatedDuration': duration,
      });

      // Update ETA in user's order
      await _database
          .child('users/$userId/profile/orders/$orderId/tracking')
          .update({
        'estimatedArrivalTime': arrivalTime.millisecondsSinceEpoch,
        'estimatedDistance': distance,
        'estimatedDuration': duration,
      });
    } catch (e) {
      print('Error calculating ETA: $e');
    }
  }

  // Distance calculation using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    const double R = 6371; // Earth's radius in km

    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 2 * R * asin(sqrt(a)); // 2 * R * arcsin(sqrt(a))
  }

  // Get a stream of order updates for tracking
  Stream<Map<String, dynamic>> getOrderUpdates(String orderId, String userId) {
    return _database
        .child('users/$userId/profile/orders/$orderId')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return {};

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return Map<String, dynamic>.from(data);
    });
  }
}
