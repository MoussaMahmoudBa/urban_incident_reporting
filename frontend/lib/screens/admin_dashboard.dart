import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/incident_service.dart';
import '../services/user_service.dart';
import '../models/incident.dart';
import '../models/user.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, dynamic>> _statsFuture;
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final stats = await _loadStats();
      await _loadIncidentsForMap();
      
      setState(() {
        _statsFuture = Future.value(stats);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de chargement: ${e.toString()}';
        _isLoading = false;
      });
      print('ERREUR: $_errorMessage');
    }
  }

  Future<Map<String, dynamic>> _loadStats() async {
    try {
      final incidents = await IncidentService.getAllIncidents();
      final allUsers = await UserService.getAllUsers();
      final nonAdminUsers = await UserService.getNonAdminUsers();
      
      // Calcul des statistiques
      final totalIncidents = incidents.length;
      final totalNonAdminUsers = nonAdminUsers.length;
      
      // Trouver les utilisateurs les plus actifs (non admin)
      final userIncidentCount = <int, int>{};
      for (var incident in incidents) {
        final user = allUsers.firstWhere(
          (u) => u.id == incident.userId, 
          orElse: () => User(id: -1, username: 'Inconnu', email: '', role: '')
        );
        if (user.role != 'admin') {
          userIncidentCount[incident.userId] = (userIncidentCount[incident.userId] ?? 0) + 1;
        }
      }
      
      final sortedUsers = userIncidentCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topActiveUsers = sortedUsers.take(3).map((e) {
        final user = allUsers.firstWhere(
          (u) => u.id == e.key, 
          orElse: () => User(id: -1, username: 'Inconnu', email: '', role: '')
        );
        return {
          'user': user,
          'count': e.value,
        };
      }).toList();

      return {
        'totalIncidents': totalIncidents,
        'totalNonAdminUsers': totalNonAdminUsers,
        'topActiveUsers': topActiveUsers,
        'recentIncidents': incidents.take(5).toList(),
      };
    } catch (e) {
      print('Erreur dans _loadStats: $e');
      rethrow;
    }
  }

  Future<void> _loadIncidentsForMap() async {
    try {
      final incidents = await IncidentService.getAllIncidents();
      
      setState(() {
        _markers.clear();
        _markers.addAll(incidents.map((incident) {
          final parts = incident.location.split(',');
          final lat = double.tryParse(parts[0]) ?? 48.8566;
          final lng = double.tryParse(parts[1]) ?? 2.3522;
          
          return Marker(
            width: 40,
            height: 40,
            point: LatLng(lat, lng),
            child: Icon(
              Icons.location_pin,
              color: Colors.red,
              size: 40,
            ),
          );
        }));
      });
    } catch (e) {
      print('Erreur dans _loadIncidentsForMap: $e');
      setState(() {
        _errorMessage = 'Erreur de chargement de la carte';
      });
    }
  }

  Widget _buildStatsCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(User user, int incidentCount) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(user.username[0])),
        title: Text(user.username),
        subtitle: Text('${user.email} - ${user.role}'),
        trailing: Chip(label: Text('$incidentCount signalements')),
      ),
    );
  }

  Widget _buildIncidentCard(Incident incident) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(incident.description.length > 30 
            ? '${incident.description.substring(0, 30)}...' 
            : incident.description),
        subtitle: Text('${incident.incidentType} - ${incident.formattedDate}'),
        trailing: IconButton(
          icon: Icon(Icons.arrow_forward),
          onPressed: () => _showIncidentDetails(incident),
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(User user) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(user.username[0])),
        title: Text(user.username),
        subtitle: Text(user.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(user.role)),
            IconButton(
              icon: Icon(Icons.block, color: Colors.red),
              onPressed: () => _toggleUserStatus(user.id, false),
            ),
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _toggleUserStatus(user.id, true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(int userId, bool isActive) async {
    try {
      await UserService.toggleUserStatus(userId, isActive);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut utilisateur mis à jour')),
      );
      _loadData(); // Recharger les données
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  void _showIncidentDetails(Incident incident) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails de l\'incident'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (incident.photoUrl != null)
                Image.network(incident.photoUrl!),
              SizedBox(height: 16),
              Text('Type: ${incident.incidentType}'),
              SizedBox(height: 8),
              Text('Description: ${incident.description}'),
              SizedBox(height: 8),
              Text('Localisation: ${incident.location}'),
              SizedBox(height: 8),
              Text('Date: ${incident.formattedDate}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Fermer'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        
        final stats = snapshot.data!;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statistiques générales', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatsCard(
                        'Incidents signalés',
                        '${stats['totalIncidents']}',
                        Icons.report,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildStatsCard(
                        'Utilisateurs (non-admin)',
                        '${stats['totalNonAdminUsers']}',
                        Icons.people,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text('Utilisateurs les plus actifs', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...(stats['topActiveUsers'] as List).map((userData) => 
                  _buildUserCard(userData['user'], userData['count'])
                ).toList(),
                SizedBox(height: 16),
                Text('Derniers incidents', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ...(stats['recentIncidents'] as List<Incident>).map((incident) => 
                  _buildIncidentCard(incident)
                ).toList(),
                SizedBox(height: 16),
                Text('Carte des incidents', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Container(
                  height: 300,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(48.8566, 2.3522),
                      initialZoom: 12.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(markers: _markers),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return FutureBuilder<List<User>>(
      future: UserService.getNonAdminUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        
        final users = snapshot.data ?? [];
        
        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserManagementCard(user);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Admin'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.logout().then((_) {
              Navigator.pushReplacementNamed(context, '/');
            }),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _selectedTabIndex == 0 
                  ? _buildStatsTab()
                  : _buildUsersTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Statistiques',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Utilisateurs',
          ),
        ],
      ),
    );
  }
}