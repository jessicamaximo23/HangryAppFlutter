import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const RestaurantMenuScreen({
    Key? key,
    required this.restaurantId,
    required this.restaurantName,
  }) : super(key: key);

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  late DatabaseReference _databaseRef;
  List<Map<String, dynamic>> menuItems = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _databaseRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(widget.restaurantId)
        .child('menu');

    _fetchMenuItems();
  }

  void _fetchMenuItems() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      DatabaseEvent event = await _databaseRef.once();

      if (event.snapshot.exists) {
        Map<dynamic, dynamic> menuData =
            event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> items = [];

        menuData.forEach((key, value) {
          if (key.toString().startsWith('item') && value is Map) {
            items.add({
              'key': key,
              'name': value['name'] ?? 'No Name',
              'price': value['price'] ?? 0.0,
              'description': value['description'] ?? 'No Description',
              'imageUrl': value['imageUrl'] ?? '',
              'category': value['category'] ?? 'Appetizer',
              'availability': value['availability'] ?? 'Yes',
            });
          }
        });

        setState(() {
          menuItems = items;
          _isLoading = false;
        });
      } else {
        setState(() {
          menuItems = [];
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Error loading menu: $error';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> getFilteredItems() {
    if (_selectedCategory == 'All') {
      return menuItems.where((item) => item['availability'] == 'Yes').toList();
    } else {
      return menuItems
          .where((item) =>
              item['category'] == _selectedCategory &&
              item['availability'] == 'Yes')
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredItems = getFilteredItems();

    // Get unique categories from menu items
    Set<String> categories = {'All'};
    for (var item in menuItems) {
      if (item['category'] != null && item['category'].toString().isNotEmpty) {
        categories.add(item['category'].toString());
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName),
        backgroundColor: hangryYellow,
      ),
      body: Column(
        children: [
          // Categories filter
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories
                    .map((category) => _buildCategoryButton(category))
                    .toList(),
              ),
            ),
          ),

          // Menu items list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: hangryYellow))
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            SizedBox(height: 16),
                            Text(
                              'Error loading menu',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(_errorMessage),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _fetchMenuItems,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hangryYellow,
                              ),
                              child: Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : filteredItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.restaurant_menu,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  _selectedCategory == 'All'
                                      ? 'No menu items available'
                                      : 'No $_selectedCategory items available',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Try selecting a different category',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              return _buildMenuItemCard(filteredItems[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String category) {
    final bool isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedCategory = category;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? hangryBlue : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          elevation: isSelected ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(category),
      ),
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> item) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item['imageUrl'] != null &&
                      item['imageUrl'].toString().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item['imageUrl'],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: Center(
                            child:
                                CircularProgressIndicator(color: hangryYellow)),
                      ),
                      errorWidget: (context, error, stackTrace) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[300],
                        child: Icon(Icons.error, size: 40, color: Colors.red),
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[300],
                      child: Icon(Icons.fastfood,
                          size: 40, color: Colors.grey[600]),
                    ),
            ),
            SizedBox(width: 16),

            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: hangryBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '\$${item['price'] is double ? item['price'].toStringAsFixed(2) : item['price'].toString()}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: hangryYellow,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    item['description'],
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item['category'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Add to cart functionality would go here
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('${item['name']} added to cart')),
                        );
                      },
                      icon: Icon(Icons.add_shopping_cart, size: 16),
                      label: Text('Add to Cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hangryYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
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
