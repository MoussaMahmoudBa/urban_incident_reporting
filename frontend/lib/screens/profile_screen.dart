import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'register_biometric_screen.dart';
import '../theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFIL', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: themeProvider.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round, color: Colors.white),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              themeProvider.backgroundColor,
              themeProvider.isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE3F2FD),
            ],
          ),
        ),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: themeProvider.accentColor,
                ),
              )
            : _buildProfileContent(themeProvider),
      ),
    );
  }

  Widget _buildProfileContent(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: themeProvider.accentColor,
                width: 3,
              ),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: themeProvider.backgroundColor,
              backgroundImage: _user?.profilePictureUrl != null
                  ? NetworkImage(_user!.profilePictureUrl!)
                  : null,
              child: _user?.profilePictureUrl == null
                  ? Icon(Icons.person, size: 60, color: themeProvider.accentColor)
                  : null,
            ),
          ),
          const SizedBox(height: 30),
          _buildProfileCard(
            themeProvider,
            children: [
              _buildProfileItem(
                themeProvider,
                icon: Icons.person,
                label: 'Nom d\'utilisateur',
                value: _user?.username ?? "N/A",
              ),
              const Divider(height: 20),
              _buildProfileItem(
                themeProvider,
                icon: Icons.email,
                label: 'Email',
                value: _user?.email ?? "N/A",
              ),
              const Divider(height: 20),
              _buildProfileItem(
                themeProvider,
                icon: Icons.phone,
                label: 'Téléphone',
                value: _user?.phoneNumber ?? "Non renseigné",
              ),
            ],
          ),
          const SizedBox(height: 30),
          FutureBuilder<bool>(
            future: AuthService.isBiometricRegistered(),
            builder: (context, snapshot) {
              if (snapshot.data == false) {
                return _buildActionButton(
                  themeProvider,
                  icon: Icons.fingerprint,
                  text: 'Enregistrer empreinte biométrique',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegisterBiometricScreen(),
                    ),
                  ),
                );
              }
              return _buildActionButton(
                themeProvider,
                icon: Icons.fingerprint,
                text: 'Authentification biométrique activée',
                onPressed: null,
                isActive: false,
              );
            },
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            themeProvider,
            icon: Icons.logout,
            text: 'Déconnexion',
            onPressed: () => AuthService.logout().then((_) {
              Navigator.pushReplacementNamed(context, '/');
            }),
            isWarning: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ThemeProvider themeProvider, {required List<Widget> children}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: themeProvider.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    ThemeProvider themeProvider, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: themeProvider.accentColor),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: themeProvider.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    ThemeProvider themeProvider, {
    required IconData icon,
    required String text,
    required VoidCallback? onPressed,
    bool isActive = true,
    bool isWarning = false,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isWarning 
            ? Colors.redAccent 
            : isActive ? themeProvider.accentColor : Colors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 3,
        shadowColor: themeProvider.accentColor.withOpacity(0.3),
      ),
      onPressed: onPressed,
    );
  }
}