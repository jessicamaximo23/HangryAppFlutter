import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileScreenRestaurant extends StatelessWidget {
  const ProfileScreenRestaurant({Key? key}) : super(key: key);

  Future<String?> getUserName(String userId) async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref(
          "users/$userId/name");
      DatabaseEvent event = await ref.once();
      return event.snapshot.value as String?;
    } catch (e) {
      print("Error fetching user name: $e");
      return null;
    }
  }

  Future<void> updateUserDetails(BuildContext context, userId, fullname, typeofcuisine,
      phonenumber, address, city, zipCode) async {
    try {
      DatabaseReference userRef = FirebaseDatabase.instance.ref(
          "users/$userId/profile");
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
      DatabaseReference profileRef = FirebaseDatabase.instance.ref(
          "users/$userId/profile");
      DatabaseEvent event = await profileRef.once();
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
        DatabaseReference userRef = FirebaseDatabase.instance.ref(
            "users/${user.uid}");
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
        title: const Text('Profile'),
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
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<String?>(
                future: user != null ? getUserName(user.uid) : Future.value(
                    null),
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
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery
                            .of(context)
                            .size
                            .height * 0.8,
                      ),
                      builder: (context) {
                        final fullnameController = TextEditingController();
                        final typeofcuisineController = TextEditingController();
                        final phoneNumberController = TextEditingController();
                        final addressController = TextEditingController();
                        final cityController = TextEditingController();
                        final zipCodeController = TextEditingController();

                        final FocusNode fullnameFocusNode = FocusNode();

                        DatabaseReference profileRef =
                        FirebaseDatabase.instance.ref("users/${user
                            .uid}/profile");

                        return FutureBuilder<DatabaseEvent>(
                          future: profileRef.once(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(
                                  child: Text('Error: ${snapshot.error}'));
                            }

                            if (snapshot.hasData &&
                                snapshot.data!.snapshot.value != null) {
                              final profileData = snapshot.data!.snapshot.value
                              as Map<dynamic, dynamic>;

                              fullnameController.text =
                                  profileData['fullName'] ?? '';
                              typeofcuisineController.text =
                                  profileData['typeofcuisine'] ?? '';
                              phoneNumberController.text =
                                  profileData['phoneNumber'] ?? '';
                              addressController.text =
                                  profileData['address'] ?? '';
                              cityController.text = profileData['city'] ?? '';
                              zipCodeController.text =
                                  profileData['zipCode'] ?? '';
                            }

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              FocusScope.of(context)
                                  .requestFocus(fullnameFocusNode);
                            });

                            return SingleChildScrollView(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 16,
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: fullnameController,
                                      decoration: const InputDecoration(
                                          labelText: 'Full Name*'),
                                    ),
                                    TextField(
                                      controller: typeofcuisineController,
                                      decoration: const InputDecoration(
                                          labelText: 'Type of Cusine '),

                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: phoneNumberController,
                                      decoration: const InputDecoration(
                                          labelText: 'Phone Number*'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: addressController,
                                      decoration: const InputDecoration(
                                          labelText: 'Address'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: cityController,
                                      decoration: const InputDecoration(
                                          labelText: 'City'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: zipCodeController,
                                      decoration: const InputDecoration(
                                          labelText: 'ZipCode'),
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: () {
                                        updateUserDetails(
                                          context,
                                          user.uid,
                                          fullnameController.text.trim(),
                                          typeofcuisineController.text.trim(),
                                          phoneNumberController.text.trim(),
                                          addressController.text.trim(),
                                          cityController.text.trim(),
                                          zipCodeController.text.trim(),
                                        );
                                        Navigator.pop(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: hangryYellow,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 30, vertical: 15),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              20),
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
                },
              ),
              _buildProfileItem(context, Icons.location_on, 'Location'),
              _buildProfileItem(context, Icons.settings, 'App Settings'),
              _buildProfileItem(
                  context, Icons.delivery_dining, 'Delivery Driver'),
              _buildProfileItem(context, Icons.admin_panel_settings, 'Admin'),
              const SizedBox(height: 70),
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


  Widget _buildProfileItem(BuildContext context,
      IconData icon,
      String title, {
        VoidCallback? onTap,
      }) {
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
