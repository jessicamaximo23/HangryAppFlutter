import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';


class ProfileScreenRestaurant extends StatefulWidget {
  const ProfileScreenRestaurant({Key? key}) : super(key: key);

  @override
  _ProfileScreenRestaurantState createState() => _ProfileScreenRestaurantState();
}

class _ProfileScreenRestaurantState extends State<ProfileScreenRestaurant> {
  String? _profileImageUrl;

  Future<String?> getUserName(String userId) async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref("users/$userId/name");
      DatabaseEvent event = await ref.once();
      return event.snapshot.value as String?;
    } catch (e) {
      print("Error fetching user name: $e");
      return null;
    }
  }

  Future<void> updaterestaurantDetails(
      BuildContext context,
      String userId,
      String fullname,
      String typeofcuisine,
      String phonenumber,
      String address,
      String city,
      String zipCode) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$userId/profile");
      await userRef.update({
        "fullName": fullname,
        "typeofcuisine": typeofcuisine,
        "phoneNumber": phonenumber,
        "address": address,
        "city": city,
        "zipCode": zipCode,
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
        DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}");
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

  Future<void> _uploadProfileImage(BuildContext context, File image) async {
    try {

      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.email == null) {
        print('No user logged in or email not found.');
        return;
      }

      final sanitizedEmail = user.email!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('restaurant_profileImage/$sanitizedEmail/${DateTime.now().toString()}.jpg');


      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update the image URL in the Realtime Database
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}/profile");
      await userRef.update({
        "photoUrl": downloadUrl,
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile picture updated successfully')),
      );
    } catch (e) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading profile picture: $e')),
      );
    }
  }

  Future<void> _pickImage(BuildContext context) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File image = File(pickedFile.path);
      await _uploadProfileImage(context, image);
    }
  }

  Future<String?> getProfileImageUrl(String userId) async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref("users/$userId/profile/photoUrl");
      DatabaseEvent event = await ref.once();
      return event.snapshot.value as String?;
    } catch (e) {
      print("Error fetching profile image URL: $e");
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      getProfileImageUrl(user.uid).then((url) {
        setState(() {
          _profileImageUrl = url;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    final Color hangryYellow = Color(0xFFFCBF49);
    final Color hangryBlue = Color(0xFF003049);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Restaurant'),
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
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50.0,
                      backgroundColor: Colors.grey,
                      backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                      child: _profileImageUrl == null ? Icon(Icons.person, size: 50, color: Colors.white) : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.camera_alt, color: hangryBlue),
                        onPressed: () {
                          if (user != null) {
                            _pickImage(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<String?>(
                future: user != null ? getUserName(user.uid) : Future.value(null),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              ),
              _buildProfileItem(
                context,
                Icons.person,
                'Profile Information',
                onTap: () {
                  if (user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreenRestaurant(userId: user.uid),
                      ),
                    );
                  }
                },
              ),
              _buildProfileItem(context, Icons.location_on, 'Location'),
              _buildProfileItem(context, Icons.settings, 'App Settings'),
              _buildProfileItem(context, Icons.delivery_dining, 'Delivery Driver'),
              _buildProfileItem(context, Icons.admin_panel_settings, 'Admin'),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF003049)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
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
class EditProfileScreenRestaurant extends StatefulWidget {
  final String userId;

  const EditProfileScreenRestaurant({Key? key, required this.userId}) : super(key: key);

  @override
  _EditProfileScreenRestaurantState createState() => _EditProfileScreenRestaurantState();
}

class _EditProfileScreenRestaurantState extends State<EditProfileScreenRestaurant> {
  final fullnameController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final zipCodeController = TextEditingController();
  final openHoursController = TextEditingController();
  final openDaysController = TextEditingController();

  final Color hangryYellow = Color(0xFFFCBF49);
  final Color hangryBlue = Color(0xFF003049);


  final List<String> cuisineTypes = [
    'Fast Food',
    'Indian',
    'Italian',
    'Japanese',
    'Mexican',
  ];

  String? selectedCuisine;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    DatabaseReference ref = FirebaseDatabase.instance.ref("users/${widget.userId}/profile");
    DatabaseEvent event = await ref.once();

    if (event.snapshot.value != null) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        fullnameController.text = data['fullName'] ?? '';
        selectedCuisine = data['typeofcuisine'] ?? '';
        phoneNumberController.text = data['phoneNumber'] ?? '';
        addressController.text = data['address'] ?? '';
        cityController.text = data['city'] ?? '';
        zipCodeController.text = data['zipCode'] ?? '';
        openHoursController.text = data['openHours'] ?? '';
        openDaysController.text = data['openDays'] ?? '';
      });
    }
  }

  Future<void> updaterestaurantDetails(
      BuildContext context,
      String userId,
      String fullname,
      String typeofcuisine,
      String phonenumber,
      String address,
      String city,
      String zipCode,
      String openHours,
      String openDays) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$userId/profile");
      await userRef.update({
        "fullName": fullname,
        "typeofcuisine": typeofcuisine,
        "phoneNumber": phonenumber,
        "address": address,
        "city": city,
        "zipCode": zipCode,
        "openHours": openHours,
        "openDays": openDays,
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

  Future<void> _saveProfileData() async {
    await updaterestaurantDetails(
      context,
      widget.userId,
      fullnameController.text.trim(),
      selectedCuisine ?? '',
      phoneNumberController.text.trim(),
      addressController.text.trim(),
      cityController.text.trim(),
      zipCodeController.text.trim(),
      openHoursController.text.trim(),
      openDaysController.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: hangryYellow,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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


              _buildStyledTextField(fullnameController, 'Full Name'),
              _buildCuisineDropdown(),
              _buildStyledTextField(phoneNumberController, 'Phone Number'),
              _buildStyledTextField(addressController, 'Address'),
              _buildStyledTextField(cityController, 'City'),
              _buildStyledTextField(zipCodeController, 'Zip Code'),
              _buildStyledTextField(openHoursController, 'Open Hours (e.g., 9 AM - 10 PM)'),
              _buildStyledTextField(openDaysController, 'Open Days (e.g., Mon - Sun)'),

              const SizedBox(height: 20),

              // Botão de salvar
              Center(
                child: ElevatedButton(
                  onPressed: _saveProfileData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hangryYellow,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
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


  Widget _buildCuisineDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: selectedCuisine,
        decoration: InputDecoration(
          labelText: 'Type of Cuisine',
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
        items: cuisineTypes.map((String cuisine) {
          return DropdownMenuItem<String>(
            value: cuisine,
            child: Text(cuisine),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            selectedCuisine = newValue;
          });
        },
      ),
    );
  }
}