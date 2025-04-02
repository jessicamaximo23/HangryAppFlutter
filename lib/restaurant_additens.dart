import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_panel_screen.dart';

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
  String _availability = "Yes";
  File? _image;
  bool _isLoading = false;
  String _selectedCategory = 'Appetizer';

  final List<String> _categories = ['Appetizer', 'Main Dish', 'Dessert'];
  final List<String> _availabilityOptions = ['Yes', 'No'];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late DatabaseReference _databaseRef;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

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

    if (widget.item != null) {
      _nameController.text = widget.item!['name'];
      _priceController.text = widget.item!['price']?.toString() ?? '';
      _descriptionController.text = widget.item!['description'];
      _selectedCategory = widget.item!['category'] ?? 'Appetizer';
      _availability = widget.item!['availability'] ?? 'Yes';
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

  // Future<void> _saveItem() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() {
  //       _isLoading = true;
  //     });
  //
  //     try {
  //       String? imageUrl;
  //       if (_image != null) {
  //         imageUrl = await _uploadImageToStorage(_image!);
  //       } else if (widget.item != null) {
  //         imageUrl = widget.item!['imageUrl'];
  //       }
  //
  //       if (imageUrl != null) {
  //         double price = double.tryParse(_priceController.text) ?? 0.0;
  //
  //         if (widget.item != null && widget.item!['key'] != null) {
  //           String itemKey = widget.item!['key'];
  //
  //           await _databaseRef.child(itemKey).update({
  //             'name': _nameController.text,
  //             'price': price,
  //             'description': _descriptionController.text,
  //             'imageUrl': imageUrl,
  //             'category': _selectedCategory,
  //             'availability': _availability,
  //           });
  //         }
  //         else {
  //           DatabaseReference counterRef = _databaseRef.child('menu_counter');
  //           DataSnapshot counterSnapshot = await counterRef.get();
  //           int counter = (counterSnapshot.value as int? ?? 0) + 1;
  //
  //           String itemKey = 'item$counter';
  //
  //           await _databaseRef.child(itemKey).set({
  //             'name': _nameController.text,
  //             'price': price.toString(),
  //             'description': _descriptionController.text,
  //             'imageUrl': imageUrl,
  //             'category': _selectedCategory,
  //             'availability': _availability,
  //           });
  //
  //           await counterRef.set(counter);
  //         }
  //
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Item saved successfully!')),
  //         );
  //
  //         Navigator.pop(context);
  //       }else {
  //         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select an image for your menu item')),
  //         );
  //       }
  //     } catch (e) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to save item: $e')),
  //       );
  //     } finally {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   }
  // }
  // =====================================================================================================
  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? imageUrl;
        if (_image != null) {
          imageUrl = await _uploadImageToStorage(_image!);
        } else if (widget.item != null && widget.item!['imageUrl'] != null) {
          // Use existing image URL if no new image is selected
          imageUrl = widget.item!['imageUrl'];
        }

        // Only proceed if we have an image URL
        if (imageUrl != null) {
          // Convert price to double for storage
          double price = double.tryParse(_priceController.text) ?? 0.0;

          // If we're editing an existing item
          if (widget.item != null) {
            String itemKey = widget.item!['key'];

            await _databaseRef.child(itemKey).update({
              'name': _nameController.text,
              'price': price,
              'description': _descriptionController.text,
              'imageUrl': imageUrl,
              'category': _selectedCategory,
              'availability': _availability,
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Item updated successfully!')),
            );
          }
          // If we're creating a new item
          else {
            // Get the counter to generate a new item key
            DatabaseReference counterRef = _databaseRef.child('menu_counter');
            DataSnapshot counterSnapshot = await counterRef.get();
            int counter = (counterSnapshot.value as int? ?? 0) + 1;

            // Create the new item key (format: item1, item2, etc.)
            String itemKey = 'item$counter';

            // Save the menu item
            await _databaseRef.child(itemKey).set({
              'name': _nameController.text,
              'price': price,
              'description': _descriptionController.text,
              'imageUrl': imageUrl,
              'category': _selectedCategory,
              'availability': _availability,
            });

            // Update the counter
            await counterRef.set(counter);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Item added successfully!')),
            );
          }

          // Return to the previous screen
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select an image for the menu item')),
          );
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
        title: Text(widget.item == null ? 'Add Item' : 'Edit Item', style: TextStyle(color: Colors.black)),
        backgroundColor: Color(0xFFFCBF49),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black, width: 1.0)),
                ),
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter item name',
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the dish name';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 20),

              // Price field
              Text(
                'Price',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black, width: 1.0)),
                ),
                child: TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    hintText: 'Enter price',
                    prefixText: '\$ ',
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
              ),
              SizedBox(height: 20),

              // Description field
              Text(
                'Description',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black, width: 1.0)),
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Enter description',
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 16),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the description';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 20),

              // Category dropdown
              Text(
                'Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                margin: EdgeInsets.only(top: 10),
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  underline: SizedBox(),
                  icon: Icon(Icons.keyboard_arrow_down),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category, style: TextStyle(fontSize: 18)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    }
                  },
                ),
              ),
              SizedBox(height: 20),

              // Availability dropdown
              Text(
                'Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                margin: EdgeInsets.only(top: 10),
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: _availability,
                  isExpanded: true,
                  underline: SizedBox(),
                  icon: Icon(Icons.keyboard_arrow_down),
                  items: _availabilityOptions.map((String option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option, style: TextStyle(fontSize: 18)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _availability = newValue;
                      });
                    }
                  },
                ),
              ),
              SizedBox(height: 30),

              // Image section
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: _image != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      )
                          : widget.item != null && widget.item!['imageUrl'] != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(widget.item!['imageUrl'], fit: BoxFit.cover),
                      )
                          : Center(
                        child: Icon(Icons.photo_library, size: 80, color: Colors.grey.shade400),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Pick Image button as shown in your design
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _pickImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0A3A52), // Dark blue as in image
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text('Pick Image', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Save Item button as shown in your design
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hangryYellow,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text('Save Item', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
