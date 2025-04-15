import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/incident_service.dart';
import '../services/user_service.dart';
import '../models/incident.dart';
import '../models/user.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';

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
      // Récupère les données de l'API
      final apiStats = await IncidentService.getIncidentStats();
      
      // Charge les données supplémentaires nécessaires
      final incidents = await IncidentService.getAllIncidents();
      final allUsers = await UserService.getAllUsers();
      final nonAdminUsers = await UserService.getNonAdminUsers();

      // Mise à jour des marqueurs pour la carte
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

      // Statistiques des 7 derniers jours (calcul côté client)
      final now = DateTime.now();
      final last7Days = List.generate(7, (i) => 
        DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
      
      final incidentsLast7Days = last7Days.map((day) {
        final count = incidents.where((incident) => 
          incident.createdAt.year == day.year &&
          incident.createdAt.month == day.month &&
          incident.createdAt.day == day.day
        ).length;
        
        return {
          'date': '${day.day}/${day.month}',
          'count': count
        };
      }).toList();

      // Trouver les utilisateurs les plus actifs (calcul côté client)
      final userIncidentCount = <int, int>{};
      for (var incident in incidents) {
        final user = allUsers.firstWhere(
          (u) => u.id == incident.userId, 
          orElse: () => User(id: -1, username: 'Inconnu', email: '', role: ''));
        if (user.role != 'admin') {
          userIncidentCount[incident.userId] = (userIncidentCount[incident.userId] ?? 0) + 1;
        }
      }
      
      final sortedUsers = userIncidentCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topActiveUsers = sortedUsers.take(3).map((e) {
        final user = allUsers.firstWhere(
          (u) => u.id == e.key, 
          orElse: () => User(id: -1, username: 'Inconnu', email: '', role: ''));
        return {
          'user': user,
          'count': e.value,
        };
      }).toList();

      // Combine les données de l'API avec les calculs côté client
      return {
        'total_incidents': apiStats['total_incidents'] ?? incidents.length,
        'total_non_admin_users': apiStats['total_non_admin_users'] ?? nonAdminUsers.length,
        'incidents_by_type': apiStats['incidents_by_type'] ?? incidents.fold<Map<String, int>>({}, (map, incident) {
          map[incident.incidentType] = (map[incident.incidentType] ?? 0) + 1;
          return map;
        }).entries.map((e) => {
          'incident_type': e.key,
          'count': e.value
        }).toList(),
        'incidents_last_7_days': incidentsLast7Days,
        'top_users': topActiveUsers,
        'recent_incidents': incidents.take(5).toList(),
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

  Widget _buildTypeChart(List<dynamic> typeData) {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < typeData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        typeData[index]['incident_type'].toString(),
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString());
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          barGroups: typeData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data['count'].toDouble(),
                  color: Colors.blue,
                  width: 20,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTimelineChart(List<dynamic> timelineData) {
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < timelineData.length) {
                    return Text(timelineData[index]['date'].toString());
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(value.toInt().toString());
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: timelineData.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value['count'].toDouble(),
                );
              }).toList(),
              isCurved: false,
              color: Colors.green,
              barWidth: 4,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatsCard(Map<String, dynamic> userData) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text(userData['user'].username[0])),
        title: Text(userData['user'].username),
        subtitle: Text(userData['user'].email),
        trailing: Chip(
          label: Text('${userData['count']} signalements'),
          backgroundColor: Colors.blue[100],
        ),
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
      _loadData();
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Text('Erreur de chargement des statistiques'));
        }

        final stats = snapshot.data!;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Statistiques des incidents', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatsCard(
                      'Total incidents',
                      '${stats['total_incidents']}',
                      Icons.report_problem,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _buildStatsCard(
                      'Utilisateurs actifs',
                      '${stats['total_non_admin_users']}',
                      Icons.people,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              Text('Incidents par type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              _buildTypeChart(stats['incidents_by_type']),
              SizedBox(height: 20),
              
              Text('Évolution sur 7 jours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              _buildTimelineChart(stats['incidents_last_7_days']),
              SizedBox(height: 20),
              
              Text('Top utilisateurs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              ...(stats['top_users'] as List).map<Widget>((user) => _buildUserStatsCard(user)).toList(),
              SizedBox(height: 20),
              
              Text('Derniers incidents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              ...(stats['recent_incidents'] as List<Incident>).map((incident) => 
                _buildIncidentCard(incident)
              ).toList(),
              SizedBox(height: 20),
              
              Text('Carte des incidents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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