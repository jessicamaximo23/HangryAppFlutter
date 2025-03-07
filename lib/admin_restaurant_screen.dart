import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AdminRestaurantScreen extends StatefulWidget {
  @override
  _AdminRestaurantScreenState createState() => _AdminRestaurantScreenState();
}

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
        title: Text('Admin Driver Screen'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
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
    );
  }
}

// Tela de edição de detalhes do restaurante
class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantName;
  final Function(Map<String, dynamic>) onSave;

  RestaurantDetailScreen({required this.restaurantName, required this.onSave});

  @override
  _RestaurantDetailScreenState createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  String _imageUrl = '';

  // Função para salvar os detalhes
  void _saveDetails() {
    final details = {
      'restaurantName': widget.restaurantName,
      'price': _priceController.text,
      'details': _detailsController.text,
      'imageUrl': _imageUrl,
    };
    widget.onSave(details);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.restaurantName}'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Price',
                hintText: 'Enter the price',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              decoration: InputDecoration(
                labelText: 'Details',
                hintText: 'Enter the details',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Aqui você pode adicionar a lógica para carregar uma imagem
                setState(() {
                  _imageUrl = 'https://via.placeholder.com/150'; // URL de exemplo
                });
              },
              child: Text('Upload Image'),
            ),
            SizedBox(height: 16),
            if (_imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: _imageUrl,
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => Icon(Icons.error),
                height: 150,
              ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveDetails,
              child: Text('Save Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}