import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/incident.dart';
import '../models/incident_hive.dart';

class IncidentService {
  static const _storage = FlutterSecureStorage();
  static const String _baseUrl = "http://127.0.0.1:8000/api/incidents/";
  static const String _boxName = 'incidentsBox';

  // Nouvelle méthode pour synchroniser les incidents en attente
 static Future<void> syncPendingIncidents() async {
  final connectivity = Connectivity();
  final connectivityResult = await connectivity.checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) return;

  final box = await Hive.openBox<IncidentHive>(_boxName);
  final unsyncedIncidents = Map.from(box.toMap()).entries.where((entry) => !entry.value.isSynced);

  for (final entry in unsyncedIncidents) {
    try {
      await _sendIncidentToServer(entry.value);
      entry.value.isSynced = true;
      await box.put(entry.key, entry.value); // Utilise la clé de l'entrée
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
        Uri.parse(_baseUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Incident.fromJson(json)).toList();
      }
      throw Exception('Failed to load incidents');
    } catch (e) {
      final box = await Hive.openBox<IncidentHive>(_boxName);
      return box.values.map((hiveIncident) => Incident.fromHive(hiveIncident)).toList();
    }
  }

  static Future<void> reportIncident({
    required String incidentType,
    required String description,
    required String? imagePath,
    required String location,
    String? audioPath,
  }) async {
    final incident = IncidentHive(
      incidentType: incidentType,
      description: description,
      imagePath: imagePath,
      location: location,
      audioPath: audioPath,
    );

    final box = await Hive.openBox<IncidentHive>(_boxName);
    await box.add(incident);

    // Tente de synchroniser immédiatement si connecté
    await syncPendingIncidents();
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
      final file = await http.MultipartFile.fromPath(
        'photo',
        incident.imagePath!,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(file);
    }

    if (incident.audioPath != null && File(incident.audioPath!).existsSync()) {
    final audioFile = await http.MultipartFile.fromPath(
      'audio',
      incident.audioPath!,
      contentType: MediaType('audio', 'mpeg'),
    );
    request.files.add(audioFile);
  }

    final response = await request.send();
    if (response.statusCode != 201) {
      throw Exception('Échec de l\'envoi au serveur: ${response.statusCode}');
    }
  }
}