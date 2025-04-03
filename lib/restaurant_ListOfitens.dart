import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'restaurant_additens.dart';

class Restaurant_ListOfItems extends StatefulWidget {
  @override
  _Restaurant_ListOfItemsState createState() => _Restaurant_ListOfItemsState();
}

class _Restaurant_ListOfItemsState extends State<Restaurant_ListOfItems> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _databaseRef;
  String _selectedCategory = 'All';


  @override
  void initState() {
    super.initState();

    final String? userUid = _auth.currentUser?.uid;

    if (userUid == null) {
      throw Exception("User UID is null. User must be logged in.");
    }

    _databaseRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(userUid)
        .child('menu');
  }

  bool _isMenuItem(String key, dynamic value) {
    return key.startsWith('item') &&
        value is Map &&
        (value.containsKey('name') || value.containsKey('price'));
  }

  @override
  Widget build(BuildContext context) {
    final Color lightPink = Color(0xFFFAF5F9);
    final Color hangryYellow = Color(0xFFFCBF49);

    return Scaffold(
      backgroundColor: lightPink,
      appBar: AppBar(
        title: Text('My Menu',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: hangryYellow,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Category selector
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryButton('All'),
                  _buildCategoryButton('Appetizer'),
                  _buildCategoryButton('Main Dish'),
                  _buildCategoryButton('Dessert'),
                ],
              ),
            ),
          ),

          // Menu items list
          Expanded(
            child: StreamBuilder(
              stream: _databaseRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  Map<dynamic, dynamic> userData =
                  snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  List<Map<String, dynamic>> menuItems = [];

                  // Extract menu items from user data
                  userData.forEach((key, value) {
                    if (_isMenuItem(key, value)) {
                      menuItems.add({
                        'key': key,
                        'name': value['name'] ?? 'No Name',
                        'price': value['price'] ?? '0',
                        'description': value['description'] ?? 'No Description',
                        'imageUrl': value['imageUrl'] ?? '',
                        'category': value['category'] ?? 'Appetizer',
                        'availability': value['availability'] ?? 'Yes',
                      });
                    }
                  });

                  // Apply filters: category and availability
                  var filteredItems = menuItems;

                  // Filter by category if not 'All'
                  if (_selectedCategory != 'All') {
                    filteredItems = filteredItems
                        .where((item) => item['category'] == _selectedCategory)
                        .toList();
                  }


                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            _selectedCategory == 'All'
                                ? 'No items available'
                                : 'No ${_selectedCategory} items available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildMenuItemCard(filteredItems[index]);
                    },
                  );
                } else {
                  return Center(child: Text('No menu items found. Add some!'));
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Restaurant_addItems()),
          );
        },
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: hangryYellow,
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
          backgroundColor: isSelected ? Color(0xFF0A3A52) : Colors.white,
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
    final bool isAvailable = item['availability'] == 'Yes';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item details section with visual indication for unavailable items
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item['imageUrl'].isNotEmpty
                          ? Image.network(
                        item['imageUrl'],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[300],
                            child: Icon(Icons.error,
                                size: 40, color: Colors.red),
                          );
                        },
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: !isAvailable ? Colors.grey : null,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '\$${item['price'].toString()}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: !isAvailable ? Colors.grey : null,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            item['description'],
                            style: TextStyle(
                              fontSize: 14,
                              color: !isAvailable ? Colors.grey : Colors.grey[700],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
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
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: item['availability'] == 'Yes'
                                      ? Colors.green[100]
                                      : Colors.red[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item['availability'] == 'Yes'
                                      ? 'Available'
                                      : 'Not Available',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: item['availability'] == 'Yes'
                                        ? Colors.green[900]
                                        : Colors.red[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Visual overlay for unavailable items (without blocking interaction)
              if (!isAvailable)
                Positioned.fill(
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    // We don't put any interactive elements here, so clicks pass through
                  ),
                ),
            ],
          ),

          // Action buttons (outside the Stack to ensure they're always accessible)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit button
                TextButton.icon(
                  icon: Icon(Icons.edit, size: 20),
                  label: Text('Edit'),
                  onPressed: () {
                    _navigateToEditItemPage(item);
                  },
                ),
                // Delete button
                TextButton.icon(
                  icon: Icon(Icons.delete, size: 20, color: Colors.red),
                  label: Text('Delete', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    _showDeleteConfirmation(item);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${item['name']}?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                _deleteItem(item['key']);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteItem(String key) {
    _databaseRef.child(key).remove().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item deleted successfully!')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item: $error')),
      );
    });
  }

  void _navigateToEditItemPage(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Restaurant_addItems(item: item),
      ),
    ).then((_) {
      setState(() {});
    });
  }
}