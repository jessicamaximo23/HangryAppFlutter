import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RestaurantOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String userId;

  const RestaurantOrderDetailsScreen({
    Key? key,
    required this.orderId,
    required this.userId,
  }) : super(key: key);

  @override
  _RestaurantOrderDetailsScreenState createState() =>
      _RestaurantOrderDetailsScreenState();
}

class _RestaurantOrderDetailsScreenState
    extends State<RestaurantOrderDetailsScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  final User? _user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  Map<String, dynamic> _orderData = {};
  // Keep track of the original data source paths for updates
  Map<String, String> _dataSourcePaths = {};
  bool _isLoading = true;
  String _errorMessage = '';
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    if (_user == null || widget.orderId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not authenticated or invalid order ID';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Reset data source paths
      _dataSourcePaths = {};
      bool dataFound = false;

      // CRITICAL: First check if the order is in simplified format under users/{restaurant_id}/orders/{order_id}
      // This is typically where just the status is updated
      final simpleOrderPath = 'users/${_user!.uid}/orders/${widget.orderId}';
      final simpleOrderSnapshot =
          await _databaseRef.child(simpleOrderPath).get();

      // If it exists here, we need to merge any data found with the full order data
      Map<String, dynamic> simplifiedData = {};
      if (simpleOrderSnapshot.exists) {
        _dataSourcePaths['restaurant_simple'] = simpleOrderPath;
        simplifiedData = _normalizeOrderData(simpleOrderSnapshot.value is Map
            ? (simpleOrderSnapshot.value as Map<dynamic, dynamic>)
            : {'status': simpleOrderSnapshot.value, 'orderId': widget.orderId});
      }

      // Now look for the full order data in all possible locations
      List<String> potentialPaths = [
        // Restaurant's direct orders path (most detailed data)
        'users/${_user!.uid}/profile/orders/${widget.orderId}',
        // Global orders collection
        'orders/${widget.orderId}',
        // Order directly under restaurant (less common)
        'users/${_user!.uid}/orders/${widget.orderId}'
      ];

      // Try to find the most complete order data first
      Map<String, dynamic> fullOrderData = {};
      for (String path in potentialPaths) {
        final orderSnapshot = await _databaseRef.child(path).get();
        if (orderSnapshot.exists && orderSnapshot.value is Map) {
          final Map<dynamic, dynamic> rawData =
              orderSnapshot.value as Map<dynamic, dynamic>;
          // Store this path for future updates
          _dataSourcePaths['full_data'] = path;

          // Normalize the data
          fullOrderData = _normalizeOrderData(rawData);
          dataFound = true;
          break;
        }
      }

      // If we still don't have the order data, we need to check for iOS/Android format
      if (!dataFound) {
        // Try to find it in iOS/Android format (with array-based items)
        // Check in the restaurant profile orders
        final restaurantProfilePath =
            'users/${_user!.uid}/profile/orders/${widget.orderId}';
        final profileOrderSnapshot =
            await _databaseRef.child(restaurantProfilePath).get();

        if (profileOrderSnapshot.exists) {
          _dataSourcePaths['restaurant_profile'] = restaurantProfilePath;
          fullOrderData = _normalizeOrderData(profileOrderSnapshot.value is Map
              ? (profileOrderSnapshot.value as Map<dynamic, dynamic>)
              : {'orderId': widget.orderId});
          dataFound = true;
        }
      }

      // If we still don't have data, check the user's profile
      if (!dataFound && widget.userId.isNotEmpty) {
        final userProfilePath =
            'users/${widget.userId}/profile/orders/${widget.orderId}';
        final userOrderSnapshot =
            await _databaseRef.child(userProfilePath).get();

        if (userOrderSnapshot.exists) {
          _dataSourcePaths['user_profile'] = userProfilePath;
          fullOrderData = _normalizeOrderData(userOrderSnapshot.value is Map
              ? (userOrderSnapshot.value as Map<dynamic, dynamic>)
              : {'orderId': widget.orderId});
          dataFound = true;
        }
      }

      // MERGE DATA: If we have simplified status data AND full data, merge them
      // The simplified data will have the most recent status
      Map<String, dynamic> mergedData = {};

      if (dataFound) {
        // Start with the full data
        mergedData = Map.from(fullOrderData);

        // If we have simplified data (especially status), overlay it
        if (simplifiedData.isNotEmpty) {
          // Only copy the status from the simplified data if it exists
          if (simplifiedData.containsKey('status') &&
              simplifiedData['status'] != null) {
            mergedData['status'] = simplifiedData['status'];
          }
          if (simplifiedData.containsKey('statusUpdatedAt') &&
              simplifiedData['statusUpdatedAt'] != null) {
            mergedData['statusUpdatedAt'] = simplifiedData['statusUpdatedAt'];
          }
        }

        // If we still don't have all critical data, check other paths
        if (mergedData['items'] == null ||
            (mergedData['items'] is Map &&
                (mergedData['items'] as Map).isEmpty)) {
          // Try to find items from the user's order record
          if (widget.userId.isNotEmpty) {
            final userOrderPath =
                'users/${widget.userId}/profile/orders/${widget.orderId}';
            final userOrderData = await _databaseRef.child(userOrderPath).get();

            if (userOrderData.exists && userOrderData.value is Map) {
              final userData = userOrderData.value as Map<dynamic, dynamic>;
              if (userData.containsKey('items')) {
                mergedData['items'] = userData['items'];

                // Also grab other missing data if available
                if (mergedData['subtotal'] == null &&
                    userData.containsKey('subtotal')) {
                  mergedData['subtotal'] = userData['subtotal'];
                }
                if (mergedData['total'] == null &&
                    userData.containsKey('total')) {
                  mergedData['total'] = userData['total'];
                }
                if (mergedData['tax'] == null && userData.containsKey('tax')) {
                  mergedData['tax'] = userData['tax'];
                }
              }
            }
          }
        }

        setState(() {
          _orderData = mergedData;
          _isLoading = false;
        });
        return;
      }

      // If we reached here, try one last fallback for iOS/Android format
      // Sometimes the data could be in a different structure
      final iosAndroidPath =
          'users/${_user!.uid}/accountType: restaurant/orders/${widget.orderId}';
      final iosSnapshot = await _databaseRef.child(iosAndroidPath).get();

      if (iosSnapshot.exists) {
        _dataSourcePaths['ios_android'] = iosAndroidPath;
        setState(() {
          _orderData = _normalizeOrderData(iosSnapshot.value is Map
              ? (iosSnapshot.value as Map<dynamic, dynamic>)
              : {'orderId': widget.orderId});
          _isLoading = false;
        });
        return;
      }

      // If we still couldn't find any data, show an error
      if (_orderData.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Order data not found. Order ID: ${widget.orderId}';
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching order details: $error';
      });
      print('Error fetching order details: $error');
    }
  }

  // Future<void> _fetchOrderDetails() async {
  //   if (_user == null || widget.orderId.isEmpty) {
  //     setState(() {
  //       _isLoading = false;
  //       _errorMessage = 'User not authenticated or invalid order ID';
  //     });
  //     return;
  //   }
  //
  //   setState(() {
  //     _isLoading = true;
  //     _errorMessage = '';
  //   });
  //
  //   try {
  //     // Reset data source paths
  //     _dataSourcePaths = {};
  //
  //     // First try looking in the restaurant's direct orders
  //     final String restOrderPath =
  //         'users/${_user!.uid}/orders/${widget.orderId}';
  //     final orderSnapshot = await _databaseRef.child(restOrderPath).get();
  //
  //     if (orderSnapshot.exists) {
  //       _dataSourcePaths['restaurant'] = restOrderPath;
  //       setState(() {
  //         _orderData =
  //             _normalizeOrderData(orderSnapshot.value as Map<dynamic, dynamic>);
  //         _isLoading = false;
  //       });
  //       return;
  //     }
  //
  //     // Next try in profile/orders path (for iOS/Android compatibility)
  //     final String profileOrderPath =
  //         'users/${_user!.uid}/profile/orders/${widget.orderId}';
  //     final iosAndroidOrderSnapshot =
  //         await _databaseRef.child(profileOrderPath).get();
  //
  //     if (iosAndroidOrderSnapshot.exists) {
  //       _dataSourcePaths['restaurant_profile'] = profileOrderPath;
  //       setState(() {
  //         _orderData = _normalizeOrderData(
  //             iosAndroidOrderSnapshot.value as Map<dynamic, dynamic>);
  //         _isLoading = false;
  //       });
  //       return;
  //     }
  //
  //     // As a last resort, check global orders collection
  //     final String globalOrderPath = 'orders/${widget.orderId}';
  //     final globalOrderSnapshot =
  //         await _databaseRef.child(globalOrderPath).get();
  //
  //     if (globalOrderSnapshot.exists) {
  //       _dataSourcePaths['global'] = globalOrderPath;
  //       setState(() {
  //         _orderData = _normalizeOrderData(
  //             globalOrderSnapshot.value as Map<dynamic, dynamic>);
  //         _isLoading = false;
  //       });
  //       return;
  //     }
  //
  //     // If we reached here, the order wasn't found
  //     setState(() {
  //       _isLoading = false;
  //       _errorMessage = 'Order not found';
  //     });
  //   } catch (error) {
  //     setState(() {
  //       _isLoading = false;
  //       _errorMessage = 'Error fetching order details: $error';
  //     });
  //     print('Error fetching order details: $error');
  //   }
  // }

  Map<String, dynamic> _normalizeOrderData(Map<dynamic, dynamic> data) {
    Map<String, dynamic> normalizedData = Map<String, dynamic>.from(data);

    // Ensure orderId exists
    normalizedData['orderId'] = normalizedData['orderId'] ?? widget.orderId;

    // Convert items if needed - this is the critical part!
    if (normalizedData['items'] is List) {
      // Convert list of items to a map structure
      Map<String, dynamic> itemsMap = {};
      List itemsList = normalizedData['items'] as List;

      // First, determine if we can get subtotal and price from the order
      num totalSubtotal = normalizedData['subtotal'] as num? ??
          normalizedData['totalPrice'] as num? ??
          0.0;

      for (int i = 0; i < itemsList.length; i++) {
        // Try to get price and quantity from the original data structure
        num price = 0.0;
        int quantity = 1;

        // If this is the only item, assign full subtotal to it
        if (itemsList.length == 1) {
          price = totalSubtotal;
        }
        // Otherwise distribute evenly as fallback
        else if (totalSubtotal > 0) {
          price = totalSubtotal / itemsList.length;
        }

        itemsMap['item$i'] = {
          'name': itemsList[i],
          'price': price,
          'quantity': quantity,
          'subtotal': price * quantity,
          'comment': '',
        };
      }
      normalizedData['items'] = itemsMap;
    } else if (normalizedData['items'] == null) {
      normalizedData['items'] = <String, dynamic>{};
    }

    // Ensure other required fields are present with defaults
    normalizedData['total'] =
        normalizedData['total'] ?? normalizedData['totalPrice'] ?? 0.0;
    normalizedData['tax'] =
        normalizedData['tax'] ?? normalizedData['taxes'] ?? 0.0;
    normalizedData['subtotal'] = normalizedData['subtotal'] ?? 0.0;
    normalizedData['deliveryFee'] = normalizedData['deliveryFee'] ?? 0.0;

    // Process delivery address
    if (normalizedData['deliveryAddress'] is String) {
      // If deliveryAddress is a string, convert it to a map
      String addressString = normalizedData['deliveryAddress'] as String;
      List<String> addressParts = addressString.split('\n');

      Map<String, dynamic> addressMap = {
        'address': addressParts.isNotEmpty ? addressParts[0] : '',
        'city': addressParts.length > 1 ? addressParts[1] : '',
        'zipCode': addressParts.length > 2 ? addressParts[2] : '',
        'phone': addressParts.length > 3
            ? addressParts[3].replaceAll('Phone: ', '')
            : '',
      };

      normalizedData['deliveryAddress'] = addressMap;
    } else if (normalizedData['deliveryAddress'] == null) {
      normalizedData['deliveryAddress'] = {
        'address': '',
        'city': '',
        'zipCode': '',
        'phone': '',
      };
    }

    // Ensure userAddress is properly formatted
    if (normalizedData['userAddress'] is String) {
      String addressStr = normalizedData['userAddress'] as String;
      if (!normalizedData.containsKey('deliveryAddress') ||
          (normalizedData['deliveryAddress'] as Map).isEmpty) {
        // Extract address from userAddress string
        List<String> addressParts = addressStr.split('\n');
        Map<String, dynamic> addressMap = {
          'address': addressParts.length > 1 ? addressParts[1] : '',
          'city': addressParts.length > 2 ? addressParts[2].split(' ')[0] : '',
          'zipCode': addressParts.length > 2
              ? addressParts[2].split(' ').length > 1
                  ? addressParts[2].split(' ')[1]
                  : ''
              : '',
          'phone': addressParts.length > 3
              ? addressParts[3].replaceAll('Phone: ', '')
              : '',
        };
        normalizedData['deliveryAddress'] = addressMap;
      }
    }

    // Ensure status is properly set
    normalizedData['status'] = normalizedData['status'] ?? 'pending';
    if (normalizedData['status'] is String) {
      String status = (normalizedData['status'] as String).toLowerCase();
      if (status == "processing") {
        normalizedData['status'] = 'preparing';
      } else if (status == "approved") {
        normalizedData['status'] = 'pending';
      }
    }

    // Ensure payment method and status
    normalizedData['paymentMethod'] =
        normalizedData['paymentMethod'] ?? 'Unknown';
    normalizedData['paymentStatus'] =
        normalizedData['paymentStatus'] ?? 'pending';

    return normalizedData;
  }

  Future<void> _updateOrderStatus(String status) async {
    if (_user == null || widget.orderId.isEmpty) return;

    setState(() {
      _updatingStatus = true;
    });

    try {
      // Create the update object with timestamp
      Map<String, dynamic> updateData = {
        'status': status,
        'statusUpdatedAt': ServerValue.timestamp,
      };

      // Track successful updates
      bool anyUpdateSuccessful = false;
      String errorMessage = '';

      // First update the simplified path that only contains status
      final simplePath = 'users/${_user!.uid}/orders/${widget.orderId}';
      try {
        await _databaseRef.child(simplePath).update(updateData);
        anyUpdateSuccessful = true;
      } catch (e) {
        errorMessage += "Failed to update simple status: $e\n";
      }

      // Now update all data paths we have access to
      for (String key in _dataSourcePaths.keys) {
        final path = _dataSourcePaths[key]!;
        try {
          await _databaseRef.child(path).update(updateData);
          anyUpdateSuccessful = true;
        } catch (e) {
          errorMessage += "Failed to update $key: $e\n";
        }
      }

      // Always also update the user's order if we have the userId
      if (widget.userId.isNotEmpty && widget.userId != 'unknown') {
        final userPath =
            'users/${widget.userId}/profile/orders/${widget.orderId}';
        try {
          await _databaseRef.child(userPath).update(updateData);
          anyUpdateSuccessful = true;
        } catch (e) {
          errorMessage += "Failed to update user order: $e\n";
        }
      }

      if (anyUpdateSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to $status')),
        );

        // Refresh order details - but only after a short delay to let Firebase update
        await Future.delayed(Duration(milliseconds: 500));
        _fetchOrderDetails();
      } else {
        // All updates failed, show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order status: $errorMessage')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order status: $e')),
      );
    } finally {
      setState(() {
        _updatingStatus = false;
      });
    }
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return 'No date available';

    try {
      if (dateString is String) {
        if (dateString.contains(',')) {
          // Format: "2025-04-10, 3:27 PM"
          return dateString;
        } else {
          // Format: "2025-04-10 15:30:45"
          final dateTime = DateTime.parse(dateString);
          return DateFormat('MMM d, h:mm a').format(dateTime);
        }
      } else {
        return dateString.toString();
      }
    } catch (e) {
      return dateString.toString();
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String displayText;

    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.grey;
        displayText = 'New';
        break;
      case 'preparing':
      case 'processing':
        color = Colors.orange;
        displayText = 'Preparing';
        break;
      case 'ready_for_pickup':
        color = Colors.blue;
        displayText = 'Ready';
        break;
      case 'on_the_way':
        color = Colors.purple;
        displayText = 'Delivering';
        break;
      case 'delivered':
      case 'completed':
        color = Colors.green;
        displayText = 'Completed';
        break;
      case 'cancelled':
        color = Colors.red;
        displayText = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        displayText = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
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
                        onPressed: _fetchOrderDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hangryYellow,
                        ),
                        child: Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Banner
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                                  _orderData['status']?.toString() ?? '')
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(
                                    _orderData['status']?.toString() ?? '')
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(
                                  _orderData['status']?.toString() ?? ''),
                              color: _getStatusColor(
                                  _orderData['status']?.toString() ?? ''),
                              size: 36,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getStatusTitle(
                                        _orderData['status']?.toString() ?? ''),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(
                                          _orderData['status']?.toString() ??
                                              ''),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _getStatusDescription(
                                        _orderData['status']?.toString() ?? ''),
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
                      ),

                      SizedBox(height: 24),

                      // Order Information
                      Text(
                        'Order Information',
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
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                  'Order ID:',
                                  _orderData['orderId']?.toString() ??
                                      widget.orderId),
                              _buildInfoRow(
                                  'Date:',
                                  _formatDate(_orderData['orderDate'] ??
                                      _orderData['timestamp']?.toString())),
                              _buildInfoRow('Customer:',
                                  '${_orderData['customerName'] ?? 'Customer'}'),
                              _buildInfoRow('Payment Method:',
                                  '${_orderData['paymentMethod']?.toString() ?? 'Unknown'}'),
                              _buildInfoRow('Payment Status:',
                                  '${_orderData['paymentStatus']?.toString().capitalize() ?? 'Unknown'}'),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Delivery Address
                      if (_orderData.containsKey('deliveryAddress') &&
                          _orderData['deliveryAddress'] != null)
                        Column(
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
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDeliveryAddress(),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                          ],
                        ),

                      // Order Items
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
                          padding: EdgeInsets.all(16),
                          child: _buildOrderItems(),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Order Summary
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
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildSummaryRow('Subtotal',
                                  '\$${(_orderData['subtotal'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                              _buildSummaryRow('Tax',
                                  '\$${(_orderData['tax'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                              _buildSummaryRow('Delivery Fee',
                                  '\$${(_orderData['deliveryFee'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                              Divider(height: 24),
                              _buildSummaryRow(
                                'Total',
                                '\$${(_orderData['total'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),

                      // Add Driver Note if order is ready for pickup
                      if ((_orderData['status']?.toString().toLowerCase() ??
                              '') ==
                          'ready_for_pickup')
                        Card(
                          elevation: 2,
                          color: Colors.blue[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver Assignment',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'This order is ready for pickup. A driver will be assigned soon.',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Order Comments
                      if (_orderData.containsKey('orderComments') &&
                          _orderData['orderComments'] != null &&
                          _orderData['orderComments'].toString().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 24),
                            Text(
                              'Customer Notes',
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
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _orderData['orderComments'].toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                      // Debug info for admin
                      if (_user?.email == 'villantijulien@gmail.com' ||
                          _user?.email == 'arepas@gmail.com')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 24),
                            Text(
                              'Debug Info (Admin Only)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Data Sources: ${_dataSourcePaths.values.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),

                      SizedBox(height: 50), // Space for the bottom button
                    ],
                  ),
                ),
      bottomNavigationBar: !_isLoading && _errorMessage.isEmpty
          ? _buildBottomActionButton()
          : null,
    );
  }

  Widget _buildDeliveryAddress() {
    final deliveryAddress =
        _orderData['deliveryAddress'] as Map<dynamic, dynamic>?;

    if (deliveryAddress == null || deliveryAddress.isEmpty) {
      return Text('No delivery address provided');
    }

    final address = deliveryAddress['address']?.toString() ?? '';
    final city = deliveryAddress['city']?.toString() ?? '';
    final zipCode = deliveryAddress['zipCode']?.toString() ?? '';
    final phone = deliveryAddress['phone']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address,
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 4),
        Text(
          '$city, $zipCode',
          style: TextStyle(fontSize: 16),
        ),
        if (phone.isNotEmpty) ...[
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone, size: 16, color: Colors.grey[700]),
              SizedBox(width: 8),
              Text(
                phone,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOrderItems() {
    final items = _orderData['items'];

    if (items == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No items in this order',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    List<Widget> itemWidgets = [];

    // Handle items as a map
    if (items is Map) {
      Map<dynamic, dynamic> itemsMap = items;

      itemsMap.forEach((key, value) {
        if (value is Map) {
          final name = value['name']?.toString() ?? 'Unknown item';
          final price = value['price'] as num? ?? 0.0;
          final quantity = value['quantity'] as num? ?? 1;
          final subtotal = value['subtotal'] as num? ?? price * quantity;
          final comment = value['comment']?.toString() ?? '';

          itemWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hangryYellow,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      quantity.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (comment.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            comment,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '\$${subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      });
    }
    // Handle items as an array
    else if (items is List) {
      List<dynamic> itemsList = items;

      for (int i = 0; i < itemsList.length; i++) {
        String itemName = itemsList[i].toString();

        // Try to find individual item price
        num price = 0.0;
        num subtotal = 0.0;

        // If we have a total or subtotal, estimate the item price
        if (_orderData.containsKey('subtotal') &&
            _orderData['subtotal'] is num &&
            itemsList.length > 0) {
          price = (_orderData['subtotal'] as num) / itemsList.length;
          subtotal = price;
        } else if (_orderData.containsKey('total') &&
            _orderData['total'] is num &&
            itemsList.length > 0) {
          // Approximate by removing tax and delivery fee
          num totalWithoutExtras = (_orderData['total'] as num) -
              (_orderData['tax'] as num? ?? 0.0) -
              (_orderData['deliveryFee'] as num? ?? 0.0);
          price = totalWithoutExtras / itemsList.length;
          subtotal = price;
        }

        itemWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hangryYellow,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (itemWidgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No items in this order',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(children: itemWidgets);
  }

  Widget _buildSummaryRow(String label, String value, [bool isTotal = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? hangryBlue : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? hangryYellow : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButton() {
    final String status = _orderData['status']?.toString().toLowerCase() ?? '';

    // Don't show action buttons for completed or cancelled orders
    if (status == 'delivered' ||
        status == 'completed' ||
        status == 'cancelled') {
      return Container(height: 0);
    }

    String buttonText;
    Color buttonColor;
    String nextStatus;

    switch (status) {
      case 'pending':
      case 'approved':
      case 'processing':
        buttonText = 'Start Preparing';
        buttonColor = Colors.orange;
        nextStatus = 'preparing';
        break;
      case 'preparing':
        buttonText = 'Mark as Ready for Pickup';
        buttonColor = Colors.blue;
        nextStatus = 'ready_for_pickup';
        break;
      case 'ready_for_pickup':
        // No action for ready_for_pickup as we're waiting for driver
        return Container(
          color: Colors.blue[50],
          padding: EdgeInsets.all(16),
          child: Text(
            'Waiting for driver to pick up order',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case 'on_the_way':
        // No action for on_the_way as driver is delivering
        return Container(
          color: Colors.purple[50],
          padding: EdgeInsets.all(16),
          child: Text(
            'Order is being delivered by driver',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.purple[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      default:
        return Container(height: 0);
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed:
              _updatingStatus ? null : () => _updateOrderStatus(nextStatus),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _updatingStatus
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Updating...'),
                  ],
                )
              : Text(
                  buttonText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'approved':
      case 'processing':
        return Colors.grey;
      case 'preparing':
        return Colors.orange;
      case 'ready_for_pickup':
        return Colors.blue;
      case 'on_the_way':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'approved':
      case 'processing':
        return Icons.receipt;
      case 'preparing':
        return Icons.restaurant;
      case 'ready_for_pickup':
        return Icons.delivery_dining;
      case 'on_the_way':
        return Icons.directions_car;
      case 'delivered':
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusTitle(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'approved':
        return 'New Order';
      case 'processing':
      case 'preparing':
        return 'Preparing Order';
      case 'ready_for_pickup':
        return 'Ready for Pickup';
      case 'on_the_way':
        return 'Out for Delivery';
      case 'delivered':
      case 'completed':
        return 'Order Completed';
      case 'cancelled':
        return 'Order Cancelled';
      default:
        return 'Unknown Status';
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'approved':
        return 'This order is new and waiting to be prepared.';
      case 'processing':
      case 'preparing':
        return 'This order is currently being prepared.';
      case 'ready_for_pickup':
        return 'This order is ready for driver pickup.';
      case 'on_the_way':
        return 'This order is on the way to the customer.';
      case 'delivered':
      case 'completed':
        return 'This order has been delivered to the customer.';
      case 'cancelled':
        return 'This order has been cancelled.';
      default:
        return '';
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
