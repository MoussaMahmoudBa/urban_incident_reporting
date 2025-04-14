import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/incident.dart';
import '../models/incident_hive.dart';
import 'auth_service.dart'; // Ajout de cet import

class IncidentService {
  static const _storage = FlutterSecureStorage();
  static const String _baseUrl = "http://10.0.2.2:8000/api/incidents/";
  static const String _boxName = 'incidentsBox';

  static Future<void> syncPendingIncidents() async {
    final connectivity = Connectivity();
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    final box = await Hive.openBox<IncidentHive>(_boxName);
    final unsyncedIncidents = box.values.where((incident) => !incident.isSynced);

    for (final incident in unsyncedIncidents) {
      try {
        await _sendIncidentToServer(incident);
        incident.isSynced = true;
        final key = box.keyAt(box.values.toList().indexOf(incident));
        await box.put(key, incident);
      } catch (e) {
        print('Échec de la synchro pour un incident: $e');
      }
    }
  }

  static Future<List<Incident>> getUserIncidents() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception('Non authentifié');

      final response = await http.get(
        Uri.parse('$_baseUrl?user=me'), 
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Incident.fromJson(json)).toList();
      }
      throw Exception('Failed to load incidents');
    } catch (e) {
      final box = await Hive.openBox<IncidentHive>(_boxName);
      final currentUserId = await _getCurrentUserId();
      
      // On filtre aussi les incidents locaux par utilisateur
      return box.values
        .where((incident) => incident.userId == currentUserId)
        .map(Incident.fromHive)
        .toList();
    }
  }

  static Future<int?> _getCurrentUserId() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/users/me/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        return userData['id']; // Retourne l'ID de l'utilisateur
      }
      return null;
    } catch (e) {
      print('Erreur récupération userId: $e');
      return null;
    }
  }

  static Future<void> reportIncident({
    required String incidentType,
    required String description,
    required String? imagePath,
    required String location,
    String? audioPath,
  }) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('Utilisateur non identifié');

      final incident = IncidentHive(
        incidentType: incidentType,
        description: description,
        imagePath: imagePath,
        location: location,
        audioPath: audioPath,
        userId: userId,
      );

      final box = await Hive.openBox<IncidentHive>(_boxName);
      await box.add(incident);
      
      // Tenter la synchronisation immédiate
      await syncPendingIncidents();
      
    } catch (e) {
      print('Erreur lors du signalement: $e');
      rethrow;
    }
  }

  static Future<void> _sendIncidentToServer(IncidentHive incident) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('Non authentifié');

    final request = http.MultipartRequest('POST', Uri.parse(_baseUrl))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['incident_type'] = incident.incidentType
      ..fields['description'] = incident.description
      ..fields['location'] = incident.location;

    if (incident.imagePath != null && File(incident.imagePath!).existsSync()) {
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        incident.imagePath!,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    if (incident.audioPath != null && File(incident.audioPath!).existsSync()) {
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        incident.audioPath!,
        contentType: MediaType('audio', 'mpeg'),
      ));
    }

    final response = await request.send();
    if (response.statusCode != 201) {
      throw Exception('Échec de l\'envoi: ${response.statusCode}');
    }
  }

   static Future<List<Incident>> getAllIncidents() async {
  try {
    final token = await _storage.read(key: 'access_token');
    if (token == null) throw Exception('Non authentifié');

    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/incidents/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('Réponse brute: ${response.body}'); // Debug crucial

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print('Nombre d\'incidents reçus: ${data.length}');
      return data.map((json) => Incident.fromJson(json)).toList();
    }
    throw Exception('Erreur serveur: ${response.statusCode}');
  } catch (e) {
    print('ERREUR FATALE dans getAllIncidents: $e');
    rethrow;
  }
}
}