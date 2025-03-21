import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

final Color hangryYellow = Color(0xFFFCBF49);
final Color hangryBlue = Color(0xFF003049);

class RestaurantsListingScreen extends StatefulWidget {
  const RestaurantsListingScreen({Key? key}) : super(key: key);

  @override
  _RestaurantsScreenState createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsListingScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('users');
  List<Map<String, dynamic>> restaurants = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchRestaurants();
  }

  void fetchRestaurants() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Get active and approved restaurants form the DB
      DatabaseEvent event = await _databaseRef
          .orderByChild('accountType')
          .equalTo('restaurant')
          .once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> usersMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> fetchedRestaurants = [];

        usersMap.forEach((key, value) {
          if (value['status'] == 'active' && value['isApproved'] == true) {
            String openingHours = 'Not available';
            String openDays = 'Not available';
            if (value['profile'] != null) {
              if (value['profile']['openHours'] != null) {
                openingHours = value['profile']['openHours'];
              }
              if (value['profile']['openDays'] != null) {
                openDays = value['profile']
                    ['openDays']; // Fixed: assign to openDays, not openingHours
              }
            }

            fetchedRestaurants.add({
              'uid': key,
              'name': value['name'] ?? 'Unknown Restaurant',
              'profileImageUrl': value['profileImageUrl'] ?? '',
              'openHours': openingHours,
              'openDays': openDays,
              'description': value['profile'] != null
                  ? value['profile']['description'] ??
                      'No description available'
                  : 'No description available',
              'cuisine': value['profile'] != null
                  ? value['profile']['typeofcuisine'] ?? 'Not specified'
                  : 'Not specified',
              'address': value['profile'] != null
                  ? value['profile']['address'] ?? 'Not available'
                  : 'Not available',
            });
          }
        });

        setState(() {
          restaurants = fetchedRestaurants;
          _isLoading = false;
        });
      } else {
        setState(() {
          restaurants = [];
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

  void navigateToRestaurantDetail(String restaurantId, String restaurantName) {
    // Todo: put the nav logic to the restaurant screen here
    //

    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected restaurant: $restaurantName')),
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: hangryYellow,
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Error loading restaurants',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(_errorMessage),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: fetchRestaurants,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hangryYellow,
                        ),
                        child: Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : restaurants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No restaurants available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Check back later!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        fetchRestaurants();
                      },
                      color: hangryYellow,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ListView.builder(
                          itemCount: restaurants.length,
                          itemBuilder: (context, index) {
                            return _buildRestaurantCard(restaurants[index]);
                          },
                        ),
                      ),
                    ),
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () =>
            navigateToRestaurantDetail(restaurant['uid'], restaurant['name']),
        borderRadius: BorderRadius.circular(12),
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
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            color: hangryYellow,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.restaurant,
                          size: 50,
                          color: hangryYellow,
                        ),
                      ),
                    )
                  : Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.restaurant,
                        size: 50,
                        color: hangryYellow,
                      ),
                    ),
            ),

            // Restaurant details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and cuisine type
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant['name'] ?? 'Unknown Restaurant',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: hangryBlue,
                            fontFamily: 'RammettoOne-Regular',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: hangryYellow.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          restaurant['cuisine'] ?? 'Various',
                          style: TextStyle(
                            color: hangryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // Description
                  // Text(
                  //   restaurant['description'] ?? 'No description available',
                  //   style: TextStyle(
                  //     fontSize: 14,
                  //     color: Colors.grey[600],
                  //   ),
                  //   maxLines: 2,
                  //   overflow: TextOverflow.ellipsis,
                  // ),
                  //
                  // SizedBox(height: 12),

                  // Opening days
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant['openDays'] ?? 'Days not available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Address and hours
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant['address'] ?? 'Address not available',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        restaurant['openHours'] ?? 'Hours not available',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // View menu button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => navigateToRestaurantDetail(
                          restaurant['uid'], restaurant['name']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hangryYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text('View Menu'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
