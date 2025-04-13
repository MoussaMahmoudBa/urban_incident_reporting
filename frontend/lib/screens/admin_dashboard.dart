import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/incident_service.dart';
import '../models/incident.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.logout().then((_) {
              Navigator.pushReplacementNamed(context, '/');
            }),
          ),
        ],
      ),
      body: FutureBuilder<List<Incident>>(
        future: IncidentService.getAllIncidents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          
          final incidents = snapshot.data ?? [];
          return ListView.builder(
            itemCount: incidents.length,
            itemBuilder: (context, index) {
              final incident = incidents[index];
              return ListTile(
                title: Text(incident.description),
                subtitle: Text('Type: ${incident.incidentType}'),
                trailing: Text('Signalé par: ${incident.userId}'),
              );
            },
          );
        },
      ),
    );
  }
}