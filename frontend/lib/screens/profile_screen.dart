import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'register_biometric_screen.dart';


class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await AuthService.getSavedUser() ?? await AuthService.getCurrentUser();
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profil')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _user?.profilePictureUrl != null
                ? NetworkImage(_user!.profilePictureUrl!)
                : null,
            child: _user?.profilePictureUrl == null
                ? Icon(Icons.person, size: 50)
                : null,
          ),
          SizedBox(height: 20),
          Text('Nom d\'utilisateur: ${_user?.username ?? "N/A"}'),
          Text('Email: ${_user?.email ?? "N/A"}'),
          Text('Téléphone: ${_user?.phoneNumber ?? "Non renseigné"}'),
          SizedBox(height: 20),
          FutureBuilder<bool>(
            future: AuthService.isBiometricRegistered(),
            builder: (context, snapshot) {
              if (snapshot.data == false) {
                return ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegisterBiometricScreen(),
                    ),
                  ),
                  child: Text('Enregistrer empreinte biométrique'),
                );
              }
              return Container();
            },
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => AuthService.logout().then((_) {
              Navigator.pushReplacementNamed(context, '/');
            }),
            child: Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}