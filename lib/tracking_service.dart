import 'package:firebase_database/firebase_database.dart';
import 'package:geocoding/geocoding.dart';

class TrackingService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Add tracking to an existing order
  Future<void> enableTrackingForOrder(String orderId, String userId, String restaurantId) async {
    try {
      // Get order data
      final orderSnapshot = await _database
          .child('users/$restaurantId/orders/$orderId')
          .get();

      if (!orderSnapshot.exists) {
        print('Order not found');
        return;
      }

      final orderData = orderSnapshot.value as Map<dynamic, dynamic>;

      // Check if tracking already exists
      if (orderData.containsKey('tracking')) {
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

      final deliveryAddress = deliveryAddressSnapshot.value as Map<dynamic, dynamic>;
      final addressString = deliveryAddress['address'] + ', ' +
          (deliveryAddress['city'] ?? '') + ', ' +
          (deliveryAddress['zipCode'] ?? '');

      // Convert address to coordinates (geocoding)
      List<Location> locations = await locationFromAddress(addressString);
      Location location = locations.first;

      // Get restaurant location (from restaurant profile or a default location)
      final restaurantSnapshot = await _database
          .child('users/$restaurantId/profile')
          .get();

      Map<String, dynamic> restaurantLocation = {
        'lat': 45.5019, // Default Montreal coordinates
        'lng': -73.5674
      };

      // If restaurant has location stored, use it
      if (restaurantSnapshot.exists) {
        final restaurantProfile = restaurantSnapshot.value as Map<dynamic, dynamic>?;
        if (restaurantProfile != null &&
            restaurantProfile.containsKey('location')) {
          restaurantLocation = Map<String, dynamic>.from(
              restaurantProfile['location'] as Map);
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
      await _database
          .child('users/$restaurantId/orders/$orderId')
          .update({
        'status': status,
        'statusUpdatedAt': now,
      });

      // Update in user's records
      await _database
          .child('users/$userId/profile/orders/$orderId')
          .update({
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
  Future<void> _assignDriverToOrder(String orderId, String restaurantId, String userId) async {
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
        return;
      }

      // Assign driver
      final assignedAt = ServerValue.timestamp;

      // Update restaurant's order record
      await _database
          .child('users/$restaurantId/orders/$orderId')
          .update({
        'assignedDriver': selectedDriverId,
        'assignedAt': assignedAt,
      });

      // Update user's order record
      await _database
          .child('users/$userId/profile/orders/$orderId')
          .update({
        'assignedDriver': selectedDriverId,
        'assignedAt': assignedAt,
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
    } catch (e) {
      print('Error assigning driver: $e');
    }
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