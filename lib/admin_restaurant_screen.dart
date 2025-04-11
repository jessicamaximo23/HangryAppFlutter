import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AdminRestaurantScreen extends StatefulWidget {
  @override
  _AdminRestaurantScreenState createState() => _AdminRestaurantScreenState();
}

// Define custom colors
final Color hangryYellow = Color(0xFFFCBF49);
final Color hangryBlue = Color(0xFF003049);

class _AdminRestaurantScreenState extends State<AdminRestaurantScreen> {
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
      });

      DatabaseEvent event = await _databaseRef
          .orderByChild('accountType')
          .equalTo('restaurant')
          .once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> usersMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> fetchedRestaurants = [];

        usersMap.forEach((key, value) {
          fetchedRestaurants.add({
            'uid': key,
            'name': value['name'] ?? 'Unknown Restaurant',
            'email': value['email'] ?? '',
            'isActive': value['status'] == 'active',
            'profileImageUrl': value['profileImageUrl'] ?? '',
            'isApproved': value['isApproved'] ?? false,
          });
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

  // Adding the toggle method
  void toggleRestaurantsStatus(int index) async {
    final String uid = restaurants[index]['uid'];
    final bool newStatus = !restaurants[index]['isActive'];

    try {
      await _databaseRef.child(uid).update({
        'status': newStatus ? 'active' : 'inactive',
      });

      setState(() {
        restaurants[index]['isActive'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restaurant status updated successfully')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update restaurant status: $error')),
      );
    }
  }

  void toggleApprovalStatus(int index) async {
    final String uid = restaurants[index]['uid'];
    final bool newStatus = !restaurants[index]['isApproved'];

    try {
      await _databaseRef.child(uid).update({
        'isApproved': newStatus,
      });

      setState(() {
        restaurants[index]['isApproved'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Restaurant approval status updated successfully!')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update approval status: $error')),
      );
    }
  }

  void navigateToRestaurantDetails(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailScreen(
          restaurantUid: restaurants[index]['uid'],
          restaurantName: restaurants[index]['name'],
          onSave: (details) {
            print('Details saved: $details');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Restaurant',
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
        backgroundColor: hangryYellow,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Restaurant List',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: hangryBlue,
                fontFamily: 'RammettoOne-Regular',
              ),
            ),
          ),
          if (_isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: hangryYellow,
                ),
              ),
            )
          else if (_errorMessage.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Error: $_errorMessage',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            )
          else if (restaurants.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No restaurants found',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  fetchRestaurants();
                },
                color: hangryYellow,
                child: ListView.builder(
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12),
                        leading: restaurants[index]['profileImageUrl']
                                .isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: CachedNetworkImage(
                                  imageUrl: restaurants[index]
                                      ['profileImageUrl'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      CircularProgressIndicator(
                                    color: hangryYellow,
                                    strokeWidth: 2,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      CircleAvatar(
                                    backgroundColor:
                                        hangryYellow.withOpacity(0.2),
                                    child: Icon(Icons.restaurant,
                                        color: hangryYellow),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: hangryYellow.withOpacity(0.2),
                                radius: 25,
                                child:
                                    Icon(Icons.restaurant, color: hangryYellow),
                              ),
                        title: Text(
                          restaurants[index]['name'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'RammettoOne-Regular',
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(restaurants[index]['email']),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: restaurants[index]['isActive']
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    restaurants[index]['isActive']
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      color: restaurants[index]['isActive']
                                          ? Colors.green[800]
                                          : Colors.red[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: restaurants[index]['isApproved']
                                        ? Colors.blue.withOpacity(0.2)
                                        : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    restaurants[index]['isApproved']
                                        ? 'Approved'
                                        : 'Pending',
                                    style: TextStyle(
                                      color: restaurants[index]['isApproved']
                                          ? Colors.blue[800]
                                          : Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status toggle
                            Switch(
                              value: restaurants[index]['isActive'],
                              onChanged: (value) {
                                toggleRestaurantsStatus(index);
                              },
                              activeColor: hangryYellow,
                              activeTrackColor: hangryYellow.withOpacity(0.5),
                            ),
                            // Approval toggle
                            IconButton(
                              icon: Icon(
                                restaurants[index]['isApproved']
                                    ? Icons.verified_user
                                    : Icons.pending,
                                color: restaurants[index]['isApproved']
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                              onPressed: () {
                                toggleApprovalStatus(index);
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          navigateToRestaurantDetails(index);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantUid;
  final String restaurantName;
  final Function(Map<String, dynamic>) onSave;

  RestaurantDetailScreen({
    required this.restaurantUid,
    required this.restaurantName,
    required this.onSave,
  });

  @override
  _RestaurantDetailScreenState createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _restaurantData;
  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  // Form controllers for editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final TextEditingController _cuisineController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
  }

  void _loadRestaurantData() async {
    try {
      final userSnapshot =
          await _databaseRef.child('users/${widget.restaurantUid}').get();

      if (userSnapshot.exists) {
        Map<dynamic, dynamic> userData =
            userSnapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> formattedData = {};

        // Format basic restaurant data
        formattedData['name'] = userData['name'] ?? 'Unknown';
        formattedData['email'] = userData['email'] ?? '';
        formattedData['status'] = userData['status'] ?? 'inactive';
        formattedData['isApproved'] = userData['isApproved'] ?? false;
        formattedData['profileImageUrl'] = userData['profileImageUrl'] ?? '';

        // Get profile data if it exists
        if (userData.containsKey('profile') && userData['profile'] is Map) {
          Map<dynamic, dynamic> profileData =
              userData['profile'] as Map<dynamic, dynamic>;
          formattedData['profile'] = Map<String, dynamic>.from(profileData);

          // Set up controllers for editing
          _nameController.text =
              profileData['fullName'] ?? formattedData['name'];
          _phoneController.text = profileData['phoneNumber'] ?? '';
          _addressController.text = profileData['address'] ?? '';
          _cityController.text = profileData['city'] ?? '';
          _zipCodeController.text = profileData['zipCode'] ?? '';
          _cuisineController.text = profileData['cuisine'] ?? '';
          _descriptionController.text = profileData['description'] ?? '';
        }

        // Load menu items
        List<Map<String, dynamic>> menuItems = [];
        if (userData.containsKey('menu_counter')) {
          int menuCounter = userData['menu_counter'] as int? ?? 0;

          for (int i = 1; i <= menuCounter; i++) {
            String itemKey = 'item$i';
            if (userData.containsKey(itemKey) && userData[itemKey] is Map) {
              Map<dynamic, dynamic> itemData =
                  userData[itemKey] as Map<dynamic, dynamic>;
              menuItems.add({
                'key': itemKey,
                'name': itemData['name'] ?? 'Unknown Item',
                'price': itemData['price'] ?? 0,
                'description': itemData['description'] ?? '',
                'imageUrl': itemData['imageUrl'] ?? '',
                'category': itemData['category'] ?? 'Other',
                'availability': itemData['availability'] ?? 'No',
              });
            }
          }
        }

        setState(() {
          _restaurantData = formattedData;
          _menuItems = menuItems;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Restaurant data not found');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading restaurant data: $error');
    }
  }

  void _toggleRestaurantStatus() async {
    if (_restaurantData == null) return;

    bool currentStatus = _restaurantData!['status'] == 'active';
    String newStatus = currentStatus ? 'inactive' : 'active';

    try {
      await _databaseRef.child('users/${widget.restaurantUid}').update({
        'status': newStatus,
      });

      setState(() {
        _restaurantData!['status'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Restaurant status updated to ${newStatus.toUpperCase()}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update restaurant status: $error')),
      );
    }
  }

  void _toggleApprovalStatus() async {
    if (_restaurantData == null) return;

    bool currentStatus = _restaurantData!['isApproved'] == true;
    bool newStatus = !currentStatus;

    try {
      await _databaseRef.child('users/${widget.restaurantUid}').update({
        'isApproved': newStatus,
      });

      setState(() {
        _restaurantData!['isApproved'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Restaurant ${newStatus ? 'approved' : 'approval revoked'}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update approval status: $error')),
      );
    }
  }

  void _saveRestaurantInfo() async {
    try {
      // Update profile data
      await _databaseRef.child('users/${widget.restaurantUid}/profile').update({
        'fullName': _nameController.text,
        'phoneNumber': _phoneController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'zipCode': _zipCodeController.text,
        'cuisine': _cuisineController.text,
        'description': _descriptionController.text,
      });

      // Also update the name at root level
      await _databaseRef.child('users/${widget.restaurantUid}').update({
        'name': _nameController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restaurant information updated successfully')),
      );

      // Reload data and exit edit mode
      setState(() {
        _isEditing = false;
      });
      _loadRestaurantData();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update restaurant information: $error')),
      );
    }
  }

  Widget _buildScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildProfileInfoScreen();
      case 1:
        return _buildMenuScreen();
      case 2:
        return _buildOrdersAndEarningsScreen();
      case 3:
        return _buildReviewsScreen();
      default:
        return Center(child: Text(''));
    }
  }

  Widget _buildProfileInfoScreen() {
    if (_restaurantData == null) {
      return Center(child: Text('No restaurant data available'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant profile section
          Center(
            child: Column(
              children: [
                _restaurantData!['profileImageUrl'].isNotEmpty
                    ? CircleAvatar(
                        radius: 60,
                        backgroundImage:
                            NetworkImage(_restaurantData!['profileImageUrl']),
                      )
                    : CircleAvatar(
                        radius: 60,
                        backgroundColor: hangryYellow.withOpacity(0.2),
                        child: Icon(Icons.restaurant,
                            size: 60, color: hangryYellow),
                      ),
                SizedBox(height: 16),
                Text(
                  _restaurantData!['name'],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: hangryBlue,
                    fontFamily: 'RammettoOne-Regular',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _restaurantData!['email'],
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _restaurantData!['status'] == 'active'
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _restaurantData!['status'] == 'active'
                            ? 'Active'
                            : 'Inactive',
                        style: TextStyle(
                          color: _restaurantData!['status'] == 'active'
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _restaurantData!['isApproved'] == true
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _restaurantData!['isApproved'] == true
                            ? 'Approved'
                            : 'Pending Approval',
                        style: TextStyle(
                          color: _restaurantData!['isApproved'] == true
                              ? Colors.blue[800]
                              : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 32),

          // Admin actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: Icon(_restaurantData!['status'] == 'active'
                    ? Icons.block
                    : Icons.check_circle),
                label: Text(_restaurantData!['status'] == 'active'
                    ? 'Deactivate'
                    : 'Activate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _restaurantData!['status'] == 'active'
                      ? Colors.red
                      : Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _toggleRestaurantStatus,
              ),
              ElevatedButton.icon(
                icon: Icon(_restaurantData!['isApproved'] == true
                    ? Icons.cancel
                    : Icons.verified_user),
                label: Text(_restaurantData!['isApproved'] == true
                    ? 'Revoke Approval'
                    : 'Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _restaurantData!['isApproved'] == true
                      ? Colors.orange
                      : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _toggleApprovalStatus,
              ),
            ],
          ),

          Divider(height: 32),

          // Restaurant details section - Editable
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Restaurant Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: hangryBlue,
                ),
              ),
              TextButton.icon(
                icon: Icon(_isEditing ? Icons.save : Icons.edit),
                label: Text(_isEditing ? 'Save' : 'Edit'),
                onPressed: () {
                  if (_isEditing) {
                    _saveRestaurantInfo();
                  } else {
                    setState(() {
                      _isEditing = true;
                    });
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 16),

          if (_isEditing) ...[
            // Editable fields
            _buildEditTextField('Restaurant Name', _nameController),
            _buildEditTextField('Phone Number', _phoneController),
            _buildEditTextField('Address', _addressController),
            _buildEditTextField('City', _cityController),
            _buildEditTextField('Zip Code', _zipCodeController),
            _buildEditTextField('Cuisine Type', _cuisineController),
            _buildEditTextField('Description', _descriptionController,
                maxLines: 3),
          ] else if (_restaurantData!.containsKey('profile')) ...[
            // Read-only profile data
            _buildDetailItem(
                'Restaurant Name',
                _restaurantData!['profile']['fullName'] ??
                    _restaurantData!['name']),
            _buildDetailItem('Phone Number',
                _restaurantData!['profile']['phoneNumber'] ?? 'Not provided'),
            _buildDetailItem('Address',
                _restaurantData!['profile']['address'] ?? 'Not provided'),
            _buildDetailItem(
                'City', _restaurantData!['profile']['city'] ?? 'Not provided'),
            _buildDetailItem('Zip Code',
                _restaurantData!['profile']['zipCode'] ?? 'Not provided'),
            _buildDetailItem('Cuisine Type',
                _restaurantData!['profile']['cuisine'] ?? 'Not provided'),
            _buildDetailItem('Description',
                _restaurantData!['profile']['description'] ?? 'Not provided'),
          ],
        ],
      ),
    );
  }

  Widget _buildEditTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuScreen() {
    if (_menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Menu Items Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This restaurant has not added any menu items yet',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item['imageUrl'] != null && item['imageUrl'].isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item['imageUrl'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: hangryYellow,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: Icon(Icons.fastfood, color: hangryYellow),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: Icon(Icons.fastfood, color: hangryYellow),
                        ),
                ),
                SizedBox(width: 12),
                // Item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        item['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${item['price']}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: hangryBlue,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item['availability'] == 'Yes'
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item['availability'] == 'Yes'
                                  ? 'Available'
                                  : 'Unavailable',
                              style: TextStyle(
                                color: item['availability'] == 'Yes'
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
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
        );
      },
    );
  }

  Widget _buildOrdersAndEarningsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Orders Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This restaurant has not received any orders yet',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Reviews Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This restaurant has not received any reviews yet',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: hangryYellow))
          : _buildScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: hangryYellow,
        selectedItemColor: hangryBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Reviews',
          ),
        ],
      ),
    );
  }
}
