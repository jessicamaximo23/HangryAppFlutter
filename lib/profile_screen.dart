import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Information'),
        backgroundColor: Color(0xFFFCBF49),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage('images/assets/profile_picture.png'), // Substitua pelo caminho da imagem do perfil
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'John Doe', // Exemplo de nome do usuário
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003049),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileItem(context, Icons.person, 'Profile Information'),
            _buildProfileItem(context, Icons.location_on, 'Location'),
            _buildProfileItem(context, Icons.settings, 'App Settings'),
            _buildProfileItem(context, Icons.notifications, 'Notifications'),
            _buildProfileItem(context, Icons.delivery_dining, 'Delivery Driver'),
            _buildProfileItem(context, Icons.admin_panel_settings, 'Admin'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF003049)),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        // Adicione a navegação ou ação desejada aqui
      },
    );
  }
}