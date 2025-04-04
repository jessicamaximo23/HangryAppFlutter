import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'cart_screen.dart';

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
  late DatabaseReference _restaurantInfoRef;
  List<Map<String, dynamic>> menuItems = [];
  Map<String, dynamic>? restaurantData;
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedCategory = 'All';

  // Cart state
  Map<String, CartItem> _cartItems = {};
  int _cartItemCount = 0;
  double _cartTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _databaseRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(widget.restaurantId)
        .child('menu');

    _restaurantInfoRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(widget.restaurantId);

    _fetchRestaurantData();
    _fetchMenuItems();
  }

  void _fetchRestaurantData() async {
    try {
      DatabaseEvent event = await _restaurantInfoRef.once();

      if (event.snapshot.exists) {
        Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;

        Map<String, dynamic> formattedData = {
          'uid': widget.restaurantId,
          'name': data['name'] ?? widget.restaurantName,
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'email': data['email'] ?? '',
          'status': data['status'] ?? 'inactive',
        };

        if (data.containsKey('profile') && data['profile'] is Map) {
          Map<dynamic, dynamic> profile =
              data['profile'] as Map<dynamic, dynamic>;
          formattedData['description'] =
              profile['description'] ?? 'No description available';
          formattedData['cuisine'] =
              profile['typeofcuisine'] ?? 'Various cuisine';
          formattedData['address'] = profile['address'] ?? '';
          formattedData['city'] = profile['city'] ?? '';
          formattedData['openHours'] =
              profile['openHours'] ?? 'Hours not available';
          formattedData['openDays'] =
              profile['openDays'] ?? 'Days not available';
        }

        setState(() {
          restaurantData = formattedData;
        });
      }
    } catch (error) {
      print('Error loading restaurant data: $error');
    }
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
              'price': _parsePrice(value['price']),
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

  double _parsePrice(dynamic price) {
    if (price is double) return price;
    if (price is int) return price.toDouble();
    if (price is String) {
      try {
        return double.parse(price);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
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

  void _addToCart(Map<String, dynamic> menuItem) {
    setState(() {
      String itemId = menuItem['key'];

      if (_cartItems.containsKey(itemId)) {
        // Item already in cart, increase quantity
        _cartItems[itemId]!.quantity += 1;
      } else {
        // Add new item to cart
        _cartItems[itemId] = CartItem(
          id: itemId,
          name: menuItem['name'],
          price: menuItem['price'],
          imageUrl: menuItem['imageUrl'],
          description: menuItem['description'],
          quantity: 1,
        );
      }

      // Update cart totals
      _updateCartTotals();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${menuItem['name']} added to cart'),
          duration: Duration(seconds: 1),
          action: SnackBarAction(
            label: 'View Cart',
            onPressed: () {
              _navigateToCart();
            },
          ),
        ),
      );
    });
  }

  void _updateCartTotals() {
    int itemCount = 0;
    double total = 0.0;

    _cartItems.forEach((key, item) {
      itemCount += item.quantity;
      total += item.price * item.quantity;
    });

    setState(() {
      _cartItemCount = itemCount;
      _cartTotal = total;
    });
  }

  void _navigateToCart() {
    if (restaurantData == null) {
      // Ensure we have restaurant data
      restaurantData = {
        'uid': widget.restaurantId,
        'name': widget.restaurantName,
      };
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          cartItems: _cartItems,
          restaurantData: restaurantData!,
          onCartUpdate: (updatedCart) {
            setState(() {
              _cartItems = updatedCart;
              _updateCartTotals();
            });
          },
        ),
      ),
    );
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
        title: Text(
          widget.restaurantName,
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
        backgroundColor: hangryYellow,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.shopping_cart),
                onPressed: _cartItemCount > 0 ? _navigateToCart : null,
              ),
              if (_cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _cartItemCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
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
      bottomNavigationBar: _cartItemCount > 0 ? _buildCartSummary() : null,
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
      child: InkWell(
        onTap: () {
          _showItemDetailDialog(item);
        },
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
                              child: CircularProgressIndicator(
                                  color: hangryYellow)),
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
                          '\$${item['price'].toStringAsFixed(2)}',
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
                          _addToCart(item);
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
      ),
    );
  }

  void _showItemDetailDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item['imageUrl'] != null && item['imageUrl'].isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item['imageUrl'],
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 180,
                            color: Colors.grey[300],
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: hangryYellow)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 180,
                            color: Colors.grey[300],
                            child: Icon(Icons.fastfood,
                                size: 40, color: hangryYellow),
                          ),
                        )
                      : Container(
                          height: 180,
                          color: Colors.grey[300],
                          child: Icon(Icons.fastfood,
                              size: 40, color: hangryYellow),
                        ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['name'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: hangryBlue,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hangryYellow.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '\$${item['price'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: hangryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item['category'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hangryBlue,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  item['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: hangryBlue,
                        side: BorderSide(color: hangryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text('Close'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _addToCart(item);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hangryYellow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: Icon(Icons.add_shopping_cart),
                      label: Text('Add to Cart'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartSummary() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_cartItemCount ${_cartItemCount == 1 ? 'item' : 'items'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '\$${_cartTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: hangryBlue,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _navigateToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: hangryYellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_cart),
                SizedBox(width: 8),
                Text(
                  'View Cart',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  int quantity;
  String? comment;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.description,
    this.quantity = 1,
    this.comment,
  });
}
