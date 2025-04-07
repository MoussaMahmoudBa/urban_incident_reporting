import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/incident_service.dart';
import '../models/incident.dart';
import '../models/incident_hive.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  Incident? _selectedIncident;
  bool _showMap = false;
  bool _isSyncing = false;
  LatLng _initialCenter = LatLng(48.8566, 2.3522); // Paris par défaut

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
      
      // Fusionne et élimine les doublons
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
      return _initialCenter; // Retourne la position par défaut en cas d'erreur
    }
  }

  Future<void> _syncIncidents() async {
    setState(() => _isSyncing = true);
    try {
      await IncidentService.syncPendingIncidents();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synchronisation réussie!')),
      );
      await _loadIncidents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de synchronisation: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Widget _buildIncidentIcon(Incident incident) {
    if (incident.photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          incident.photoUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => 
            Icon(Icons.broken_image, color: Colors.grey),
          loadingBuilder: (context, child, loadingProgress) =>
            loadingProgress == null ? child : CircularProgressIndicator(),
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
    setState(() => _selectedIncident = incident);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails complet', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (incident.photoUrl != null)
                  Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                    incident.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      Text('Image non disponible', style: TextStyle(color: Colors.grey)),
            ],
                      
          ),
    ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(child: CircularProgressIndicator());
      },
    ),
  ),
  ),
              SizedBox(height: 16),
              _buildDetailRow('Type', _getTypeLabel(incident.incidentType)),
              SizedBox(height: 8),
              _buildDetailRow('Description', incident.description),
              SizedBox(height: 8),
              _buildDetailRow('Localisation', incident.location),
              SizedBox(height: 8),
              _buildDetailRow('Date', incident.formattedDate),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('Statut: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: incident.isSynced ? Colors.green[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      incident.isSynced ? 'Synchronisé' : 'En attente',
                      style: TextStyle(
                        color: incident.isSynced ? Colors.green[800] : Colors.orange[800],
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
            child: Text('Fermer'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Ouvrir dans Maps'),
            onPressed: () {
              Navigator.pop(context);
              _openMaps(incident.location);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text(value),
        Divider(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique des incidents'),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncIncidents,
            tooltip: 'Synchroniser',
          ),
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
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
      body: _showMap ? _buildMap() : _buildList(),
      floatingActionButton: _selectedIncident != null && _showMap
          ? FloatingActionButton(
              child: Icon(Icons.directions),
              onPressed: () => _openMaps(_selectedIncident!.location),
              tooltip: 'Itinéraire',
            )
          : null,
    );
  }

  Widget _buildMap() {
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
          Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<Incident>>(
      future: _loadAllIncidents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text('Erreur de chargement'),
                TextButton(
                  onPressed: _loadIncidents,
                  child: Text('Réessayer'),
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
                Icon(Icons.history, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucun incident signalé'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadIncidents,
          child: ListView.builder(
            itemCount: incidents.length,
            itemBuilder: (context, index) {
              final incident = incidents[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                child: ListTile(
                  leading: _buildIncidentIcon(incident),
                  title: Text(
                    _getTypeLabel(incident.incidentType),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.description.length > 30 
                          ? '${incident.description.substring(0, 30)}...' 
                          : incident.description,
                      ),
                      SizedBox(height: 4),
                      Text(incident.formattedDate),
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
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}