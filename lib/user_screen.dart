import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hangry_app_flutter/order_history_screen.dart';
import 'package:hangry_app_flutter/track_order_screen.dart';
import 'userprofile_screen.dart';
import 'restaurant_listing_screen.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({Key? key}) : super(key: key);

  @override
  _UserScreenState createState() => _UserScreenState();
}

final Color hangryYellow = Color(0xFFFCBF49);
final Color hangryBlue = Color(0xFF003049);

class _UserScreenState extends State<UserScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

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

  void _navigateToTrackOrder(BuildContext context) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You need to be logged in to track orders')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(hangryYellow),
            ),
          );
        },
      );

      // Get active orders
      final ordersSnapshot = await _database
          .child('users/${_currentUser!.uid}/profile/orders')
          .orderByChild('status')
          .startAt('on_the_way')
          .endAt('on_the_way\uf8ff')
          .get();

      // Close loading indicator
      Navigator.pop(context);

      if (!ordersSnapshot.exists) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('No Active Orders'),
              content: Text(
                  'You don\'t have any active orders to track at the moment.'),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
        return;
      }

      // If there's only one active order, navigate directly to tracking
      final orders = Map<String, dynamic>.from(ordersSnapshot.value as Map);
      if (orders.length == 1) {
        final orderId = orders.keys.first;
        final orderData = orders[orderId] as Map<dynamic, dynamic>;

        _navigateToTrackOrderScreen(
            context,
            orderId,
            _currentUser!.uid,
            orderData['restaurantId'],
            orderData['restaurantName'] ?? 'Restaurant');
      } else {
        // If there are multiple active orders, show a selection dialog
        _showOrderSelectionDialog(context, orders);
      }
    } catch (e) {
      // Close loading indicator if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading active orders: $e')),
      );
    }
  }

  void _showOrderSelectionDialog(
      BuildContext context, Map<String, dynamic> orders) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Order to Track'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final orderId = orders.keys.elementAt(index);
                final orderData = orders[orderId] as Map<dynamic, dynamic>;
                final restaurantName =
                    orderData['restaurantName'] ?? 'Restaurant';

                return ListTile(
                  title: Text('Order #${orderId.substring(0, 8)}...'),
                  subtitle: Text(restaurantName),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToTrackOrderScreen(
                        context,
                        orderId,
                        _currentUser!.uid,
                        orderData['restaurantId'],
                        restaurantName);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToTrackOrderScreen(BuildContext context, String orderId,
      String userId, String restaurantId, String restaurantName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackOrderScreen(
          orderId: orderId,
          userId: userId,
          restaurantId: restaurantId,
          restaurantName: restaurantName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rest of your build method remains the same
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
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
            const SizedBox(height: 20),
            Text(
              'Welcome to Hangry!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: hangryBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'User DashBoard',
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
                    icon: Icons.list,
                    title: 'Previous Orders',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => OrderHistoryScreen()),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.map,
                    title: 'Track my order',
                    onTap: () => _navigateToTrackOrder(context),
                  ),
                  _buildDashboardCard(
                    icon: Icons.restaurant,
                    title: 'Restaurant ',
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => RestaurantListingScreen()));
                    },
                  ),
                  _buildDashboardCard(
                    icon: Icons.person,
                    title: 'Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProfileScreen()),
                      );
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
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hangryBlue,
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
