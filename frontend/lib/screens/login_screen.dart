import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import 'registration_screen.dart'; // Import de l'écran d'inscription

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final BiometricAuthService _bioAuth = BiometricAuthService();
  bool _isBiometricAvailable = false;
  bool _isBiometricReady = false;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
    _checkLoginStatus();
  }

  Future<void> _initBiometric() async {
    final isAvailable = await _bioAuth.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        if (isAvailable) _checkBiometricRegistration();
      });
    }
  }

  Future<void> _checkBiometricRegistration() async {
    final isRegistered = await AuthService.isBiometricRegistered();
    if (mounted) {
      setState(() => _isBiometricReady = isRegistered);
    }
  }

  Future<void> _checkLoginStatus() async {
    final token = await AuthService.getAccessToken();
    if (mounted) {
      setState(() => _isLoggedIn = token != null);
    }
  }

  Future<void> _loginWithCredentials() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.login(
        _usernameController.text,
        _passwordController.text,
      );
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connecté avec succès!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _registerBiometric() async {
    setState(() => _isLoading = true);
    try {
      final auth = await _bioAuth.authenticate();
      if (!auth) throw Exception('Authentification biométrique requise');

      await AuthService.registerBiometric();
      
      if (mounted) {
        setState(() => _isBiometricReady = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Empreinte enregistrée avec succès!')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() => _isLoading = true);
    try {
      final auth = await _bioAuth.authenticate();
      if (!auth) throw Exception('Authentification biométrique annulée');

      final success = await AuthService.biometricLogin();
      if (!success) throw Exception('Échec de la validation serveur');

      if (mounted) {
        setState(() => _isLoggedIn = true);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _isBiometricReady = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connexion'),
        actions: [
          if (_isLoggedIn)
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _isLoading ? null : _logout,
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (!_isLoggedIn) ...[
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(labelText: 'Nom d\'utilisateur'),
                  ),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: 'Mot de passe'),
                    obscureText: true,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithCredentials,
                    child: Text('Se connecter'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  SizedBox(height: 10),
                  // Ajout du bouton "Créer un compte"
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegistrationScreen(),
                              ),
                            ),
                    child: Text(
                      'Créer un compte',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
                if (_isBiometricAvailable) ...[
                  SizedBox(height: 20),
                  if (_isBiometricReady)
                    ElevatedButton.icon(
                      icon: Icon(Icons.fingerprint),
                      label: Text('Connexion biométrique'),
                      onPressed: _isLoading ? null : _loginWithBiometrics,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                  if (!_isBiometricReady && _isLoggedIn) ...[
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _registerBiometric,
                      child: Text('Enregistrer empreinte digitale'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Enregistrez votre empreinte pour une connexion plus rapide',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (_isLoading)
            Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}