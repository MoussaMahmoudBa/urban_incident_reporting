import 'dart:developer';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:mime/mime.dart';

class AuthService {
  static final _storage = FlutterSecureStorage();
  static const String baseUrl = "http://10.0.2.2:8000/api/";
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'current_user';
  static const _biometricTokenKey = 'biometric_token';
  static const _biometricRegisteredKey = 'biometric_registered';
  static const _usernameKey = 'current_username'; // Nouvelle clé pour le username


  // Nouvelle méthode pour vérifier et rafraîchir le token
  static Future<String?> _getValidToken() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) return null;

      // Décodage basique du token pour vérifier l'expiration
      final parts = accessToken.split('.');
      if (parts.length != 3) return accessToken;

      final payload = json.decode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(parts[1]),
          ),
        ),
      );

      final exp = payload['exp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Si le token expire dans moins de 5 minutes, on le rafraîchit
      if (exp > now + 300) {
        return accessToken;
      }

      log('Token expiré ou sur le point d\'expirer, rafraîchissement en cours...');
      return await refreshToken();
    } catch (e) {
      log('Erreur lors de la vérification du token: $e');
      return null;
    }
  }

  // Nouvelle méthode pour obtenir les headers avec token valide
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await _getValidToken();
    if (token == null) {
      throw Exception('Session expirée - Veuillez vous reconnecter');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Future<User> login(String username, String password) async {
    try {
      // Étape 1: Authentification
      final authResponse = await http.post(
        Uri.parse('${baseUrl}users/token/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (authResponse.statusCode != 200) {
        throw Exception('Identifiants incorrects');
      }

      final tokens = json.decode(authResponse.body);
      await _saveTokens(tokens);
      await _storage.write(key: _usernameKey, value: username); // Stockage du username

      // Étape 2: Récupération du profil
      final profileResponse = await http.get(
        Uri.parse('${baseUrl}users/me/'),
        headers: await getAuthHeaders(), // Utilisation de la nouvelle méthode
      );

      if (profileResponse.statusCode == 200) {
        return User.fromJson(json.decode(profileResponse.body));
      } else {
        throw Exception('Profil utilisateur introuvable');
      }
    } on SocketException {
      throw Exception('Problème de connexion réseau');
    } catch (e) {
      throw Exception('Erreur de connexion: ${e.toString()}');
    }
  }

  static Future<User> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}users/me/'),
        headers: await getAuthHeaders(), // Utilisation de la nouvelle méthode
      );

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expirée - Veuillez vous reconnecter');
      } else {
        throw Exception('Échec du chargement de l\'utilisateur');
      }
    } catch (e) {
      log('Erreur getCurrentUser: $e');
      rethrow;
    }
  }

  static Future<bool> biometricLogin() async {
    try {
      final token = await _storage.read(key: _biometricTokenKey);
      final username = await _storage.read(key: _usernameKey); // Récupération du username stocké
      
      if (token == null || username == null) {
        throw Exception('Aucun token biométrique ou username enregistré');
      }

      final response = await http.post(
        Uri.parse('${baseUrl}users/biometric-login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'biometric_token': token,
          'username': username,
        }),
      );

      if (response.statusCode == 200) {
        await _saveTokens(json.decode(response.body));
        return true;
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      log('Erreur connexion biométrique: $e');
      rethrow;
    }
  }

  static Future<void> registerBiometric() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken == null) throw Exception('Non authentifié');

      final token = DateTime.now().millisecondsSinceEpoch.toString();
      await _storage.write(key: _biometricTokenKey, value: token);
      await _storage.write(key: _biometricRegisteredKey, value: 'true');
      
      final response = await http.post(
        Uri.parse('${baseUrl}users/register-biometric/'), // Ajout de users/
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'biometric_token': token}),
      );

      if (response.statusCode != 200) {
        throw Exception('Échec de l\'enregistrement: ${response.statusCode}');
      }
    } catch (e) {
      await _storage.delete(key: _biometricTokenKey);
      await _storage.delete(key: _biometricRegisteredKey);
      rethrow;
    }
  }

  static Future<bool> isBiometricRegistered() async {
    final registered = await _storage.read(key: _biometricRegisteredKey);
    return registered == 'true';
  }

  static Future<void> _saveTokens(Map<String, dynamic> tokens) async {
    await _storage.write(key: _accessTokenKey, value: tokens['access']);
    await _storage.write(key: _refreshTokenKey, value: tokens['refresh']);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  static Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _usernameKey); // Suppression du username stocké
  }

  static Future<String> refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        throw Exception('Aucun refresh token disponible');
      }

      final response = await http.post(
        Uri.parse('${baseUrl}token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final tokens = json.decode(response.body);
        await _saveTokens(tokens);
        return tokens['access'];
      } else {
        await logout();
        throw Exception('Échec du rafraîchissement du token');
      }
    } catch (e) {
      await logout();
      rethrow;
    }
  }

  static Future<User?> getSavedUser() async {
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      return User.fromJson(json.decode(userJson));
    }
    return null;
  }

  static Future<void> register({
    required String username,
    required String email,
    required String password,
    String? phoneNumber,
    File? profilePicture,
  }) async {
    try {
      final uri = Uri.parse('${baseUrl}users/register/');
    log('Tentative d\'inscription vers: $uri');  // ✅ Debug
    final request = http.MultipartRequest('POST', uri);
      
      // Headers
      request.headers.addAll({
        'Accept': 'application/json',
      });

      // Champs obligatoires
      request.fields.addAll({
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'password2': password,
      });

      // Champ optionnel
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        request.fields['phone_number'] = phoneNumber.trim();
      }

      // Image de profil
      if (profilePicture != null) {
        final file = await http.MultipartFile.fromPath(
          'profile_picture',
          profilePicture.path,
        );
        request.files.add(file);
      }

      final response = await http.Response.fromStream(await request.send());
      log('Statut: ${response.statusCode}, Body: ${response.body}');  // ✅ Debug

      final responseBody = json.decode(utf8.decode(response.bodyBytes));

if (response.statusCode == 201) {
      final responseData = json.decode(utf8.decode(response.bodyBytes));
      await _saveTokens(responseData['tokens']); // Sauvegarde des tokens
      await _storage.write(key: _usernameKey, value: username);
    } else {
      throw Exception(_parseDjangoErrors(json.decode(utf8.decode(response.bodyBytes))));
    }
    
    } catch (e) {
      log('Erreur inscription: $e');
      rethrow;
    }
  }

  static String? _parseDjangoErrors(Map<String, dynamic> response) {
    if (response.containsKey('non_field_errors')) {
      return response['non_field_errors'].join(', ');
    }
    
    final errors = [];
    response.forEach((key, value) {
      if (value is List) {
        errors.add('${key}: ${value.join(', ')}');
      } else {
        errors.add('${key}: $value');
      }
    });
    
    return errors.join(' | ');
  }
}