import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
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
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('users');
  List<Map<String, dynamic>> restaurants = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // TRYING STUFF ================================================
  // List<Map<String, dynamic>> restaurants = [
  //   {'name': 'Indian', 'isActive': true},
  //   {'name': 'Japanese', 'isActive': false},
  //   {'name': 'Mexican', 'isActive': true},
  //   {'name': 'Italian', 'isActive': false},
  //   {'name': 'Fast Food', 'isActive': true},
  // ];

  // void toggleRestaurantStatus(int index) {
  //   setState(() {
  //     restaurants[index]['isActive'] = !restaurants[index]['isActive'];
  //   });
  // }

  // =============================================================

  @override
  void initState() {
    super.initState();
    fetchRestaurants();
  }

  void fetchRestaurants() async {
    try {
      setState(() {
        _isLoading = true;
      });

      DatabaseEvent event = await _databaseRef
          .orderByChild('accountType')
          .equalTo('restaurant')
          .once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> usersMap =
            event.snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> fetchedRestaurants = [];

        usersMap.forEach((key, value) {
          fetchedRestaurants.add({
            'uid': key,
            'name': value['name'] ?? 'Unknown Restaurant',
            'email': value['email'] ?? '',
            'isActive': value['status'] == 'active',
            'profileImageUrl': value['profileImageUrl'] ?? '',
            'isApproved': value['isApproved'] ?? false,
          });
        });
        setState(() {
          restaurants = fetchedRestaurants;
          _isLoading = false;
        });
      } else {
        setState(() {
          restaurants = [];
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  // Adding the toggle method
  void toggleRestaurantsStatus(int index) async {
    final String uid = restaurants[index]['uid'];
    final bool newStatus = !restaurants[index]['isActive'];

    try {
      await _databaseRef.child(uid).update({
        'status': newStatus ? 'active' : 'inactive',
      });

      setState(() {
        restaurants[index]['isActive'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restaurant status updated successfully')),
      );
    }catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update restaurant status: $error')),
      );
    }
  }


  void toggleApprovalStatus(int index) async {
    final String uid = restaurants[index]['uid'];
    final bool newStatus = !restaurants[index]['isApproved'];

    try {
      await _databaseRef.child(uid).update({
        'isApproved': newStatus,
      });

      setState(() {
        restaurants[index]['isApproved'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restaurant approval status updated successfully!')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update approval status: $error')),
      );
    }
  }

  void navigateToRestaurantDetails(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailScreen(
          restaurantUid: restaurants[index]['uid'],
          restaurantName: restaurants[index]['name'],
          onSave: (details) {
            print('Details saved: $details');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Restaurant',
          style: TextStyle(
            fontFamily: 'RammettoOne-Regular',
            color: Colors.black,
          ),
        ),
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
                fontFamily: 'RammettoOne-Regular',
              ),
            ),
          ),
          if (_isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: hangryYellow,
                ),
              ),
            )
          else if (_errorMessage.isNotEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Error: $_errorMessage',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            )
          else if (restaurants.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No restaurants found',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    fetchRestaurants();
                  },
                  color: hangryYellow,
                  child: ListView.builder(
                    itemCount: restaurants.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(12),
                          leading: restaurants[index]['profileImageUrl'].isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: CachedNetworkImage(
                              imageUrl: restaurants[index]['profileImageUrl'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => CircularProgressIndicator(
                                color: hangryYellow,
                                strokeWidth: 2,
                              ),
                              errorWidget: (context, url, error) => CircleAvatar(
                                backgroundColor: hangryYellow.withOpacity(0.2),
                                child: Icon(Icons.restaurant, color: hangryYellow),
                              ),
                            ),
                          )
                              : CircleAvatar(
                            backgroundColor: hangryYellow.withOpacity(0.2),
                            radius: 25,
                            child: Icon(Icons.restaurant, color: hangryYellow),
                          ),
                          title: Text(
                            restaurants[index]['name'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'RammettoOne-Regular',
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(restaurants[index]['email']),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: restaurants[index]['isActive']
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      restaurants[index]['isActive'] ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        color: restaurants[index]['isActive']
                                            ? Colors.green[800]
                                            : Colors.red[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: restaurants[index]['isApproved']
                                          ? Colors.blue.withOpacity(0.2)
                                          : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      restaurants[index]['isApproved'] ? 'Approved' : 'Pending',
                                      style: TextStyle(
                                        color: restaurants[index]['isApproved']
                                            ? Colors.blue[800]
                                            : Colors.orange[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Status toggle
                              Switch(
                                value: restaurants[index]['isActive'],
                                onChanged: (value) {
                                  toggleRestaurantsStatus(index);
                                },
                                activeColor: hangryYellow,
                                activeTrackColor: hangryYellow.withOpacity(0.5),
                              ),
                              // Approval toggle
                              IconButton(
                                icon: Icon(
                                  restaurants[index]['isApproved']
                                      ? Icons.verified_user
                                      : Icons.pending,
                                  color: restaurants[index]['isApproved']
                                      ? Colors.blue
                                      : Colors.orange,
                                ),
                                onPressed: () {
                                  toggleApprovalStatus(index);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            navigateToRestaurantDetails(index);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

  // void navigateToEditScreen(int index) {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => RestaurantDetailScreen(
  //         restaurantName: restaurants[index]['name'],
  //         onSave: (details) {
  //           // Aqui você pode salvar os detalhes no Firebase ou em outro local
  //           print('Detalhes salvos: $details');
  //         },
  //       ),
  //     ),
  //   );
  // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin Restaurant'),
//         backgroundColor: hangryYellow,
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Text(
//               'Restaurant List',
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: hangryBlue,
//               ),
//             ),
//           ),
//           Expanded(
//             child: ListView.builder(
//               itemCount: restaurants.length,
//               itemBuilder: (context, index) {
//                 return Card(
//                   margin: EdgeInsets.all(8),
//                   child: ListTile(
//                     title: Text(
//                       restaurants[index]['name'],
//                       style:
//                           TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     trailing: Switch(
//                       value: restaurants[index]['isActive'],
//                       onChanged: (value) {
//                         toggleRestaurantStatus(index);
//                       },
//                       activeColor: Colors.green,
//                     ),
//                     onTap: () {
//                       navigateToEditScreen(index);
//                     },
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantUid;
  final String restaurantName;
  final Function (Map<String, dynamic>) onSave;

  RestaurantDetailScreen({
    required this.restaurantUid,
    required this.restaurantName,
  required this.onSave,
      // required Null Function(dynamic details) onSave});
  });

  @override
  _RestaurantDetailScreenState createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _restaurantData;
  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRestaurantData();
  }

  void _loadRestaurantData() async {
    try {
      final userSnapshot = await _databaseRef.child('users/${widget.restaurantUid}').get();

      if (userSnapshot.exists) {
        Map<dynamic, dynamic> userData = userSnapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> formattedData = {};

        // Format basic restaurant data
        formattedData['name'] = userData['name'] ?? 'Unknown';
        formattedData['email'] = userData['email'] ?? '';
        formattedData['status'] = userData['status'] ?? 'inactive';
        formattedData['isApproved'] = userData['isApproved'] ?? false;
        formattedData['profileImageUrl'] = userData['profileImageUrl'] ?? '';

        // Get profile data if it exists
        if (userData.containsKey('profile') && userData['profile'] is Map) {
          Map<dynamic, dynamic> profileData = userData['profile'] as Map<dynamic, dynamic>;
          formattedData['profile'] = Map<String, dynamic>.from(profileData);
        }

        // Load menu items
        List<Map<String, dynamic>> menuItems = [];
        if (userData.containsKey('menu_counter')) {
          int menuCounter = userData['menu_counter'] as int? ?? 0;

          for (int i = 1; i <= menuCounter; i++) {
            String itemKey = 'item$i';
            if (userData.containsKey(itemKey) && userData[itemKey] is Map) {
              Map<dynamic, dynamic> itemData = userData[itemKey] as Map<dynamic, dynamic>;
              menuItems.add({
                'key': itemKey,
                'name': itemData['name'] ?? 'Unknown Item',
                'price': itemData['price'] ?? 0,
                'description': itemData['description'] ?? '',
                'imageUrl': itemData['imageUrl'] ?? '',
                'category': itemData['category'] ?? 'Other',
                'availability': itemData['availability'] ?? 'No',
              });
            }
          }
        }

        setState(() {
          _restaurantData = formattedData;
          _menuItems = menuItems;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Restaurant data not found');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading restaurant data: $error');
    }
  }

  // void _loadRestaurantData() async {
  //   final snapshot =
  //       await _databaseRef.child('restaurants/${widget.restaurantName}').get();
  //   if (snapshot.exists) {
  //     setState(() {
  //       _restaurantData = Map<String, dynamic>.from(snapshot.value as Map);
  //     });
  //   } else {
  //     print('Restaurant data not found');
  //   }
  // }

  // @override
  // void initState() {
  //   super.initState();
  //   _loadRestaurantData();
  // }
  void _toggleApprovalStatus() async {
    if (_restaurantData == null) return;

    bool currentStatus = _restaurantData!['isApproved'] == true;
    bool newStatus = !currentStatus;

    try {
      await _databaseRef.child('users/${widget.restaurantUid}').update({
        'isApproved': newStatus,
      });

      setState(() {
        _restaurantData!['isApproved'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restaurant ${newStatus ? 'approved' : 'approval revoked'}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update approval status: $error')),
      );
    }
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
            onPressed: () {},
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
