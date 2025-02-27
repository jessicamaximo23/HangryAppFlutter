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

  Future<void> updatePassword(BuildContext context, String newPassword) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating password: $e')),
      );
    }
  }
  Future<void> updateAddress(String userId, String address) async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref("users/$userId/address");
      await ref.set(address);
    } catch (e) {
      print("Error updating address: $e");
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

            const SizedBox(height: 20),
            _buildProfileItem(context, Icons.person, 'Profile Information'),
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
                    print('Delete Account button pressed');
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

  Widget _buildProfileItem(BuildContext context, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF003049)),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {

      },
    );
  }
}