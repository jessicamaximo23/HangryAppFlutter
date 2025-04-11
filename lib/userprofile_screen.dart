import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _profileImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final profileSnapshot = await FirebaseDatabase.instance
            .ref("users/${user.uid}/profile/profileImageUrl")
            .get();

        if (profileSnapshot.exists) {
          setState(() {
            _profileImageUrl = profileSnapshot.value as String?;
          });
          return;
        }

        final rootSnapshot = await FirebaseDatabase.instance
            .ref("users/${user.uid}/profileImageUrl")
            .get();

        if (rootSnapshot.exists) {
          setState(() {
            _profileImageUrl = rootSnapshot.value as String?;
          });
          return;
        }

        // If nothing in DB, use the user's photoURL from Firebase Auth
        if (user.photoURL != null) {
          setState(() {
            _profileImageUrl = user.photoURL;
          });
        }
      } catch (e) {
        print("Error loading profile image: $e");
      }
    }
  }

  Future<String?> getUserName(String userId) async {
    try {
      DatabaseReference ref =
          FirebaseDatabase.instance.ref("users/$userId/name");
      DatabaseEvent event = await ref.once();
      return event.snapshot.value as String?;
    } catch (e) {
      print("Error fetching user name: $e");
      return null;
    }
  }

  Future<void> updateUserDetails(
      BuildContext context,
      String userId,
      String fullname,
      String phonenumber,
      String address,
      String city,
      String postalCode) async {
    try {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref("users/$userId/profile");
      await userRef.update({
        "fullName": fullname,
        "phoneNumber": phonenumber,
        "address": address,
        "city": city,
        "zipCode": postalCode,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  Future<void> deleteAccount(BuildContext context) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DatabaseReference userRef =
            FirebaseDatabase.instance.ref("users/${user.uid}");
        await userRef.remove();
        await user.delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account deleted successfully')),
        );

        Navigator.of(context).pushReplacementNamed('/account_screen');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    final Color hangryYellow = Color(0xFFFCBF49);
    final Color hangryBlue = Color(0xFF003049);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile User'),
        backgroundColor: hangryYellow,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    if (_isLoading) return; // Prevent multiple uploads

                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      final ImagePicker _picker = ImagePicker();
                      final XFile? image =
                          await _picker.pickImage(source: ImageSource.gallery);

                      if (image != null && user != null) {
                        // Show loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Uploading image...')),
                        );

                        // Create a properly formatted storage path with sanitized email
                        final sanitizedEmail = user.email
                                ?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ??
                            'unknown';
                        final storageRef = FirebaseStorage.instance
                            .ref()
                            .child('user_profileImage/$sanitizedEmail.jpg');

                        // Upload the image
                        final uploadTask =
                            await storageRef.putFile(File(image.path));
                        final downloadURL =
                            await uploadTask.ref.getDownloadURL();

                        // Update Firebase Auth profile
                        await user.updatePhotoURL(downloadURL);

                        // Update in the database root level
                        DatabaseReference userRef =
                            FirebaseDatabase.instance.ref("users/${user.uid}");
                        await userRef.update({'profileImageUrl': downloadURL});

                        // Update in the database under profile/profileImageUrl
                        DatabaseReference profileRef = FirebaseDatabase.instance
                            .ref("users/${user.uid}/profile");
                        await profileRef
                            .update({'profileImageUrl': downloadURL});

                        // Update local state to show the new image immediately
                        setState(() {
                          _profileImageUrl = downloadURL;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Profile picture updated successfully')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Error updating profile picture: $e')),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50.0,
                        backgroundColor: Colors.grey,
                        backgroundImage: _profileImageUrl != null
                            ? NetworkImage(_profileImageUrl!)
                            : (user != null && user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : null),
                        child: (_profileImageUrl == null &&
                                (user == null || user.photoURL == null))
                            ? Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                      ),
                      if (_isLoading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: hangryYellow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<String?>(
                future:
                    user != null ? getUserName(user.uid) : Future.value(null),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: hangryBlue,
                        ),
                      ),
                    );
                  } else {
                    return Center(
                      child: Text(
                        snapshot.data ?? 'User',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: hangryBlue,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              //   children: [
              //     _buildTopButton(
              //       icon: Icons.wallet,
              //       label: 'Wallet',
              //       onPressed: () {
              //         print('Wallet button pressed');
              //       },
              //       color: hangryYellow,
              //     ),
              //     _buildTopButton(
              //       icon: Icons.favorite,
              //       label: 'Favorites',
              //       onPressed: () {
              //         print('Favorites button pressed');
              //       },
              //       color: hangryYellow,
              //     ),
              //   ],
              // ),
              _buildProfileItem(
                context,
                Icons.person,
                'Profile Information',
                onTap: () {
                  if (user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(
                            userId: user.uid, email: user.email ?? ""),
                      ),
                    ).then((_) {
                      // Refresh the profile image when returning from Edit Profile
                      _loadProfileImage();
                    });
                  }
                },
              ),
              _buildProfileItem(context, Icons.location_on, 'Location'),
              _buildProfileItem(context, Icons.settings, 'App Settings'),
              _buildProfileItem(
                  context, Icons.delivery_dining, 'Delivery Driver'),
              _buildProfileItem(context, Icons.admin_panel_settings, 'Admin'),

              // Add Order History section for user profile
              _buildProfileItem(
                context,
                Icons.receipt_long,
                'Order History',
                onTap: () {
                  print('Order History button pressed');
                  // You can navigate to an order history screen here
                },
              ),

              const SizedBox(height: 100),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomButton(
                    label: 'Delete Account',
                    onPressed: () {
                      deleteAccount(context);
                    },
                    color: hangryYellow,
                  ),
                  _buildBottomButton(
                    label: 'Review',
                    onPressed: () {
                      print('Review button pressed');
                    },
                    color: hangryYellow,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String title,
      {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF003049)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildTopButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.black),
      label: Text(
        label,
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String email;

  const EditProfileScreen({
    Key? key,
    required this.userId,
    required this.email,
  }) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final fullnameController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final postalCodeController = TextEditingController();

  String? _profileImageUrl;
  bool _isLoading = false;

  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DatabaseReference ref =
          FirebaseDatabase.instance.ref("users/${widget.userId}/profile");
      DatabaseEvent event = await ref.once();

      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          fullnameController.text = data['fullName'] ?? '';
          phoneNumberController.text = data['phoneNumber'] ?? '';
          addressController.text = data['address'] ?? '';
          cityController.text = data['city'] ?? '';
          postalCodeController.text = data['zipCode'] ?? '';
          _profileImageUrl = data['profileImageUrl'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DatabaseReference ref =
          FirebaseDatabase.instance.ref("users/${widget.userId}/profile");
      await ref.update({
        'fullName': fullnameController.text.trim(),
        'phoneNumber': phoneNumberController.text.trim(),
        'address': addressController.text.trim(),
        'city': cityController.text.trim(),
        'zipCode': postalCodeController.text.trim(),
        'profileImageUrl': _profileImageUrl,
      });

      // Also update the name at root level for consistency
      await FirebaseDatabase.instance
          .ref("users/${widget.userId}")
          .update({'name': fullnameController.text.trim()});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // Sanitize email for storage path
        final sanitizedEmail =
            widget.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

        // Use a consistent storage path
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_profileImage/$sanitizedEmail.jpg');

        // Upload the image
        final uploadTask = await storageRef.putFile(File(image.path));
        final downloadURL = await uploadTask.ref.getDownloadURL();

        // Update Firebase Auth profile
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updatePhotoURL(downloadURL);
        }

        // Update root level
        await FirebaseDatabase.instance.ref("users/${widget.userId}").update({
          'profileImageUrl': downloadURL,
        });

        // Update profile with the profile image URL
        DatabaseReference ref =
            FirebaseDatabase.instance.ref("users/${widget.userId}/profile");
        await ref.update({
          'profileImageUrl': downloadURL,
        });

        setState(() {
          _profileImageUrl = downloadURL;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile picture: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: hangryYellow,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Edit Your Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: hangryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Profile Image
                    Center(
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50.0,
                              backgroundColor: Colors.grey,
                              backgroundImage: _profileImageUrl != null
                                  ? NetworkImage(_profileImageUrl!)
                                  : null,
                              child: _profileImageUrl == null
                                  ? Icon(Icons.person,
                                      size: 50, color: Colors.white)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: hangryYellow,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildStyledTextField(fullnameController, 'Full Name'),
                    _buildStyledTextField(
                        phoneNumberController, 'Phone Number'),
                    _buildStyledTextField(addressController, 'Address'),
                    _buildStyledTextField(cityController, 'City'),
                    _buildStyledTextField(postalCodeController, 'Zip Code'),

                    const SizedBox(height: 20),

                    Center(
                      child: ElevatedButton(
                        onPressed: _saveProfileData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hangryYellow,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 15),
                        ),
                        child: const Text('Save Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStyledTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: hangryBlue),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: hangryBlue),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: hangryYellow, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
