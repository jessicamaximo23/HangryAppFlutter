import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({Key? key}) : super(key: key);

  @override
  _RestaurantScreen createState() => _RestaurantScreen();
}

final Color hangryYellow = Color(0xFFFCBF49);
final Color hangryBlue = Color(0xFF003049);


class _RestaurantScreen extends State<RestaurantScreen> {
  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      Navigator.pushReplacementNamed(context, '/account_screen');
    } catch (e) {
      print("Error to log out: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to logout. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Dashboard'),
        backgroundColor: hangryYellow,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            Image.asset(
              'images/assets/logobackground.png',
              width: 200,
              height: 150,
            ),
            SizedBox(height: 20),
            const SizedBox(height: 20),
            Text('Welcome to Hangry!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: hangryBlue, // Use custom blue color
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text('Restaurant DashBoard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Dashboard cards
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: [
                  _buildDashboardCard(
                    icon: Icons.graphic_eq,
                    title: 'Graphics',
                    onTap: () {
                      // Navigate to deliveries screen
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.attach_money,
                    title: 'Earnings',
                    onTap: () {
                      // Navigate to earnings screen
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.menu,
                    title: 'Create my menu',
                    onTap: () {
                      // Navigate to schedule screen
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.person,
                    title: 'Profile',
                    onTap: () {
                      // Navigate to profile screen
                    },
                  ),
                ],
              ),
            ),


            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: ElevatedButton(
                onPressed: () => _signOut(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hangryYellow,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build dashboard cards
  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: hangryYellow),
              // Use custom yellow color
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hangryBlue, // Use custom blue color
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}