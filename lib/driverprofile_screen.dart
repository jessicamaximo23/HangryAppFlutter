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
                child: GestureDetector(
                  onTap: () async {

                    final ImagePicker _picker = ImagePicker();
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

                    if (image != null && user != null) {

                      final storageRef = FirebaseStorage.instance
                          .ref()
                          .child('driver_profileImage/${user.email}');

                      final uploadTask = await storageRef.putFile(File(image.path));
                      final downloadURL = await uploadTask.ref.getDownloadURL();

                      await user.updatePhotoURL(downloadURL);

                      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/${user.uid}/profile");
                      await userRef.update({'photoURL': downloadURL});

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile picture updated successfully')),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 50.0,
                    backgroundColor: Colors.grey,
                    backgroundImage: user != null && user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user == null || user.photoURL == null
                        ? Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreenDriver(
                            userId: user.uid, email: user.email ?? ""),
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
}

class EditProfileScreenDriver extends StatefulWidget {
  final String userId;
  final String email;

  const EditProfileScreenDriver({
    Key? key,
    required this.userId,
    required this.email,
  }) : super(key: key);

  @override
  _EditProfileScreenDriverState createState() => _EditProfileScreenDriverState();

}

class _EditProfileScreenDriverState extends State<EditProfileScreenDriver> {
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
              _buildStyledTextField(phoneNumberController, 'Phone Number'),
              _buildStyledTextField(addressController, 'Address'),
              _buildStyledTextField(cityController, 'City'),
              _buildStyledTextField(zipCodeController, 'Zip Code'),
              _buildStyledTextField(carModelController, 'Car Model'),
              _buildStyledTextField(carColorController, 'Car Color'),
              _buildStyledTextField(plateNumberController, 'Plate Number'),

              const SizedBox(height: 20),

              Center(
                child: Column(
                  children: [
                    StreamBuilder<DatabaseEvent>(
                      stream: FirebaseDatabase.instance
                          .ref("users/${widget.userId}/profile/status")
                          .onValue,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(color: Colors.red),
                          );
                        } else if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                          return Column(
                            children: [
                              Text(
                                'You have not uploaded your driver license yet.',
                                style: TextStyle(color: Colors.black, fontSize: 16),
                              ),
                            ],
                          );
                        } else {
                          String status = snapshot.data!.snapshot.value as String;

                          String message;
                          Color color;
                          IconData icon;

                          switch (status) {
                            case 'pending':
                              message = 'Your driver license is under review. ';
                              color = Colors.orange;
                              icon = Icons.access_time;
                              break;
                            case 'approved':
                              message = 'Your driver license has been approved.';
                              color = Colors.green;
                              icon = Icons.check_circle;
                              break;
                            case 'rejected':
                              message = 'Your driver license has been rejected.';
                              color = Colors.red;
                              icon = Icons.error;
                              break;
                            default:
                              message = 'You can upload your driver license now.';
                              color = Colors.blue;
                              icon = Icons.upload;
                          }

                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon, color: color, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    message,
                                    style: TextStyle(color: color, fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                              if (status == 'rejected' || status == '')
                                SizedBox(height: 20),
                            ],
                          );
                        }
                      },
                    ),
                    ElevatedButton(
                      onPressed: _pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hangryYellow,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                      ),
                      child: const Text('Upload Driver License'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _saveProfileData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hangryYellow,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                      ),
                      child: const Text('Save Profile'),
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

  @override
  void initState() {
    super.initState();

    _loadProfileData();
    // _checkDriverLicenseStatus();
  }

  Future<void> _loadProfileData() async {
    DatabaseReference ref = FirebaseDatabase.instance.ref(
        "users/${widget.userId}/profile");
    DatabaseEvent event = await ref.once();

    if (event.snapshot.value != null) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        fullnameController.text = data['fullName'] ?? '';
        phoneNumberController.text = data['phoneNumber'] ?? '';
        addressController.text = data['address'] ?? '';
        cityController.text = data['city'] ?? '';
        zipCodeController.text = data['zipCode'] ?? '';
        carModelController.text = data['carModel'] ?? '';
        carColorController.text = data['carColor'] ?? '';
        plateNumberController.text = data['plateNumber'] ?? '';
        _driverLicenseUrl = data['driverLicenseUrl'];
      });
    }
  }

  Future<void> _saveProfileData() async {
    DatabaseReference ref = FirebaseDatabase.instance.ref(
        "users/${widget.userId}/profile");
    await ref.update({
      'fullName': fullnameController.text.trim(),
      'phoneNumber': phoneNumberController.text.trim(),
      'address': addressController.text.trim(),
      'city': cityController.text.trim(),
      'zipCode': zipCodeController.text.trim(),
      'carModel': carModelController.text.trim(),
      'carColor': carColorController.text.trim(),
      'plateNumber': plateNumberController.text.trim(),
      'driverLicenseUrl': _driverLicenseUrl,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
    Navigator.pop(context);
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      _driverLicenseImage = File(image.path);
      _uploadDriverLicense(_driverLicenseImage!);
    }
  }

  Future<void> _uploadDriverLicense(File image) async {
    try {

      final sanitizedEmail = widget.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('driver_license/$sanitizedEmail');

      final uploadTask = await storageRef.putFile(image);
      final downloadURL = await uploadTask.ref.getDownloadURL();


      DatabaseReference ref = FirebaseDatabase.instance.ref("users/${widget.userId}/profile");
      await ref.update({
        'driverlicenseUrl': downloadURL,
        'status': 'pending',
      });

      setState(() {
        _driverLicenseUrl = downloadURL;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded successfully! Awaiting admin approval.')),
      );
    } catch (e) {
      print("Error uploading image:");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photo: $e')),
      );
    }
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
