import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/incident_service.dart';
import '../models/incident.dart';
import '../models/incident_hive.dart';
import '../theme_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  Incident? _selectedIncident;
  bool _showMap = false;
  bool _isSyncing = false;
  LatLng _initialCenter = const LatLng(48.8566, 2.3522);

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    final incidents = await _loadAllIncidents();
    _updateMarkers(incidents);
  }

  Future<List<Incident>> _loadAllIncidents() async {
    try {
      final onlineIncidents = await IncidentService.getUserIncidents();
      final box = await Hive.openBox<IncidentHive>('incidentsBox');
      final localIncidents = box.values.map((i) => Incident.fromHive(i)).toList();
      
      final allIncidents = [...onlineIncidents, ...localIncidents.where((i) => !i.isSynced)];
      return allIncidents.fold<List<Incident>>([], (list, incident) {
        if (!list.any((i) => 
            i.description == incident.description && 
            i.location == incident.location &&
            i.incidentType == incident.incidentType)) {
          list.add(incident);
        }
        return list;
      });
    } catch (e) {
      print('Erreur chargement incidents: $e');
      return [];
    }
  }

  void _updateMarkers(List<Incident> incidents) {
    setState(() {
      _markers.clear();
      _markers.addAll(incidents.map((incident) {
        final latLng = _parseLocation(incident.location);
        return Marker(
          width: 40,
          height: 40,
          point: latLng,
          child: GestureDetector(
            onTap: () => _showIncidentDetails(incident),
            child: Icon(
              Icons.location_pin,
              color: incident.isSynced ? Colors.green : Colors.orange,
              size: 40,
            ),
          ),
        );
      }));

      if (_markers.isNotEmpty) {
        _initialCenter = _markers.first.point;
        if (_showMap) {
          _mapController.move(_initialCenter, 12.0);
        }
      }
    });
  }

  LatLng _parseLocation(String location) {
    try {
      final parts = location.split(',');
      return LatLng(double.parse(parts[0]), double.parse(parts[1]));
    } catch (e) {
      return _initialCenter;
    }
  }

  Future<void> _syncIncidents() async {
    setState(() => _isSyncing = true);
    try {
      await IncidentService.syncPendingIncidents();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronisation réussie!'),
        ),
      );
      await _loadIncidents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de synchronisation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _openMaps(String location) async {
    try {
      final latLng = _parseLocation(location);
      final url = 'https://www.google.com/maps/search/?api=1&query=${latLng.latitude},${latLng.longitude}';
      
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Impossible d\'ouvrir Google Maps';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildIncidentIcon(Incident incident) {
    if (incident.photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: incident.photoUrl!.startsWith('http')
          ? Image.network(
              incident.photoUrl!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.broken_image, color: Colors.grey),
              loadingBuilder: (context, child, loadingProgress) =>
                loadingProgress == null ? child : const CircularProgressIndicator(),
            )
          : Image.file(
              File(incident.photoUrl!),
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.broken_image, color: Colors.grey),
            ),
      );
    }
    return Icon(
      incident.isSynced ? Icons.cloud_done : Icons.cloud_off,
      color: incident.isSynced ? Colors.green : Colors.orange,
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'fire': return 'Incendie';
      case 'accident': return 'Accident';
      case 'theft': return 'Vol';
      default: return 'Autre';
    }
  }

  void _showIncidentDetails(Incident incident) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.cardColor,
        title: Text(
          'Détails complet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (incident.photoUrl != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: incident.photoUrl!.startsWith('http')
                      ? Image.network(
                          incident.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                Text(
                                  'Image non disponible',
                                  style: TextStyle(color: themeProvider.textColor),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Image.file(
                          File(incident.photoUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                Text(
                                  'Image non disponible',
                                  style: TextStyle(color: themeProvider.textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Type: ${_getTypeLabel(incident.incidentType)}',
                style: TextStyle(color: themeProvider.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Description: ${incident.description}',
                style: TextStyle(color: themeProvider.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Localisation: ${incident.location}',
                style: TextStyle(color: themeProvider.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${incident.formattedDate}',
                style: TextStyle(color: themeProvider.textColor),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Statut: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: incident.isSynced 
                        ? Colors.green.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.2)
                        : Colors.orange.withOpacity(themeProvider.isDarkMode ? 0.3 : 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      incident.isSynced ? 'Synchronisé' : 'En attente',
                      style: TextStyle(
                        color: incident.isSynced ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Fermer',
              style: TextStyle(color: themeProvider.accentColor),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              'Ouvrir dans Maps',
              style: TextStyle(color: themeProvider.accentColor),
            ),
            onPressed: () {
              Navigator.pop(context);
              _openMaps(incident.location);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des incidents', style: TextStyle(color: Colors.white)),
        backgroundColor: themeProvider.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round, color: Colors.white),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: _isSyncing ? null : _syncIncidents,
            tooltip: 'Synchroniser',
          ),
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map, color: Colors.white),
            onPressed: () {
              setState(() => _showMap = !_showMap);
              if (_showMap && _markers.isNotEmpty) {
                _mapController.move(_markers.first.point, 12.0);
              }
            },
            tooltip: _showMap ? 'Vue liste' : 'Vue carte',
          ),
        ],
      ),
      backgroundColor: themeProvider.backgroundColor,
      body: _showMap ? _buildMap(themeProvider) : _buildList(themeProvider),
      floatingActionButton: _selectedIncident != null && _showMap
          ? FloatingActionButton(
              backgroundColor: themeProvider.accentColor,
              child: const Icon(Icons.directions, color: Colors.white),
              onPressed: () => _openMaps(_selectedIncident!.location),
              tooltip: 'Itinéraire',
            )
          : null,
    );
  }

  Widget _buildMap(ThemeProvider themeProvider) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 12.0,
            onTap: (_, __) => setState(() => _selectedIncident = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(markers: _markers),
          ],
        ),
        if (_isSyncing)
          Center(
            child: CircularProgressIndicator(
              color: themeProvider.accentColor,
            ),
          ),
      ],
    );
  }

  Widget _buildList(ThemeProvider themeProvider) {
    return FutureBuilder<List<Incident>>(
      future: _loadAllIncidents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: themeProvider.accentColor,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erreur de chargement',
                  style: TextStyle(color: themeProvider.textColor),
                ),
                TextButton(
                  onPressed: _loadIncidents,
                  child: Text(
                    'Réessayer',
                    style: TextStyle(color: themeProvider.accentColor),
                  ),
                ),
              ],
            ),
          );
        }

        final incidents = snapshot.data ?? [];
        
        if (incidents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: themeProvider.textColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun incident signalé',
                  style: TextStyle(color: themeProvider.textColor),
                ),
              ],
            ),
          );
        }

      return RefreshIndicator(
        onRefresh: _loadIncidents,
        color: themeProvider.accentColor,
        child: ListView.builder(
          itemCount: incidents.length,
          itemBuilder: (context, index) {
            final incident = incidents[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              elevation: 2,
              color: themeProvider.cardColor,
              child: ListTile(
                leading: _buildIncidentIcon(incident),
                title: Text(
                  _getTypeLabel(incident.incidentType),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.description.length > 30 
                        ? '${incident.description.substring(0, 30)}...' 
                        : incident.description,
                      style: TextStyle(color: themeProvider.textColor.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      incident.formattedDate,
                      style: TextStyle(color: themeProvider.textColor.withOpacity(0.6)),
                    ),
                  ],
                ),
                trailing: Icon(
                  incident.isSynced ? Icons.cloud_done : Icons.cloud_off,
                  color: incident.isSynced ? Colors.green : Colors.orange,
                ),
                onTap: () => _showIncidentDetails(incident),
              ),
            );
          },
        ),
      );
    },
  );
}
}

