// lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'incident_service.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  static Future<void> init() async {
    // Écoute les changements de connexion
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        await IncidentService.syncPendingIncidents();
      }
    });
  }

  static Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}