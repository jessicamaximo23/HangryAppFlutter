import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hangry_app_flutter/restaurant_map_screen.dart';
import 'restaurant_menu_screen.dart';

class RestaurantListingScreen extends StatefulWidget {
  const RestaurantListingScreen({Key? key}) : super(key: key);

  @override
  _RestaurantListingScreenState createState() =>
      _RestaurantListingScreenState();
}

class _RestaurantListingScreenState extends State<RestaurantListingScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  List<Map<String, dynamic>> _restaurants = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
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
            };

            // Try to get profile data for address
            if (value.containsKey('profile') && value['profile'] is Map) {
              final profile = value['profile'] as Map<dynamic, dynamic>;

              restaurant['address'] = profile['address'] ?? '';
              restaurant['city'] = profile['city'] ?? '';
              restaurant['cuisine'] = profile['typeofcuisine'] ?? 'Various';
            }

            restaurants.add(restaurant);
          }
        });

        setState(() {
          _restaurants = restaurants;
          _isLoading = false;
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

  void _navigateToMapTest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantMapScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Restaurants',
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
        backgroundColor: hangryYellow,
        actions: [
          IconButton(
            icon: Icon(Icons.map, color: Colors.black),
            onPressed: _navigateToMapTest,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: hangryYellow,
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget()
              : _restaurants.isEmpty
                  ? Center(
                      child: Text(
                        'No restaurants available',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _restaurants.length,
                      itemBuilder: (context, index) {
                        final restaurant = _restaurants[index];
                        return _buildRestaurantCard(context, restaurant);
                      },
                    ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(16),
        margin: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
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
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRestaurants,
              child: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hangryYellow,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(
      BuildContext context, Map<String, dynamic> restaurant) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant image
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: restaurant['profileImageUrl'] != null &&
                    restaurant['profileImageUrl'].isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: restaurant['profileImageUrl'],
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: hangryYellow,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 150,
                      color: Colors.grey[300],
                      child:
                          Icon(Icons.restaurant, color: hangryYellow, size: 50),
                    ),
                  )
                : Container(
                    height: 150,
                    color: Colors.grey[300],
                    width: double.infinity,
                    child:
                        Icon(Icons.restaurant, color: hangryYellow, size: 50),
                  ),
          ),

          // Restaurant details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant['name'] ?? 'Unknown Restaurant',
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

                SizedBox(height: 16),

                // Buttons in a row layout
                Row(
                  children: [
                    // View Menu button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _navigateToRestaurantMenu(
                          restaurant['uid'],
                          restaurant['name'],
                        ),
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
                    SizedBox(width: 8),
                    // Simple Map Test button
                    IconButton(
                      onPressed: _navigateToMapTest,
                      icon: Icon(
                        Icons.map,
                        color: hangryBlue,
                        size: 28,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
