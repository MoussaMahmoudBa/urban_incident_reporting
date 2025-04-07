import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';

class RegisterBiometricScreen extends StatefulWidget {
  @override
  _RegisterBiometricScreenState createState() => _RegisterBiometricScreenState();
}

class _RegisterBiometricScreenState extends State<RegisterBiometricScreen> {
  final BiometricAuthService _bioAuth = BiometricAuthService();
  bool _isLoading = false;

  Future<void> _registerBiometric() async {
    setState(() => _isLoading = true);
    try {
  final authenticated = await _bioAuth.authenticate();
  if (authenticated) {
    await AuthService.registerBiometric();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Empreinte enregistrée avec succès!')),
      );
      Navigator.pop(context, true);
    }
  }
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
        duration: Duration(seconds: 5),
      ),
    );
  }
}

    final accessToken = await AuthService.getAccessToken();
  if (accessToken == null) {
  throw Exception('Non authentifié - token manquant');
}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activer la biométrie'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fingerprint, size: 80),
                SizedBox(height: 20),
                Text(
                  'Activez l\'authentification biométrique pour une connexion plus rapide',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: Icon(Icons.fingerprint),
                  label: Text('Activer maintenant'),
                  onPressed: _isLoading ? null : _registerBiometric,
                ),
              ],
            ),
          ),
          if (_isLoading)
            Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}