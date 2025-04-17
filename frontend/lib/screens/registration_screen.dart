import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../services/auth_service.dart';
import '../models/user.dart';

class RegistrationScreen extends StatefulWidget {

  const RegistrationScreen({Key? key}) : super(key: key);
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _profileImage;
  bool _isLoading = false;
  bool _isDarkMode = false;

  // Couleurs dynamiques
  Color get _primaryColor => _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F9FF);
  Color get _secondaryColor => _isDarkMode ? const Color(0xFF1A237E) : const Color(0xFF1565C0);
  Color get _accentColor => _isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF0D47A1);
  Color get _textColor => _isDarkMode ? Colors.white : Colors.grey[900]!;
  Color get _secondaryTextColor => _isDarkMode ? Colors.white70 : Colors.grey[800]!;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Les mots de passe ne correspondent pas')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneController.text.trim(),
        profilePicture: _profileImage,
      );

     
      
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      appBar: AppBar(
        title: const Text('INSCRIPTION', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: _secondaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.wb_sunny : Icons.nightlight_round, 
                     color: Colors.white),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: _secondaryColor.withOpacity(0.2),
                  backgroundImage: _profileImage != null 
                      ? FileImage(_profileImage!) 
                      : null,
                  child: _profileImage == null 
                      ? Icon(Icons.add_a_photo, size: 40, color: _textColor) 
                      : null,
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Nom d\'utilisateur*',
                  labelStyle: TextStyle(color: _textColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _secondaryTextColor),
                  ),
                ),
                style: TextStyle(color: _textColor),
                validator: (value) => value!.isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email*',
                  labelStyle: TextStyle(color: _textColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _secondaryTextColor),
                  ),
                ),
                style: TextStyle(color: _textColor),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => 
                    !value!.contains('@') ? 'Email invalide' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Mot de passe*',
                  labelStyle: TextStyle(color: _textColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _secondaryTextColor),
                  ),
                ),
                style: TextStyle(color: _textColor),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Champ obligatoire';
                  if (value.length < 8) return '8+ caractères requis';
                  if (!value.contains(RegExp(r'[A-Z]'))) return '1 majuscule minimum';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe*',
                  labelStyle: TextStyle(color: _textColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _secondaryTextColor),
                  ),
                ),
                style: TextStyle(color: _textColor),
                obscureText: true,
                validator: (value) => 
                    value != _passwordController.text ? 'Ne correspond pas' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Téléphone (optionnel)',
                  labelStyle: TextStyle(color: _textColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _secondaryTextColor),
                  ),
                ),
                style: TextStyle(color: _textColor),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading 
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'S\'INSCRIRE',
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
                    : () => Navigator.pop(context),
                child: Text(
                  'Déjà un compte ? Se connecter',
                  style: TextStyle(color: _accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}