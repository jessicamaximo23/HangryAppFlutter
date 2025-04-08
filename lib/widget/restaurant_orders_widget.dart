import 'package:flutter/material.dart';
import '../order_status_service.dart';

class RestaurantOrdersWidget extends StatefulWidget {
  final String restaurantId;

  const RestaurantOrdersWidget({
    Key? key,
    required this.restaurantId,
  }) : super(key: key);

  @override
  _RestaurantOrdersWidgetState createState() => _RestaurantOrdersWidgetState();
}

class _RestaurantOrdersWidgetState extends State<RestaurantOrdersWidget> {
  final OrderStatusService _orderService = OrderStatusService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _orderService.getRestaurantOrders(widget.restaurantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return Center(child: Text('No orders found'));
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String orderId = order['orderId'] ?? '';
    final String status = order['status'] ?? 'pending';
    final String orderDate = order['orderDate'] ?? '';
    final double total = double.tryParse(order['total'].toString()) ?? 0.0;
    final String userId = order['userId'] ?? '';

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #$orderId',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            SizedBox(height: 8),
            Text('Date: $orderDate'),
            Text('Total: \$${total.toStringAsFixed(2)}'),
            SizedBox(height: 16),

            // Status update buttons - show appropriate buttons based on current status
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'pending')
                  _buildStatusButton(
                    'Preparing',
                    'preparing',
                    Colors.orange,
                    orderId,
                    userId,
                  ),
                if (status == 'preparing')
                  _buildStatusButton(
                    'Ready for Pickup',
                    'ready_for_pickup',
                    Colors.green,
                    orderId,
                    userId,
                  ),
              ],
            ),
          ],
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
        text = 'On the way';
        break;
      case 'delivered':
        color = Colors.green;
        text = 'Delivered';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
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

  Widget _buildStatusButton(
      String label,
      String status,
      Color color,
      String orderId,
      String userId,
      ) {
    return ElevatedButton(
      onPressed: () => _updateOrderStatus(orderId, status, userId),
      child: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _updateOrderStatus(
      String orderId,
      String status,
      String userId,
      ) async {
    try {
      await _orderService.updateOrderStatus(
        orderId: orderId,
        status: status,
        restaurantId: widget.restaurantId,
        userId: userId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to $status')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}