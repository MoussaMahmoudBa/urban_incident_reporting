import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class UserService {
  static const _storage = FlutterSecureStorage();
  static const String _baseUrl = "http://10.0.2.2:8000/api/users/";

  static Future<List<User>> getAllUsers({bool excludeAdmins = false}) async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception('Non authentifié');

      final uri = excludeAdmins 
          ? Uri.parse('$_baseUrl?exclude_admins=true')
          : Uri.parse(_baseUrl);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      }
      throw Exception('Failed to load users: ${response.statusCode}');
    } catch (e) {
      throw Exception('Erreur: $e');
    }
  }

  static Future<List<User>> getNonAdminUsers() async {
    return getAllUsers(excludeAdmins: true);
  }

  static Future<void> toggleUserStatus(int userId, bool isActive) async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception('Non authentifié');

      final response = await http.patch(
        Uri.parse('$_baseUrl$userId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'is_active': isActive}),
      );

      if (response.statusCode != 200) {
        throw Exception('Échec de la mise à jour: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur: $e');
    }
  }

  static Future<User?> getUserById(int userId) async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception('Non authentifié');

      final response = await http.get(
        Uri.parse('$_baseUrl$userId/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      throw Exception('Erreur: $e');
    }
  }

  static Future<int> getIncidentCountForUser(int userId) async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception('Non authentifié');

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/incidents/?user_id=$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.length;
      }
      return 0;
    } catch (e) {
      print('Erreur récupération nombre incidents: $e');
      return 0;
    }
  }
}