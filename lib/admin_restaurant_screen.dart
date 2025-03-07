import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AdminRestaurantScreen extends StatefulWidget {
  @override
  _AdminRestaurantScreenState createState() => _AdminRestaurantScreenState();
}
// Define custom colors
final Color hangryYellow = Color(0xFFFCBF49);
final Color hangryBlue = Color(0xFF003049);

class _AdminRestaurantScreenState extends State<AdminRestaurantScreen> {

  List<Map<String, dynamic>> restaurants = [
    {'name': 'Indian', 'isActive': true},
    {'name': 'Japanese', 'isActive': false},
    {'name': 'Mexican', 'isActive': true},
    {'name': 'Italian', 'isActive': false},
    {'name': 'Fast Food', 'isActive': true},
  ];


  void toggleRestaurantStatus(int index) {
    setState(() {
      restaurants[index]['isActive'] = !restaurants[index]['isActive'];
    });
  }


  void navigateToEditScreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailScreen(
          restaurantName: restaurants[index]['name'],
          onSave: (details) {
            // Aqui você pode salvar os detalhes no Firebase ou em outro local
            print('Detalhes salvos: $details');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Restaurant'),
        backgroundColor: hangryYellow,
      ),


      body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
      Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Restaurant List',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: hangryBlue,
        ),
      ),
    ),
            Expanded(
              child: ListView.builder(
                itemCount: restaurants.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(
                        restaurants[index]['name'],
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      trailing: Switch(
                        value: restaurants[index]['isActive'],
                        onChanged: (value) {
                          toggleRestaurantStatus(index);
                        },
                        activeColor: Colors.green,
                      ),
                      onTap: () {
                        navigateToEditScreen(index);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
      ),
    );
  }
}

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantName;

  RestaurantDetailScreen({required this.restaurantName, required Null Function(dynamic details) onSave});

  @override
  _RestaurantDetailScreenState createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _restaurantData;
  int _selectedIndex = 0;


  void _loadRestaurantData() async {
    final snapshot = await _databaseRef.child(
        'restaurants/${widget.restaurantName}').get();
    if (snapshot.exists) {
      setState(() {
        _restaurantData = Map<String, dynamic>.from(snapshot.value as Map);
      });
    } else {
      print('Restaurant data not found');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
  }


  Widget _buildScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildOrdersAndEarningsScreen();
      case 1:
        return _buildReviewsScreen();
      case 2:
        return _buildAdminChatScreen();
      default:
        return Center(child: Text(''));
    }
  }


  Widget _buildOrdersAndEarningsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Orders + Earnings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          if (_restaurantData != null)
            Text('Total Earnings: \$${_restaurantData!['earnings'] ?? '0'}'),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {


            },
            child: Text('View Orders'),
          ),
        ],
      ),
    );
  }

  // Tela de Reviews
  Widget _buildReviewsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Reviews',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          if (_restaurantData != null && _restaurantData!['reviews'] != null)
            Expanded(
              child: ListView.builder(
                itemCount: _restaurantData!['reviews'].length,
                itemBuilder: (context, index) {
                  final review = _restaurantData!['reviews'][index];
                  return ListTile(
                    title: Text(review['user']),
                    subtitle: Text(review['comment']),
                    trailing: Text('Rating: ${review['rating']}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminChatScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Admin Chat',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          if (_restaurantData != null && _restaurantData!['chat'] != null)
            Expanded(
              child: ListView.builder(
                itemCount: _restaurantData!['chat'].length,
                itemBuilder: (context, index) {
                  final message = _restaurantData!['chat'][index];
                  return ListTile(
                    title: Text(message['sender']),
                    subtitle: Text(message['text']),
                    trailing: Text(message['timestamp']),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurantName),
        backgroundColor: hangryYellow, // Cor do AppBar
      ),
      body: _restaurantData == null
          ? Center(child: CircularProgressIndicator())
          : _buildScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: hangryYellow,
        selectedItemColor: hangryBlue,
        unselectedItemColor: Colors.grey,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Orders/Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Reviews',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}