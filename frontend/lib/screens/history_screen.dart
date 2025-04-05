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
  LatLng _initialCenter = LatLng(48.8566, 2.3522); // Position par défaut (Paris)

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    final incidents = await _loadAllIncidents();
    setState(() {
      _markers.clear();
      _markers.addAll(incidents.map((incident) {
        final latLng = _parseLocation(incident.location);
        return Marker(
          width: 40,
          height: 40,
          point: latLng,
          child: Icon(
            Icons.location_pin,
            color: incident.isSynced ? Colors.green : Colors.orange,
            size: 40,
          ),
        );
      }));

      // Mettre à jour le centre initial si des marqueurs existent
      if (_markers.isNotEmpty) {
        _initialCenter = _markers.first.point;
        _mapController.move(_initialCenter, 12.0);
      }
    });
  }

  LatLng _parseLocation(String location) {
    final parts = location.split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }

  Future<List<Incident>> _loadAllIncidents() async {
    final onlineIncidents = await IncidentService.getUserIncidents();
    final box = await Hive.openBox<IncidentHive>('incidentsBox');
    final localIncidents = box.values.map((i) => Incident.fromHive(i)).toList();
    return [...onlineIncidents, ...localIncidents.where((i) => !i.isSynced)];
  }

  Widget _buildIncidentIcon(Incident incident) {
    if (incident.photoUrl != null) {
      return Image.network(incident.photoUrl!, width: 40, height: 40);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique des incidents'),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: () {
              setState(() => _showMap = !_showMap);
              if (_showMap && _markers.isNotEmpty) {
                _mapController.move(_markers.first.point, 12.0);
              }
            },
          ),
        ],
      ),
      body: _showMap ? _buildMap() : _buildList(),
      floatingActionButton: _selectedIncident != null
          ? FloatingActionButton(
              child: Icon(Icons.directions),
              onPressed: _showDirections,
            )
          : null,
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter, // Utilisation correcte
        initialZoom: 12.0,
        onTap: (_, __) => setState(() => _selectedIncident = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.app',
        ),
        MarkerLayer(markers: _markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
            ),
          ],
        ),
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
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final incidents = snapshot.data ?? [];
        
        return ListView.builder(
          itemCount: incidents.length,
          itemBuilder: (context, index) {
            final incident = incidents[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: _buildIncidentIcon(incident),
                title: Text(incident.description),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Type: ${_getTypeLabel(incident.incidentType)}'),
                    Text('Statut: ${incident.isSynced ? 'Synchro' : 'En attente'}'),
                    Text(incident.formattedDate),
                  ],
                ),
                onTap: () => _showIncidentDetails(incident),
              ),
            );
          },
        );
      },
    );
  }

  void _showIncidentDetails(Incident incident) {
    setState(() => _selectedIncident = incident);
    _mapController.move(_parseLocation(incident.location), 14);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails de l\'incident'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (incident.photoUrl != null)
                Image.network(incident.photoUrl!, height: 200),
              SizedBox(height: 16),
              Text('Type: ${_getTypeLabel(incident.incidentType)}'),
              Text('Description: ${incident.description}'),
              Text('Localisation: ${incident.location}'),
              Text('Date: ${incident.formattedDate}'),
              Text('Statut: ${incident.isSynced ? 'Synchronisé' : 'En attente'}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Fermer'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Voir sur la carte'),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showMap = true;
                _mapController.move(_parseLocation(incident.location), 14);
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDirections() async {
    if (_selectedIncident == null) return;
    
    final location = _parseLocation(_selectedIncident!.location);
    final url = 'https://www.openstreetmap.org/?mlat=${location.latitude}&mlon=${location.longitude}#map=16/${location.latitude}/${location.longitude}';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir OpenStreetMap')),
      );
    }
  }
}