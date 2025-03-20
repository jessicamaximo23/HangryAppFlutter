import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminDriverScreen extends StatefulWidget {
  @override
  _AdminDriverScreenState createState() => _AdminDriverScreenState();
}

// Define custom colors
final Color hangryYellow = Color(0xFFFCBF49);
final Color hangryBlue = Color(0xFF003049);

class _AdminDriverScreenState extends State<AdminDriverScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('users');
  List<Map<String, dynamic>> drivers = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchDrivers();
  }

  void fetchDrivers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      DatabaseEvent event = await _databaseRef
          .orderByChild('accountType')
          .equalTo('driver')
          .once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> usersMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> fetchedDrivers = [];

        usersMap.forEach((key, value) {
          fetchedDrivers.add({
            'uid': key,
            'name': value['name'] ?? 'Unknown Driver',
            'email': value['email'] ?? '',
            'isActive': value['status'] == 'active',
            'profileImageUrl': value['profileImageUrl'] ?? '',
            'isApproved': value['isApproved'] ?? false,
          });
        });
        setState(() {
          drivers = fetchedDrivers;
          _isLoading = false;
        });
      } else {
        setState(() {
          drivers = [];
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

  void toggleDriverStatus(int index) async {
    final String uid = drivers[index]['uid'];
    final bool newStatus = !drivers[index]['isActive'];

    try {
      await _databaseRef.child(uid).update({
        'status': newStatus ? 'active' : 'inactive',
      });

      setState(() {
        drivers[index]['isActive'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Driver status updated successfully')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update driver status: $error')),
      );
    }
  }

  void toggleApprovalStatus(int index) async {
    final String uid = drivers[index]['uid'];
    final bool newStatus = !drivers[index]['isApproved'];

    try {
      await _databaseRef.child(uid).update({
        'isApproved': newStatus,
      });

      setState(() {
        drivers[index]['isApproved'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Driver approval status updated successfully!')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update approval status: $error')),
      );
    }
  }

  void navigateToDriverDetails(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverDetailScreen(
          driverUid: drivers[index]['uid'],
          driverName: drivers[index]['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Driver',
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
              'Driver List',
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
          else if (drivers.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No drivers found',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  fetchDrivers();
                },
                color: hangryYellow,
                child: ListView.builder(
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12),
                        leading: drivers[index]['profileImageUrl'].isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: CachedNetworkImage(
                                  imageUrl: drivers[index]['profileImageUrl'],
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
                          drivers[index]['name'],
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
                            Text(drivers[index]['email']),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: drivers[index]['isActive']
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    drivers[index]['isActive']
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      color: drivers[index]['isActive']
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
                                    color: drivers[index]['isApproved']
                                        ? Colors.blue.withOpacity(0.2)
                                        : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    drivers[index]['isApproved']
                                        ? 'Approved'
                                        : 'Pending',
                                    style: TextStyle(
                                      color: drivers[index]['isApproved']
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
                              value: drivers[index]['isActive'],
                              onChanged: (value) {
                                toggleDriverStatus(index);
                              },
                              activeColor: hangryYellow,
                              activeTrackColor: hangryYellow.withOpacity(0.5),
                            ),
                            // Approval toggle
                            IconButton(
                              icon: Icon(
                                drivers[index]['isApproved']
                                    ? Icons.verified_user
                                    : Icons.pending,
                                color: drivers[index]['isApproved']
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
                          navigateToDriverDetails(index);
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

class DriverDetailScreen extends StatefulWidget {
  final String driverUid;
  final String driverName;

  DriverDetailScreen({
    required this.driverUid,
    required this.driverName,
  });

  @override
  _DriverDetailScreenState createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  int _selectedIndex = 0;

  // Form controllers for editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _carColorController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();
  bool _isEditing = false;
  String? _driverLicenseStatus;
  String? _driverLicenseUrl;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  void _loadDriverData() async {
    try {
      final userSnapshot =
          await _databaseRef.child('users/${widget.driverUid}').get();

      if (userSnapshot.exists) {
        Map<dynamic, dynamic> userData =
            userSnapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> formattedData = {};

        // Format basic driver data
        formattedData['name'] = userData['name'] ?? 'Unknown';
        formattedData['email'] = userData['email'] ?? '';
        formattedData['status'] = userData['status'] ?? 'inactive';
        formattedData['isApproved'] = userData['isApproved'] ?? false;
        formattedData['profileImageUrl'] = userData['profileImageUrl'] ?? '';
        formattedData['earnings'] = userData['earnings'] ?? '0';

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
          _carModelController.text = profileData['carModel'] ?? '';
          _carColorController.text = profileData['carColor'] ?? '';
          _plateNumberController.text = profileData['plateNumber'] ?? '';
          _driverLicenseStatus = profileData['status'] ?? 'pending';
          _driverLicenseUrl = profileData['driverLicenseUrl'] ?? '';
        }

        setState(() {
          _driverData = formattedData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Driver data not found');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading driver data: $error');
    }
  }

  void _toggleDriverStatus() async {
    if (_driverData == null) return;

    bool currentStatus = _driverData!['status'] == 'active';
    String newStatus = currentStatus ? 'inactive' : 'active';

    try {
      await _databaseRef.child('users/${widget.driverUid}').update({
        'status': newStatus,
      });

      setState(() {
        _driverData!['status'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Driver status updated to ${newStatus.toUpperCase()}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update driver status: $error')),
      );
    }
  }

  void _toggleApprovalStatus() async {
    if (_driverData == null) return;

    bool currentStatus = _driverData!['isApproved'] == true;
    bool newStatus = !currentStatus;

    try {
      await _databaseRef.child('users/${widget.driverUid}').update({
        'isApproved': newStatus,
      });

      setState(() {
        _driverData!['isApproved'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Driver ${newStatus ? 'approved' : 'approval revoked'}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update approval status: $error')),
      );
    }
  }

  void _updateDriverLicenseStatus(String status) async {
    try {
      await _databaseRef.child('users/${widget.driverUid}/profile').update({
        'status': status,
      });

      setState(() {
        _driverLicenseStatus = status;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Driver license status updated to $status')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update driver license status: $error')),
      );
    }
  }

  void _saveDriverInfo() async {
    try {
      // Update profile data
      await _databaseRef.child('users/${widget.driverUid}/profile').update({
        'fullName': _nameController.text,
        'phoneNumber': _phoneController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'zipCode': _zipCodeController.text,
        'carModel': _carModelController.text,
        'carColor': _carColorController.text,
        'plateNumber': _plateNumberController.text,
      });

      // Also update the name at root level
      await _databaseRef.child('users/${widget.driverUid}').update({
        'name': _nameController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Driver information updated successfully')),
      );

      // Reload data and exit edit mode
      setState(() {
        _isEditing = false;
      });
      _loadDriverData();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update driver information: $error')),
      );
    }
  }

  Widget _buildScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildProfileInfoScreen();
      case 1:
        return _buildDeliveriesScreen();
      case 2:
        return _buildEarningsScreen();
      default:
        return Center(child: Text(''));
    }
  }

  Widget _buildProfileInfoScreen() {
    if (_driverData == null) {
      return Center(child: Text('No driver data available'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver profile section
          Center(
            child: Column(
              children: [
                _driverData!['profileImageUrl'].isNotEmpty
                    ? CircleAvatar(
                        radius: 60,
                        backgroundImage:
                            NetworkImage(_driverData!['profileImageUrl']),
                      )
                    : CircleAvatar(
                        radius: 60,
                        backgroundColor: hangryYellow.withOpacity(0.2),
                        child:
                            Icon(Icons.person, size: 60, color: hangryYellow),
                      ),
                SizedBox(height: 16),
                Text(
                  _driverData!['name'],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: hangryBlue,
                    fontFamily: 'RammettoOne-Regular',
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _driverData!['email'],
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
                        color: _driverData!['status'] == 'active'
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _driverData!['status'] == 'active'
                            ? 'Active'
                            : 'Inactive',
                        style: TextStyle(
                          color: _driverData!['status'] == 'active'
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
                        color: _driverData!['isApproved'] == true
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _driverData!['isApproved'] == true
                            ? 'Approved'
                            : 'Pending Approval',
                        style: TextStyle(
                          color: _driverData!['isApproved'] == true
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
                icon: Icon(_driverData!['status'] == 'active'
                    ? Icons.block
                    : Icons.check_circle),
                label: Text(_driverData!['status'] == 'active'
                    ? 'Deactivate'
                    : 'Activate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _driverData!['status'] == 'active'
                      ? Colors.red
                      : Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _toggleDriverStatus,
              ),
              ElevatedButton.icon(
                icon: Icon(_driverData!['isApproved'] == true
                    ? Icons.cancel
                    : Icons.verified_user),
                label: Text(_driverData!['isApproved'] == true
                    ? 'Revoke Approval'
                    : 'Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _driverData!['isApproved'] == true
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

          // Driver license section
          Text(
            'Driver\'s License',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: hangryBlue,
            ),
          ),
          SizedBox(height: 16),

          if (_driverLicenseUrl != null && _driverLicenseUrl!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CachedNetworkImage(
                imageUrl: _driverLicenseUrl!,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                    Center(child: Icon(Icons.error)),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getLicenseStatusColor(_driverLicenseStatus)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _driverLicenseStatus ?? 'pending',
                    style: TextStyle(
                      color: _getLicenseStatusColor(_driverLicenseStatus),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _updateDriverLicenseStatus('approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Approve License'),
                ),
                ElevatedButton(
                  onPressed: () => _updateDriverLicenseStatus('rejected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Reject License'),
                ),
                ElevatedButton(
                  onPressed: () => _updateDriverLicenseStatus('pending'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Mark Pending'),
                ),
              ],
            ),
          ] else
            Center(
              child: Text('No driver\'s license uploaded yet.'),
            ),

          Divider(height: 32),

          // Driver details section - Editable
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Driver Details',
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
                    _saveDriverInfo();
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
            _buildEditTextField('Car Model', _carModelController),
            _buildEditTextField('Car Color', _carColorController),
            _buildEditTextField('License Plate', _plateNumberController),
          ] else if (_driverData!.containsKey('profile')) ...[
            // Read-only profile data
            _buildDetailItem('Full Name',
                _driverData!['profile']['fullName'] ?? 'Not provided'),
            _buildDetailItem('Phone Number',
                _driverData!['profile']['phoneNumber'] ?? 'Not provided'),
            _buildDetailItem('Address',
                _driverData!['profile']['address'] ?? 'Not provided'),
            _buildDetailItem(
                'City', _driverData!['profile']['city'] ?? 'Not provided'),
            _buildDetailItem('Zip Code',
                _driverData!['profile']['zipCode'] ?? 'Not provided'),
            _buildDetailItem('Car Model',
                _driverData!['profile']['carModel'] ?? 'Not provided'),
            _buildDetailItem('Car Color',
                _driverData!['profile']['carColor'] ?? 'Not provided'),
            _buildDetailItem('License Plate',
                _driverData!['profile']['plateNumber'] ?? 'Not provided'),
          ],
        ],
      ),
    );
  }

  Color _getLicenseStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green[800]!;
      case 'rejected':
        return Colors.red[800]!;
      case 'pending':
      default:
        return Colors.orange[800]!;
    }
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

  Widget _buildDeliveriesScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Deliveries Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This driver has not completed any deliveries yet',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.attach_money, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Earnings Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This driver has not earned any income yet',
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
          widget.driverName,
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
            icon: Icon(Icons.delivery_dining),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Earnings',
          ),
        ],
      ),
    );
  }
}
