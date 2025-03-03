import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hangry_app_flutter/driver_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfileScreenDriver extends StatelessWidget {
  const ProfileScreenDriver({Key? key}) : super(key: key);

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

  Future<void> updatedriverDetails(
      BuildContext context,
      String userId,
      String fullname,
      String phonenumber,
      String address,
      String city,
      String zipCode,
      String carModel,
      String carColor,
      String plateNumber,
      String? driverLicenseUrl,) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$userId/profile");
      await userRef.update({
        "fullName": fullname,
        "phoneNumber": phonenumber,
        "address": address,
        "city": city,
        "zipCode": zipCode,
        "carModel": carModel,
        "carColor": carColor,
        "plateNumber": plateNumber,
        "driverLicenseUrl": driverLicenseUrl,
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


  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    final Color hangryYellow = Color(0xFFFCBF49);
    final Color hangryBlue = Color(0xFF003049);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Driver'),
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
                child: CircleAvatar(
                  radius: 50.0,
                  backgroundColor: Colors.grey,
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null ? Icon(Icons.person, size: 50, color: Colors.white) : null,
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
                children: [
                  _buildTopButton(
                    icon: Icons.wallet,
                    label: 'Wallet',
                    onPressed: () {
                      print('Wallet button pressed');
                    },
                    color: hangryYellow,
                  ),
                  _buildTopButton(
                    icon: Icons.favorite,
                    label: 'Favorites',
                    onPressed: () {
                      print('Favorites button pressed');
                    },
                    color: hangryYellow,
                  ),
                ],
              ),
              _buildProfileItem(
                context,
                Icons.person,
                'Profile Information',
                onTap: () {
                  if (user != null) {
                    _showProfileBottomSheet(context, user);
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

  void _showProfileBottomSheet(BuildContext context, User user) {
    final fullnameController = TextEditingController();
    final phoneNumberController = TextEditingController();
    final addressController = TextEditingController();
    final cityController = TextEditingController();
    final zipCodeController = TextEditingController();
    final carModelController = TextEditingController();
    final carColorController = TextEditingController();
    final plateNumberController = TextEditingController();

    File? _driverLicenseImage;
    String? _driverLicenseUrl;

    final FocusNode fullnameFocusNode = FocusNode();

    DatabaseReference profileRef = FirebaseDatabase.instance.ref("users/${user.uid}/profile");

    Future<String> _uploadDriverLicense(File image) async {
      try {
        final storageRef = FirebaseStorage.instance.ref().child('driver_licenses/${user.uid}.jpg');
        await storageRef.putFile(image);
        final downloadURL = await storageRef.getDownloadURL();
        return downloadURL; 
      } catch (e) {
        print("Error uploading image: $e");
        throw e; 
      }
    }

    Future<void> _pickImage() async {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        print("Image selected: ${image.path}");

        _driverLicenseImage = File(image.path);
        _driverLicenseUrl = await _uploadDriverLicense(_driverLicenseImage!);

        print("Image uploaded, URL: $_driverLicenseUrl");
      } else {
        print("No image selected");
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<DatabaseEvent>(
          future: profileRef.once(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              final profileData = snapshot.data!.snapshot.value as Map<
                  dynamic,
                  dynamic>;

              fullnameController.text = profileData['fullName'] ?? '';
              phoneNumberController.text = profileData['phoneNumber'] ?? '';
              addressController.text = profileData['address'] ?? '';
              cityController.text = profileData['city'] ?? '';
              zipCodeController.text = profileData['zipCode'] ?? '';
              carModelController.text = profileData['carModel'] ?? '';
              carColorController.text = profileData['carColor'] ?? '';
              plateNumberController.text = profileData['plateNumber'] ?? '';
              _driverLicenseUrl = profileData['driverLicenseUrl'];
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              FocusScope.of(context).requestFocus(fullnameFocusNode);
            });

            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 5,
                  right: 5,
                  top: 5,
                  bottom: MediaQuery
                      .of(context)
                      .viewInsets
                      .bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'My Profile',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: fullnameController,
                      decoration: const InputDecoration(
                          labelText: 'Full Name*'),
                      focusNode: fullnameFocusNode,
                    ),
                    TextField(
                      controller: phoneNumberController,
                      decoration: const InputDecoration(
                          labelText: 'Phone Number*'),
                    ),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    TextField(
                      controller: cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                    TextField(
                      controller: zipCodeController,
                      decoration: const InputDecoration(labelText: 'ZipCode'),
                    ), TextField(
                      controller: carModelController,
                      decoration: const InputDecoration(labelText: 'Car Model'),
                    ),
                    TextField(
                      controller: carColorController,
                      decoration: const InputDecoration(labelText: 'Car Color'),
                    ),
                    TextField(
                      controller: plateNumberController,
                      decoration: const InputDecoration(
                          labelText: 'Plate Number'),
                    ),
                    const SizedBox(height: 10),
                    if (_driverLicenseUrl != null)
                      Image.network(_driverLicenseUrl!, height: 100),
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: Text('Upload Driver License'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (_driverLicenseImage !=
                            null) { // Verifica se a imagem foi selecionada
                          await _uploadDriverLicense(
                              _driverLicenseImage!); // Faz o upload da imagem
                          updatedriverDetails(
                            context,
                            user.uid,
                            fullnameController.text.trim(),
                            phoneNumberController.text.trim(),
                            addressController.text.trim(),
                            cityController.text.trim(),
                            zipCodeController.text.trim(),
                            carModelController.text.trim(),
                            carColorController.text.trim(),
                            plateNumberController.text.trim(),
                            _driverLicenseUrl,
                          );
                          Navigator.pop(context); 
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Please select an image first')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hangryYellow,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Save Profile'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

  Widget _buildProfileItem(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
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