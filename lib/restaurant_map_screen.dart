import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'restaurant_menu_screen.dart';

class RestaurantMapScreen extends StatefulWidget {
  final Map<String, dynamic>? initialRestaurant;

  const RestaurantMapScreen({
    Key? key,
    this.initialRestaurant,
  }) : super(key: key);

  @override
  _RestaurantMapScreenState createState() => _RestaurantMapScreenState();
}

class _RestaurantMapScreenState extends State<RestaurantMapScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  String _errorMessage = '';

  // Montreal coordinates
  final LatLng _montrealLocation = LatLng(45.5017, -73.5673);
  LatLng _defaultLocation = LatLng(45.5017, -73.5673); // Default: Montreal

  List<Map<String, dynamic>> _restaurants = [];
  Position? _currentUserPosition;
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();

    // If we have an initial restaurant, set the default location to it
    if (widget.initialRestaurant != null) {
      final restaurant = widget.initialRestaurant!;
      if (restaurant.containsKey('latitude') &&
          restaurant.containsKey('longitude')) {
        _defaultLocation = LatLng(
          restaurant['latitude'] as double,
          restaurant['longitude'] as double,
        );
      }
    }

    _fetchUserLocation();
    _fetchRestaurants();
  }

  Future<void> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // If location services are not enabled, use Montreal as fallback
        setState(() {
          _currentUserPosition = Position(
            longitude: _montrealLocation.longitude,
            latitude: _montrealLocation.latitude,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
          _defaultLocation = _montrealLocation;
          _locationLoaded = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location services are disabled. Using Montreal as default location.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // If permissions are denied, use Montreal as fallback
          setState(() {
            _currentUserPosition = Position(
              longitude: _montrealLocation.longitude,
              latitude: _montrealLocation.latitude,
              timestamp: DateTime.now(),
              accuracy: 0.0,
              altitude: 0.0,
              heading: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
              altitudeAccuracy: 0.0,
              headingAccuracy: 0.0,
            );
            _defaultLocation = _montrealLocation;
            _locationLoaded = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location permissions are denied. Using Montreal as default location.'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // If permissions are permanently denied, use Montreal as fallback
        setState(() {
          _currentUserPosition = Position(
            longitude: _montrealLocation.longitude,
            latitude: _montrealLocation.latitude,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
          _defaultLocation = _montrealLocation;
          _locationLoaded = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permissions are permanently denied. Using Montreal as default location.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Get current position with timeout to avoid hanging
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      ).catchError((error) {
        print('Error getting position: $error');
        // Return Montreal coordinates as fallback
        return Position(
          longitude: _montrealLocation.longitude,
          latitude: _montrealLocation.latitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
      });

      // Check if the position is valid (if Geolocator returned valid coordinates)
      bool isValidLocation = position.latitude != 0 && position.longitude != 0;

      if (!isValidLocation) {
        position = Position(
          longitude: _montrealLocation.longitude,
          latitude: _montrealLocation.latitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not determine your location. Using Montreal as default.'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      setState(() {
        _currentUserPosition = position;
        // Only set default location if we don't have an initialRestaurant
        if (widget.initialRestaurant == null) {
          _defaultLocation = LatLng(position.latitude, position.longitude);
        }
        _locationLoaded = true;
      });

      // If map controller is ready and no initial restaurant is set, move to user's location
      if (_mapController != null && widget.initialRestaurant == null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14.0,
          ),
        );
      }
    } catch (e) {
      print('Error in location handling: $e');
      // Set Montreal as the fallback location
      setState(() {
        _currentUserPosition = Position(
          longitude: _montrealLocation.longitude,
          latitude: _montrealLocation.latitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
        _defaultLocation = _montrealLocation;
        _locationLoaded = true;
      });
    }
  }

  // Method to center the map on Montreal
  void _goToMontreal() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        _montrealLocation,
        14.0,
      ),
    );
  }

  // Method to center the map on user's current location or Montreal as fallback
  Future<void> _goToCurrentLocation() async {
    if (_currentUserPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude),
          14.0,
        ),
      );
    } else {
      // Try to get position again if not available
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ).catchError((error) {
          print('Error getting position again: $error');
          // Use Montreal as fallback
          return Position(
            longitude: _montrealLocation.longitude,
            latitude: _montrealLocation.latitude,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        });

        setState(() {
          _currentUserPosition = position;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14.0,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to get your current location. Using Montreal as default.'),
            duration: Duration(seconds: 3),
          ),
        );

        // Fall back to Montreal
        _goToMontreal();
      }
    }
  }

  Future<void> _fetchRestaurants() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final DatabaseReference databaseRef =
      FirebaseDatabase.instance.ref('users');
      final event = await databaseRef
          .orderByChild('accountType')
          .equalTo('restaurant')
          .once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> usersMap =
        event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> restaurants = [];

        await Future.forEach(usersMap.entries, (MapEntry entry) async {
          final key = entry.key;
          final value = entry.value as Map<dynamic, dynamic>;

          // Only include active and approved restaurants
          if (value['status'] == 'active' && value['isApproved'] == true) {
            Map<String, dynamic> restaurant = {
              'uid': key,
              'name': value['name'] ?? 'Unknown Restaurant',
              'profileImageUrl': value['profileImageUrl'] ?? '',
              'latitude': _montrealLocation.latitude +
                  (restaurants.length * 0.002), // Default coords in Montreal
              'longitude':
              _montrealLocation.longitude + (restaurants.length * 0.002),
            };

            // Try to get profile data for address
            if (value.containsKey('profile') && value['profile'] is Map) {
              final profile = value['profile'] as Map<dynamic, dynamic>;

              restaurant['address'] = profile['address'] ?? '';
              restaurant['city'] = profile['city'] ?? '';
              restaurant['cuisine'] = profile['typeofcuisine'] ?? 'Various';

              // If you have actual coordinates in your database
              if (profile.containsKey('latitude') &&
                  profile.containsKey('longitude')) {
                restaurant['latitude'] = profile['latitude'];
                restaurant['longitude'] = profile['longitude'];
              }
            }

            restaurants.add(restaurant);
          }
        });

        setState(() {
          _restaurants = restaurants;
          _updateMarkers();
          _isLoading = false;

          // If initial restaurant was provided, highlight it on the map
          if (widget.initialRestaurant != null) {
            final initialUid = widget.initialRestaurant!['uid'];
            final restaurant = _restaurants.firstWhere(
                  (r) => r['uid'] == initialUid,
              orElse: () => widget.initialRestaurant!,
            );

            // Slight delay to ensure map is ready
            Future.delayed(Duration(milliseconds: 500), () {
              if (_mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    LatLng(
                      restaurant['latitude'] as double,
                      restaurant['longitude'] as double,
                    ),
                    16.0,
                  ),
                );
                _showRestaurantInfo(restaurant);
              }
            });
          }
        });
      } else {
        setState(() {
          _restaurants = [];
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _updateMarkers() {
    _markers.clear();

    for (var restaurant in _restaurants) {
      final marker = Marker(
        markerId: MarkerId(restaurant['uid']),
        position: LatLng(
          restaurant['latitude'] as double,
          restaurant['longitude'] as double,
        ),
        infoWindow: InfoWindow(
          title: restaurant['name'],
          snippet: restaurant['cuisine'] ?? 'Restaurant',
          onTap: () {
            _navigateToRestaurantMenu(restaurant['uid'], restaurant['name']);
          },
        ),
        onTap: () {
          _showRestaurantInfo(restaurant);
        },
      );

      _markers.add(marker);
    }
  }

  void _navigateToRestaurantMenu(String restaurantId, String restaurantName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantMenuScreen(
          restaurantId: restaurantId,
          restaurantName: restaurantName,
        ),
      ),
    );
  }

  void _showRestaurantInfo(Map<String, dynamic> restaurant) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: restaurant['profileImageUrl'] != null &&
                        restaurant['profileImageUrl'].isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: restaurant['profileImageUrl'],
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            color: hangryYellow,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child:
                        Icon(Icons.restaurant, color: hangryYellow),
                      ),
                    )
                        : Container(
                      width: 70,
                      height: 70,
                      color: Colors.grey[300],
                      child: Icon(Icons.restaurant, color: hangryYellow),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant['name'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: hangryBlue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          restaurant['cuisine'] ?? 'Various cuisine',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        if (restaurant['address'] != null &&
                            restaurant['address'].isNotEmpty)
                          Text(
                            restaurant['address'] +
                                (restaurant['city'] != null
                                    ? ', ${restaurant["city"]}'
                                    : ''),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    _navigateToRestaurantMenu(
                        restaurant['uid'], restaurant['name']);
                  },
                  child: Text('View Menu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hangryYellow,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Restaurants Map',
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
        backgroundColor: hangryYellow,
        actions: [
          // Add Montreal button in app bar
          IconButton(
            icon: Icon(Icons.location_city, color: Colors.black),
            onPressed: _goToMontreal,
            tooltip: 'Go to Montreal',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _defaultLocation,
              zoom: 14.0,
            ),
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _updateMarkers();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Custom button instead
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            padding: EdgeInsets.only(
              bottom: 80, // Add padding to bottom for floating restaurant list
              right: 10, // Add padding to right for zoom controls
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(
                  color: hangryYellow,
                ),
              ),
            ),
          if (_errorMessage.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error loading restaurants',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(_errorMessage),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _fetchRestaurants,
                    child: Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hangryYellow,
                    ),
                  ),
                ],
              ),
            ),

          // Custom My Location Button - Top right corner
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: "locationBtn",
              mini: true,
              onPressed: _goToCurrentLocation,
              backgroundColor: Colors.white,
              child: Icon(Icons.my_location, color: hangryBlue),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "listBtn",
        onPressed: () {
          if (_restaurants.isEmpty) {
            _fetchRestaurants();
          } else {
            _showRestaurantsList();
          }
        },
        backgroundColor: hangryYellow,
        child: Icon(Icons.list, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  void _showRestaurantsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nearby Restaurants',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: hangryBlue,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _restaurants.length,
                  itemBuilder: (context, index) {
                    final restaurant = _restaurants[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: restaurant['profileImageUrl'] != null &&
                            restaurant['profileImageUrl'].isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: restaurant['profileImageUrl'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            width: 50,
                            height: 50,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            width: 50,
                            height: 50,
                            child: Icon(Icons.restaurant,
                                color: hangryYellow),
                          ),
                        )
                            : Container(
                          color: Colors.grey[300],
                          width: 50,
                          height: 50,
                          child:
                          Icon(Icons.restaurant, color: hangryYellow),
                        ),
                      ),
                      title: Text(restaurant['name']),
                      subtitle: Text(restaurant['cuisine'] ?? 'Restaurant'),
                      onTap: () {
                        Navigator.pop(context);

                        // Center the map on this restaurant
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(
                              restaurant['latitude'] as double,
                              restaurant['longitude'] as double,
                            ),
                            16.0,
                          ),
                        );

                        // Show restaurant info
                        _showRestaurantInfo(restaurant);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}