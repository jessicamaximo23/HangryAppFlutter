import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdminDriverScreen extends StatefulWidget {
  @override
  _AdminDriverScreenState createState() => _AdminDriverScreenState();
}

class _AdminDriverScreenState extends State<AdminDriverScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver License Management'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref("driver_licenses").onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(child: Text('No driver licenses found.'));
          } else {
            final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            final licenses = data.entries.toList();

            return ListView.builder(
              itemCount: licenses.length,
              itemBuilder: (context, index) {
                final licenseData = licenses[index].value as Map<dynamic, dynamic>;
                final userId = licenses[index].key;
                final driverLicenseUrl = licenseData['driverLicenseUrl'];
                final email = licenseData['email'];
                final fullName = licenseData['fullName'];
                final phoneNumber = licenseData['phoneNumber'];
                final status = licenseData['status'];

                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: Image.network(driverLicenseUrl), // Exibe a foto da carteira de motorista
                    title: Text(fullName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email: $email'),
                        Text('Phone: $phoneNumber'),
                        Text('Status: $status'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => _updateDriverLicenseStatus(userId, 'approved'),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => _updateDriverLicenseStatus(userId, 'rejected'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<void> _updateDriverLicenseStatus(String userId, String status) async {
    try {
      // Atualiza o status no banco de dados
      DatabaseReference driverLicenseRef = FirebaseDatabase.instance.ref("driver_licenses/$userId");
      await driverLicenseRef.update({
        'status': status,
      });

      // Atualiza o status no perfil do usuário
      DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$userId/profile");
      await userRef.update({
        'status': status,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Driver license status updated to $status')),
      );
    } catch (e) {
      print("Error updating status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }
}