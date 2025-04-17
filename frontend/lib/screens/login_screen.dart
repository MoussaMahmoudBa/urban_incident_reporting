import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import 'registration_screen.dart'; // Import de l'écran d'inscription

class LoginScreen extends StatefulWidget {

  const LoginScreen({Key? key}) : super(key: key);

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
  bool _isDarkMode = false;

  // Couleurs dynamiques
  Color get _primaryColor => _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F9FF);
  Color get _secondaryColor => _isDarkMode ? const Color(0xFF1A237E) : const Color(0xFF1565C0);
  Color get _accentColor => _isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF0D47A1);
  Color get _textColor => _isDarkMode ? Colors.white : Colors.grey[900]!;
  Color get _secondaryTextColor => _isDarkMode ? Colors.white70 : Colors.grey[800]!;

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
    final user = await AuthService.login(
      _usernameController.text,
      _passwordController.text,
    );
    
    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
      });
      
      // Redirection basée sur le rôle
      if (user.role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
      
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
      backgroundColor: _primaryColor,
      appBar: AppBar(
        title: const Text('CONNEXION', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: _secondaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.wb_sunny : Icons.nightlight_round, 
                     color: Colors.white),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _isLoading ? null : _logout,
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _primaryColor,
                  _isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE3F2FD),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isLoggedIn) ...[
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Nom d\'utilisateur',
                        labelStyle: TextStyle(color: _textColor),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _secondaryTextColor),
                        ),
                      ),
                      style: TextStyle(color: _textColor),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        labelStyle: TextStyle(color: _textColor),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _secondaryTextColor),
                        ),
                      ),
                      obscureText: true,
                      style: TextStyle(color: _textColor),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loginWithCredentials,
                      child: Text(
                        'SE CONNECTER',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
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
                          color: _accentColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                  if (_isBiometricAvailable) ...[
                    const SizedBox(height: 30),
                    if (_isBiometricReady)
                      ElevatedButton.icon(
                        icon: Icon(Icons.fingerprint, color: Colors.white),
                        label: Text(
                          'Connexion biométrique',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: _isLoading ? null : _loginWithBiometrics,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    if (!_isBiometricReady && _isLoggedIn) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _registerBiometric,
                        child: Text(
                          'Enregistrer empreinte',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enregistrez votre empreinte pour une connexion plus rapide',
                        style: TextStyle(color: _secondaryTextColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
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