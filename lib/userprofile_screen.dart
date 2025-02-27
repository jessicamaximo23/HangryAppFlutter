import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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

  Future<void> updateUserDetails(BuildContext context, userId, fullname, phonenumber, address, city, zipcode) async {
    try {

      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$userId");
      await userRef.update({
        "name": fullname,
        "number": phonenumber,
        "address": address,
        "city" : city,
        "zipCode" : zipcode

      });
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // await user.updateEmail(email);
      }


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
    // Define custom colors
    final Color hangryYellow = Color(0xFFFCBF49);
    final Color hangryBlue = Color(0xFF003049);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Information'),
        backgroundColor: Color(0xFFFCBF49),
      ),
        body: Padding(
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
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) {
                        TextEditingController fullnameController = TextEditingController();
                        TextEditingController phonenumberController = TextEditingController();
                        TextEditingController addressController = TextEditingController();
                        TextEditingController cityController = TextEditingController();
                        TextEditingController zipCodeController = TextEditingController();

                        return Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 16,
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'My Profile',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                StreamBuilder(
                                  stream: FirebaseDatabase.instance.ref("users/${user.uid}").onValue,
                                  builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return CircularProgressIndicator();
                                    }

                                    if (snapshot.hasError) {
                                      return Text('Error: ${snapshot.error}');
                                    }

                                    return Column(
                                      children: [
                                        TextField(
                                          controller: fullnameController,
                                          decoration: const InputDecoration(labelText: 'Full Name*'),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: phonenumberController,
                                          decoration: const InputDecoration(labelText: 'Phone Number*'),
                                        ),
                                        const SizedBox(height: 8),
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
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton(
                                          onPressed: () {
                                            updateUserDetails(
                                              context,
                                              user.uid,
                                              fullnameController.text.trim(),
                                              phonenumberController.text.trim(),
                                              addressController.text.trim(),
                                              cityController.text.trim(),
                                              zipCodeController.text.trim(),
                                            );
                                            Navigator.pop(context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFFFCBF49),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15), // Espaçamento interno
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20), // Bordas arredondadas
                                            ),
                                          ),
                                          child: const Text('Save Profile'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            _buildProfileItem(context, Icons.location_on, 'Location'),
            _buildProfileItem(context, Icons.settings, 'App Settings'),
            _buildProfileItem(context, Icons.delivery_dining, 'Delivery Driver'),
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
    );
  }

  Widget _buildProfileItem(
      BuildContext context,
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