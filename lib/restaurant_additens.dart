import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class Restaurant_addItems extends StatefulWidget {
  final Map<String, dynamic>? item;

  Restaurant_addItems({this.item});

  @override
  _Restaurant_addItemsState createState() => _Restaurant_addItemsState();
}

class _Restaurant_addItemsState extends State<Restaurant_addItems> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _image;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _databaseRef;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Obtém o UID do usuário logado
    final String? userUid = _auth.currentUser?.uid;

    if (userUid == null) {
      throw Exception("User UID is null. User must be logged in.");
    }

    // Cria a referência do banco de dados para o menu do usuário logado
    _databaseRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(userUid)
        .child('menu');

    // Preenche os campos se estiver editando um item existente
    if (widget.item != null) {
      _nameController.text = widget.item!['name'];
      _priceController.text = widget.item!['price'];
      _descriptionController.text = widget.item!['description'];
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  Future<String> _uploadImageToStorage(File image) async {
    try {
      final storageRef = _storage.ref().child('menu_images/${DateTime.now().toString()}');
      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? imageUrl;
        if (_image != null) {
          imageUrl = await _uploadImageToStorage(_image!);
        } else if (widget.item != null) {
          imageUrl = widget.item!['imageUrl'];
        }

        if (imageUrl != null) {
          // Verifica se já existe um item para determinar o próximo nome
          final DatabaseEvent snapshot = await _databaseRef.once();
          final Map<dynamic, dynamic>? items = snapshot.snapshot.value as Map<dynamic, dynamic>?;
          int itemCount = items?.length ?? 0;

          String itemKey = 'item${itemCount + 1}';

          if (widget.item != null) {

            await _databaseRef.child(widget.item!['key']).update({
              'name': _nameController.text,
              'price': _priceController.text,
              'description': _descriptionController.text,
              'imageUrl': imageUrl,
            });
          } else {

            await _databaseRef.child(itemKey).set({
              'name': _nameController.text,
              'price': _priceController.text,
              'description': _descriptionController.text,
              'imageUrl': imageUrl,
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item saved successfully!')),
          );

          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save item: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Menu Creation' : 'Edit Item', style: TextStyle(color: Colors.black)),
        backgroundColor: Color(0xFFFCBF49),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Dish Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the dish name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              _image == null && widget.item == null
                  ? Text('No image selected.')
                  : _image != null
                  ? Image.file(_image!, height: 150)
                  : Image.network(widget.item!['imageUrl'], height: 150),
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFCBF49),
                ),
                child: Text('Pick Image', style: TextStyle(color: Colors.black)),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFCBF49), // Botão amarelo
                ),
                child: Text('Submit', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}