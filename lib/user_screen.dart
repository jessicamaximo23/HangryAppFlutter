import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


class UserScreen extends StatefulWidget {
  const UserScreen({Key? key}) : super(key: key);

  @override
  _UserScreenState createState() => _UserScreenState();
}

final Color hangryYellow = Color(0xFFFCBF49);
final Color hangryBlue = Color(0xFF003049);

class _UserScreenState extends State<UserScreen> {
  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      Navigator.pushReplacementNamed(context, '/signin_screen');
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
        title: const Text('User Dashboard'),
        backgroundColor:  hangryYellow,
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
              Text('User DashBoard',
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
                    icon: Icons.delivery_dining,
                    title: 'My Deliveries',
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
                    icon: Icons.schedule,
                    title: 'Schedule',
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
