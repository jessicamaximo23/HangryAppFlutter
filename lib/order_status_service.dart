import 'package:firebase_database/firebase_database.dart';

class OrderStatusService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Update order status in both user and restaurant nodes
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    required String restaurantId,
    required String userId,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'status': status,
        'statusUpdatedAt': ServerValue.timestamp,
      };

      // Update in restaurant's orders
      await _database
          .child('users/$restaurantId/orders/$orderId')
          .update(updates);

      // Update in user's orders
      await _database
          .child('users/$userId/profile/orders/$orderId')
          .update(updates);

      print('Updated order $orderId status to $status');
    } catch (e) {
      print('Error updating order status: $e');
      throw e;
    }
  }

  // Get stream of orders for a restaurant
  Stream<List<Map<String, dynamic>>> getRestaurantOrders(String restaurantId) {
    return _database
        .child('users/$restaurantId/orders')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final orders = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        if (value is Map) {
          final orderData = Map<String, dynamic>.from(value as Map);
          orderData['orderId'] = key;
          orders.add(orderData);
        }
      });

      // Sort by orderDate (newest first)
      orders.sort((a, b) {
        final aDate = a['orderDate'] as String? ?? '';
        final bDate = b['orderDate'] as String? ?? '';
        return bDate.compareTo(aDate);
      });

      return orders;
    });
  }
}