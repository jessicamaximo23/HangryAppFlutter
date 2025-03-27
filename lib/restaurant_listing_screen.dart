import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'restaurant_menu_screen.dart';

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
  List<Map<String, dynamic>> filteredRestaurants = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Filter variables for restaurants
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCuisineFilter = 'All';
  String _selectedDishTypeFilter = 'All Dishes';

  Set<String> availableCuisines = {'All Cuisines'};
  final Set<String> availableDishTypes = {
    'All Dishes',
    'Appetizer',
    'Main Dish',
    'Dessert'
  };

  // Active filter
  String _activeFilterTab = 'Cuisine';

  @override
  void initState() {
    super.initState();
    fetchRestaurants();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilters();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void fetchRestaurants() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Get active and approved restaurants from the DB
      DatabaseEvent event = await _databaseRef
          .orderByChild('accountType')
          .equalTo('restaurant')
          .once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> usersMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> fetchedRestaurants = [];
        Set<String> cuisines = {'All Cuisines'};

        usersMap.forEach((key, value) {
          if (value['status'] == 'active' && value['isApproved'] == true) {
            String openingHours = 'Not available';
            String openDays = 'Not available';
            String cuisine = 'Not specified';

            if (value['profile'] != null) {
              if (value['profile']['openHours'] != null) {
                openingHours = value['profile']['openHours'];
              }
              if (value['profile']['openDays'] != null) {
                openDays = value['profile']
                    ['openDays']; // Fixed: assign to openDays, not openingHours
              }
              if (value['profile']['typeofcuisine'] != null) {
                cuisine = value['profile']['typeofcuisine'];
                cuisines.add(cuisine);
              }
            }

            List<String> dishTypes = [];
            if (value['menu'] != null) {
              try {
                Map<dynamic, dynamic> menu =
                    value['menu'] as Map<dynamic, dynamic>;
                menu.forEach((menuKey, menuItem) {
                  if (menuItem is Map && menuItem.containsKey('category')) {
                    String category = menuItem['category'] as String;
                    if (category.isNotEmpty && !dishTypes.contains(category)) {
                      dishTypes.add(category);
                    }
                  }
                });
              } catch (e) {
                print('Error parsing menu: $e');
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
              'dishTypes': dishTypes,
            });
          }
        });

        setState(() {
          restaurants = fetchedRestaurants;
          availableCuisines = cuisines;
          _applyFilters();
          _isLoading = false;
        });
      } else {
        setState(() {
          restaurants = [];
          filteredRestaurants = [];
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

  // method for filtering restaurants
  void _applyFilters() {
    setState(() {
      filteredRestaurants = restaurants.where((restaurant) {
        // Apply search filter
        final nameMatches = restaurant['name']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());

        // Apply cuisine filter if not "All Cuisines"
        final cuisineMatches = _selectedCuisineFilter == 'All Cuisines' ||
            restaurant['cuisine'].toString() == _selectedCuisineFilter;

        // Apply dish type filter if not "All Dishes"
        bool dishTypeMatches = true;
        if (_selectedDishTypeFilter != 'All Dishes') {
          // If restaurant has dish types, check if the selected one exists
          if (restaurant.containsKey('dishTypes') &&
              restaurant['dishTypes'] is List) {
            List<String> dishTypes = restaurant['dishTypes'] as List<String>;
            dishTypeMatches = dishTypes.contains(_selectedDishTypeFilter);
          } else {
            // If no dish types defined, it doesn't match specific dish type filters
            dishTypeMatches = false;
          }
        }

        return nameMatches && cuisineMatches && dishTypeMatches;
      }).toList();
    });
  }

  // Method to update the cuisine filter
  void _updateCuisineFilter(String cuisine) {
    setState(() {
      _selectedCuisineFilter = cuisine;
      _applyFilters();
    });
  }

  // Method to update the dish type filter
  void _updateDishTypeFilter(String dishType) {
    setState(() {
      _selectedDishTypeFilter = dishType;
      _applyFilters();
    });
  }

  // Method to switch active filter tab
  void _switchFilterTab(String tabName) {
    setState(() {
      _activeFilterTab = tabName;
    });
  }

  void navigateToRestaurantDetail(String restaurantId, String restaurantName) {
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

  // For now, just show a message
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(content: Text('Selected restaurant: $restaurantName')),
  //   );
  // }

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
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search restaurants...',
                prefixIcon: Icon(Icons.search, color: hangryBlue),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Filter tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterTab('Cuisine', 'Cuisine'),
                SizedBox(width: 16),
                _buildFilterTab('Dish Type', 'Dish Type'),
              ],
            ),
          ),

          // Dynamic filter chips based on active tab
          Container(
            height: 50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _activeFilterTab == 'Cuisine'
                  ? Row(
                      children: availableCuisines.map((cuisine) {
                        final isSelected = _selectedCuisineFilter == cuisine;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(cuisine),
                            selected: isSelected,
                            onSelected: (selected) {
                              _updateCuisineFilter(cuisine);
                            },
                            selectedColor: hangryYellow,
                            checkmarkColor: hangryBlue,
                            backgroundColor: Colors.grey[200],
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected
                                    ? hangryYellow
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  : Row(
                      children: availableDishTypes.map((dishType) {
                        final isSelected = _selectedDishTypeFilter == dishType;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(dishType),
                            selected: isSelected,
                            onSelected: (selected) {
                              _updateDishTypeFilter(dishType);
                            },
                            selectedColor: hangryYellow,
                            checkmarkColor: hangryBlue,
                            backgroundColor: Colors.grey[200],
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected
                                    ? hangryYellow
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),

          // Active filters display
          if (_selectedCuisineFilter != 'All Cuisines' ||
              _selectedDishTypeFilter != 'All Dishes')
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Filters:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_selectedCuisineFilter != 'All Cuisines')
                        _buildActiveFilterChip(_selectedCuisineFilter, () {
                          _updateCuisineFilter('All Cuisines');
                        }),
                      if (_selectedDishTypeFilter != 'All Dishes')
                        _buildActiveFilterChip(_selectedDishTypeFilter, () {
                          _updateDishTypeFilter('All Dishes');
                        }),
                      if (_selectedCuisineFilter != 'All Cuisines' ||
                          _selectedDishTypeFilter != 'All Dishes')
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedCuisineFilter = 'All Cuisines';
                              _selectedDishTypeFilter = 'All Dishes';
                              _applyFilters();
                            });
                          },
                          icon: Icon(Icons.clear_all, size: 16),
                          label:
                              Text('Clear All', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: hangryBlue,
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            minimumSize: Size(80, 30),
                            side:
                                BorderSide(color: hangryBlue.withOpacity(0.5)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Restaurants list or loading/error states
          Expanded(
            child: _isLoading
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
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
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
                    : filteredRestaurants.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.restaurant_menu,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty &&
                                          _selectedCuisineFilter ==
                                              'All Cuisines' &&
                                          _selectedDishTypeFilter ==
                                              'All Dishes'
                                      ? 'No restaurants available'
                                      : 'No restaurants match your filters',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _searchQuery.isEmpty &&
                                          _selectedCuisineFilter ==
                                              'All Cuisines' &&
                                          _selectedDishTypeFilter ==
                                              'All Dishes'
                                      ? 'Check back later!'
                                      : 'Try adjusting your filters',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                if (_searchQuery.isNotEmpty ||
                                    _selectedCuisineFilter != 'All Cuisines' ||
                                    _selectedDishTypeFilter != 'All Dishes')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _selectedCuisineFilter =
                                              'All Cuisines';
                                          _selectedDishTypeFilter =
                                              'All Dishes';
                                          _applyFilters();
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hangryYellow,
                                      ),
                                      child: Text('Clear Filters'),
                                    ),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: ListView.builder(
                                itemCount: filteredRestaurants.length,
                                itemBuilder: (context, index) {
                                  return _buildRestaurantCard(
                                      filteredRestaurants[index]);
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // Build filter tab button
  Widget _buildFilterTab(String tabName, String displayName) {
    final isActive = _activeFilterTab == tabName;

    return Expanded(
      child: InkWell(
        onTap: () => _switchFilterTab(tabName),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? hangryYellow : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? hangryYellow : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // Build active filter chip display
  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        backgroundColor: hangryYellow.withOpacity(0.2),
        deleteIcon: Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        deleteIconColor: hangryBlue,
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

                  // Dish Types (if available)
                  if (restaurant['dishTypes'] != null &&
                      (restaurant['dishTypes'] as List).isNotEmpty)
                    Container(
                      height: 25,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: (restaurant['dishTypes'] as List)
                            .map<Widget>((dishType) {
                          return Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: hangryBlue.withOpacity(0.2)),
                            ),
                            child: Text(
                              dishType,
                              style: TextStyle(
                                fontSize: 10,
                                color: hangryBlue,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  SizedBox(height: 8),

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
