import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AdminUserScreen extends StatefulWidget {
  @override
  _AdminUserScreenState createState() => _AdminUserScreenState();
}

// Define custom colors
final Color hangryYellow = Color(0xFFFCBF49);
final Color hangryBlue = Color(0xFF003049);

class _AdminUserScreenState extends State<AdminUserScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('users');
  List<Map<String, dynamic>> users = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  void fetchUsers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      DatabaseEvent event =
          await _databaseRef.orderByChild('accountType').equalTo('user').once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> usersMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> fetchedUsers = [];

        usersMap.forEach((key, value) {
          fetchedUsers.add({
            'uid': key,
            'name': value['name'] ?? 'Unknown User',
            'email': value['email'] ?? '',
            'isActive': value['status'] == 'active',
            'profileImageUrl': value['profileImageUrl'] ?? '',
            'isApproved': value['isApproved'] ??
                true, // Users are typically approved by default
          });
        });
        setState(() {
          users = fetchedUsers;
          _isLoading = false;
        });
      } else {
        setState(() {
          users = [];
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

  void toggleUserStatus(int index) async {
    final String uid = users[index]['uid'];
    final bool newStatus = !users[index]['isActive'];

    try {
      await _databaseRef.child(uid).update({
        'status': newStatus ? 'active' : 'inactive',
      });

      setState(() {
        users[index]['isActive'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User status updated successfully')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user status: $error')),
      );
    }
  }

  void navigateToUserDetails(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailScreen(
          userUid: users[index]['uid'],
          userName: users[index]['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin User',
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
              'User List',
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
          else if (users.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No users found',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  fetchUsers();
                },
                color: hangryYellow,
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12),
                        leading: users[index]['profileImageUrl'].isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: CachedNetworkImage(
                                  imageUrl: users[index]['profileImageUrl'],
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
                                    child:
                                        Icon(Icons.person, color: hangryYellow),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: hangryYellow.withOpacity(0.2),
                                radius: 25,
                                child: Icon(Icons.person, color: hangryYellow),
                              ),
                        title: Text(
                          users[index]['name'],
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
                            Text(users[index]['email']),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: users[index]['isActive']
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                users[index]['isActive']
                                    ? 'Active'
                                    : 'Inactive',
                                style: TextStyle(
                                  color: users[index]['isActive']
                                      ? Colors.green[800]
                                      : Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Switch(
                          value: users[index]['isActive'],
                          onChanged: (value) {
                            toggleUserStatus(index);
                          },
                          activeColor: hangryYellow,
                          activeTrackColor: hangryYellow.withOpacity(0.5),
                        ),
                        onTap: () {
                          navigateToUserDetails(index);
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

class UserDetailScreen extends StatefulWidget {
  final String userUid;
  final String userName;

  UserDetailScreen({
    required this.userUid,
    required this.userName,
  });

  @override
  _UserDetailScreenState createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _selectedIndex = 0;

  // Form controllers for editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    try {
      final userSnapshot =
          await _databaseRef.child('users/${widget.userUid}').get();

      if (userSnapshot.exists) {
        Map<dynamic, dynamic> userData =
            userSnapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> formattedData = {};

        // Format basic user data
        formattedData['name'] = userData['name'] ?? 'Unknown';
        formattedData['email'] = userData['email'] ?? '';
        formattedData['status'] = userData['status'] ?? 'inactive';
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
        }

        // Get orders if they exist
        List<Map<String, dynamic>> orders = [];
        if (userData.containsKey('orders') && userData['orders'] is Map) {
          Map<dynamic, dynamic> ordersData =
              userData['orders'] as Map<dynamic, dynamic>;
          ordersData.forEach((key, value) {
            if (value is Map) {
              orders.add({
                'id': key,
                'restaurant': value['restaurant'] ?? 'Unknown',
                'items': value['items'] ?? [],
                'total': value['total'] ?? 0,
                'status': value['status'] ?? 'pending',
                'date': value['date'] ?? '',
              });
            }
          });
        }
        formattedData['orders'] = orders;

        setState(() {
          _userData = formattedData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        print('User data not found');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading user data: $error');
    }
  }

  void _toggleUserStatus() async {
    if (_userData == null) return;

    bool currentStatus = _userData!['status'] == 'active';
    String newStatus = currentStatus ? 'inactive' : 'active';

    try {
      await _databaseRef.child('users/${widget.userUid}').update({
        'status': newStatus,
      });

      setState(() {
        _userData!['status'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('User status updated to ${newStatus.toUpperCase()}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user status: $error')),
      );
    }
  }

  void _saveUserInfo() async {
    try {
      // Update profile data
      await _databaseRef.child('users/${widget.userUid}/profile').update({
        'fullName': _nameController.text,
        'phoneNumber': _phoneController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'zipCode': _zipCodeController.text,
      });

      // Also update the name at root level
      await _databaseRef.child('users/${widget.userUid}').update({
        'name': _nameController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User information updated successfully')),
      );

      // Reload data and exit edit mode
      setState(() {
        _isEditing = false;
      });
      _loadUserData();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user information: $error')),
      );
    }
  }

  Widget _buildScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildProfileInfoScreen();
      case 1:
        return _buildOrdersScreen();
      case 2:
        return _buildPaymentMethodsScreen();
      default:
        return Center(child: Text(''));
    }
  }

  Widget _buildProfileInfoScreen() {
    if (_userData == null) {
      return Center(child: Text('No user data available'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User profile section
          Center(
            child: Column(
              children: [
                _userData!['profileImageUrl'].isNotEmpty
                    ? CircleAvatar(
                        radius: 60,
                        backgroundImage:
                            NetworkImage(_userData!['profileImageUrl']),
                      )
                    : CircleAvatar(
                        radius: 60,
                        backgroundColor: hangryYellow.withOpacity(0.2),
                        child:
                            Icon(Icons.person, size: 60, color: hangryYellow),
                      ),
                SizedBox(height: 16),
                Text(
                  _userData!['name'],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: hangryBlue,
                    fontFamily: 'RammettoOne-Regular',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _userData!['email'],
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _userData!['status'] == 'active'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _userData!['status'] == 'active' ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: _userData!['status'] == 'active'
                          ? Colors.green[800]
                          : Colors.red[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 32),

          // Admin actions
          Center(
            child: ElevatedButton.icon(
              icon: Icon(_userData!['status'] == 'active'
                  ? Icons.block
                  : Icons.check_circle),
              label: Text(
                  _userData!['status'] == 'active' ? 'Deactivate' : 'Activate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _userData!['status'] == 'active'
                    ? Colors.red
                    : Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _toggleUserStatus,
            ),
          ),

          Divider(height: 32),

          // User details section - Editable
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'User Details',
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
                    _saveUserInfo();
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
            _buildEditTextField('Full Name', _nameController),
            _buildEditTextField('Phone Number', _phoneController),
            _buildEditTextField('Address', _addressController),
            _buildEditTextField('City', _cityController),
            _buildEditTextField('Zip Code', _zipCodeController),
          ] else if (_userData!.containsKey('profile')) ...[
            // Read-only profile data
            _buildDetailItem('Full Name',
                _userData!['profile']['fullName'] ?? 'Not provided'),
            _buildDetailItem('Phone Number',
                _userData!['profile']['phoneNumber'] ?? 'Not provided'),
            _buildDetailItem(
                'Address', _userData!['profile']['address'] ?? 'Not provided'),
            _buildDetailItem(
                'City', _userData!['profile']['city'] ?? 'Not provided'),
            _buildDetailItem(
                'Zip Code', _userData!['profile']['zipCode'] ?? 'Not provided'),
          ],
        ],
      ),
    );
  }

  Widget _buildEditTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
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

  Widget _buildOrdersScreen() {
    if (_userData == null ||
        !_userData!.containsKey('orders') ||
        (_userData!['orders'] as List).isEmpty) {
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
              'This user has not placed any orders yet',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    List<Map<String, dynamic>> orders =
        _userData!['orders'] as List<Map<String, dynamic>>;

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${orders[index]['id']}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getOrderStatusColor(orders[index]['status'])
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        orders[index]['status'],
                        style: TextStyle(
                          color: _getOrderStatusColor(orders[index]['status']),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Restaurant: ${orders[index]['restaurant']}',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Total: \$${orders[index]['total']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Date: ${orders[index]['date']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green[800]!;
      case 'cancelled':
        return Colors.red[800]!;
      case 'pending':
      default:
        return Colors.orange[800]!;
    }
  }

  Widget _buildPaymentMethodsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Payment Methods Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This user has not added any payment methods yet',
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
          widget.userName,
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card),
            label: 'Payments',
          ),
        ],
      ),
    );
  }
}
