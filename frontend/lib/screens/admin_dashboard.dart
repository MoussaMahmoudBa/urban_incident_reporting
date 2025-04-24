import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/incident_service.dart';
import '../services/user_service.dart';
import '../models/incident.dart';
import '../models/user.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddAdminDialog extends StatefulWidget {
  final Function() onAdminCreated;

  const AddAdminDialog({Key? key, required this.onAdminCreated}) : super(key: key);

  @override
  _AddAdminDialogState createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<AddAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  final _storage = FlutterSecureStorage();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception('Non authentifié');

      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/users/admin/register/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'password2': _confirmPasswordController.text.trim(),
          'phone_number': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        widget.onAdminCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admin créé avec succès!'))
        );
      } else {
        throw Exception(json.decode(response.body).toString());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'))
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajouter un administrateur'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Nom d\'utilisateur*'),
                validator: (value) => value?.isEmpty ?? true ? 'Ce champ est requis' : null,
              ),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email*'),
                validator: (value) => value?.isEmpty ?? true ? 'Email invalide' : null,
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Mot de passe*'),
                validator: (value) => value?.isEmpty ?? true ? 'Ce champ est requis' : null,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Confirmer mot de passe*'),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Ce champ est requis';
                  if (value != _passwordController.text) return 'Les mots de passe ne correspondent pas';
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Téléphone'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text('Annuler'),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitForm,
          child: _isSubmitting 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Text('Créer'),
        ),
      ],
    );
  }
}

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
  bool _isDarkMode = false;
  final _storage = FlutterSecureStorage();

  // Couleurs dynamiques
  Color get _primaryColor => _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F9FF);
  Color get _secondaryColor => _isDarkMode ? const Color(0xFF1A237E) : const Color(0xFF1565C0);
  Color get _accentColor => _isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF0D47A1);
  Color get _primaryTextColor => _isDarkMode ? Colors.white : Colors.grey[900]!;
  Color get _secondaryTextColor => _isDarkMode ? Colors.white.withOpacity(0.9) : Colors.grey[800]!;
  Color get _cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

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
      final apiStats = await IncidentService.getIncidentStats();
      final incidents = await IncidentService.getAllIncidents();
      final allUsers = await UserService.getAllUsers();
      final nonAdminUsers = await UserService.getNonAdminUsers();
      final currentUser = await AuthService.getCurrentUser();
      
      if (currentUser?.role != 'admin') {
        throw Exception('Permissions insuffisantes');
      }

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

      if (apiStats.containsKey('error')) {
        return _buildLocalStats(incidents, allUsers, nonAdminUsers);
      }

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
      
      try {
        final incidents = await IncidentService.getAllIncidents();
        final allUsers = await UserService.getAllUsers();
        final nonAdminUsers = await UserService.getNonAdminUsers();
        return _buildLocalStats(incidents, allUsers, nonAdminUsers);
      } catch (fallbackError) {
        print('Erreur dans le fallback: $fallbackError');
        rethrow;
      }
    }
  }

  Map<String, dynamic> _buildLocalStats(List<Incident> incidents, List<User> allUsers, List<User> nonAdminUsers) {
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

    return {
      'total_incidents': incidents.length,
      'total_non_admin_users': nonAdminUsers.length,
      'incidents_by_type': incidents.fold<Map<String, int>>({}, (map, incident) {
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
      color: _cardColor,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: _accentColor),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 16, color: _primaryTextColor)),
            const SizedBox(height: 8),
            Text(value, 
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                )),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: _secondaryTextColor,
                        ),
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
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(color: _secondaryTextColor),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: _secondaryTextColor.withOpacity(0.3)),
          ),
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: _secondaryTextColor.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          barGroups: typeData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: data['count'].toDouble(),
                  color: _accentColor,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
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
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: _secondaryTextColor.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < timelineData.length) {
                    return Text(
                      timelineData[index]['date'].toString(),
                      style: TextStyle(
                        color: _secondaryTextColor,
                        fontSize: 10,
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
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(color: _secondaryTextColor),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: _secondaryTextColor.withOpacity(0.3)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: timelineData.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value['count'].toDouble(),
                );
              }).toList(),
              isCurved: false,
              color: _accentColor,
              barWidth: 4,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: _accentColor,
                  strokeWidth: 2,
                  strokeColor: _cardColor,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: _accentColor.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatsCard(Map<String, dynamic> userData) {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _accentColor,
          child: Text(
            userData['user'].username[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          userData['user'].username,
          style: TextStyle(color: _primaryTextColor),
        ),
        subtitle: Text(
          userData['user'].email,
          style: TextStyle(color: _secondaryTextColor),
        ),
        trailing: Chip(
          label: Text(
            '${userData['count']} signalements',
            style: TextStyle(color: _accentColor),
          ),
          backgroundColor: _accentColor.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildIncidentCard(Incident incident) {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          incident.description.length > 30 
              ? '${incident.description.substring(0, 30)}...' 
              : incident.description,
          style: TextStyle(color: _primaryTextColor),
        ),
        subtitle: Text(
          '${incident.incidentType} - ${incident.formattedDate}',
          style: TextStyle(color: _secondaryTextColor),
        ),
        trailing: IconButton(
          icon: Icon(Icons.arrow_forward, color: _accentColor),
          onPressed: () => _showIncidentDetails(incident),
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(User user) {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _accentColor,
          child: Text(
            user.username[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          user.username,
          style: TextStyle(color: _primaryTextColor),
        ),
        subtitle: Text(
          user.email,
          style: TextStyle(color: _secondaryTextColor),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                user.role,
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: _accentColor,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.block, color: Colors.red[400]),
              onPressed: () => _toggleUserStatus(user.id, false),
            ),
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green[400]),
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
          return Center(
            child: CircularProgressIndicator(color: _accentColor),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Text(
              'Erreur de chargement des statistiques',
              style: TextStyle(color: _primaryTextColor),
            ),
          );
        }

        final stats = snapshot.data!;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statistiques des incidents', 
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(child: _buildStatsCard('Total incidents', '${stats['total_incidents']}', Icons.report_problem)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatsCard('Utilisateurs actifs', '${stats['total_non_admin_users']}', Icons.people)),
                ],
              ),
              const SizedBox(height: 20),
              
              Text(
                'Incidents par type', 
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              _buildTypeChart(stats['incidents_by_type']),
              const SizedBox(height: 20),
              
              Text(
                'Évolution sur 7 jours', 
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              _buildTimelineChart(stats['incidents_last_7_days']),
              const SizedBox(height: 20),
              
              Text(
                'Top utilisateurs', 
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              ...(stats['top_users'] as List).map((user) => _buildUserStatsCard(user)),
              const SizedBox(height: 20),
              
              Text(
                'Derniers incidents', 
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              ...(stats['recent_incidents'] as List<Incident>).map((incident) => _buildIncidentCard(incident)),
              const SizedBox(height: 20),
              
              Text(
                'Carte des incidents', 
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _secondaryTextColor.withOpacity(0.2)),
                  color: _isDarkMode ? Colors.black : Colors.blue[50],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(48.8566, 2.3522),
                      initialZoom: 12.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(
                        markers: _markers.map((marker) => Marker(
                          width: 40,
                          height: 40,
                          point: marker.point,
                          child: Icon(
                            Icons.location_pin,
                            color: _accentColor,
                            size: 40,
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
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
          return Center(
            child: CircularProgressIndicator(color: _accentColor),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: ${snapshot.error}',
              style: TextStyle(color: _primaryTextColor),
            ),
          );
        }
        
        final users = snapshot.data ?? [];
        
        return RefreshIndicator(
          color: _accentColor,
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
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

  void _showAddAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AddAdminDialog(
        onAdminCreated: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      appBar: AppBar(
        title: const Text(
          'Tableau de bord Admin',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: _secondaryColor,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedTabIndex == 1)
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white),
              onPressed: _showAddAdminDialog,
              tooltip: 'Ajouter un admin',
            ),
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => AuthService.logout().then((_) {
              Navigator.pushReplacementNamed(context, '/');
            }),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: _primaryTextColor),
                  ),
                )
              : _selectedTabIndex == 0 
                  ? _buildStatsTab()
                  : _buildUsersTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() => _selectedTabIndex = index),
        backgroundColor: _secondaryColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
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