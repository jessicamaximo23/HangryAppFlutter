class OrderTracking {
  final String orderId;
  final String status;
  final String? assignedDriver;
  final DateTime? assignedAt;
  final DriverLocation? driverLocation;
  final Location? restaurantLocation;
  final Location? deliveryLocation;
  final DateTime? estimatedArrival;

  OrderTracking({
    required this.orderId,
    required this.status,
    this.assignedDriver,
    this.assignedAt,
    this.driverLocation,
    this.restaurantLocation,
    this.deliveryLocation,
    this.estimatedArrival,
  });

  factory OrderTracking.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? tracking = map['tracking'] as Map<String, dynamic>?;

    return OrderTracking(
      orderId: map['orderId'] ?? '',
      status: map['status'] ?? 'pending',
      assignedDriver: map['assignedDriver'],
      assignedAt: map['assignedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['assignedAt'])
          : null,
      driverLocation: tracking != null && tracking['driverLocation'] != null
          ? DriverLocation.fromMap(tracking['driverLocation'])
          : null,
      restaurantLocation: map['restaurantLocation'] != null
          ? Location.fromMap(map['restaurantLocation'])
          : null,
      deliveryLocation: map['deliveryLocation'] != null
          ? Location.fromMap(map['deliveryLocation'])
          : null,
      estimatedArrival: tracking != null && tracking['estimatedArrivalTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(tracking['estimatedArrivalTime'])
          : null,
    );
  }
}

class Location {
  final double latitude;
  final double longitude;
  final String? address;

  Location({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory Location.fromMap(Map<dynamic, dynamic> map) {
    return Location(
      latitude: map['lat'] as double,
      longitude: map['lng'] as double,
      address: map['address'] as String?,
    );
  }
}

class DriverLocation extends Location {
  final DateTime lastUpdated;

  DriverLocation({
    required double latitude,
    required double longitude,
    required this.lastUpdated,
  }) : super(latitude: latitude, longitude: longitude);

  factory DriverLocation.fromMap(Map<dynamic, dynamic> map) {
    return DriverLocation(
      latitude: map['lat'] as double,
      longitude: map['lng'] as double,
      lastUpdated: DateTime.now(), // Firebase doesn't always include this
    );
  }
}