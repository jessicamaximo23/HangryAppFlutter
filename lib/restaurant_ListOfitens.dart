import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hangry_app_flutter/restaurant_additens.dart';

class Restaurant_ListOfItems extends StatefulWidget {
  @override
  _Restaurant_ListOfItemsState createState() => _Restaurant_ListOfItemsState();
}

class _Restaurant_ListOfItemsState extends State<Restaurant_ListOfItems> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _databaseRef;

  @override
  void initState() {
    super.initState();


    final String? userUid = _auth.currentUser?.uid;

    if (userUid == null) {
      throw Exception("User UID is null. User must be logged in.");
    }


    _databaseRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(userUid)
        .child('menu');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('List of Items', style: TextStyle(color: Colors.black)),
        backgroundColor: Color(0xFFFCBF49),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder(
        stream: _databaseRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            Map<dynamic, dynamic> items = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            List<Map<String, dynamic>> itemList = items.entries.map((entry) {
              return {
                'key': entry.key,
                'name': entry.value['name'],
                'price': entry.value['price'],
                'description': entry.value['description'],
                'imageUrl': entry.value['imageUrl'],
              };
            }).toList();

            return ListView.builder(
              itemCount: itemList.length,
              itemBuilder: (context, index) {
                return _buildListItem(itemList[index]);
              },
            );
          } else {
            return Center(child: Text('No items found.'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Restaurant_addItems()),
          );
        },
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Color(0xFF003049),
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: Image.network(item['imageUrl'], width: 50, height: 50, fit: BoxFit.cover),
        title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['description']),
            Text('\$${item['price']}', style: TextStyle(color: Color(0xFF003049))),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Color(0xFF003049)),
              onPressed: () {
                _navigateToEditItemPage(item);
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _deleteItem(item['key']);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteItem(String key) {
    _databaseRef.child(key).remove().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item deleted successfully!')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item: $error')),
      );
    });
  }

  void _navigateToEditItemPage(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Restaurant_addItems(item: item),
      ),
    );
  }
}