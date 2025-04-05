import 'incident_hive.dart'; // Ajoutez cet import

class Incident {
  final int id;
  final String incidentType;
  final String description;
  final String? photoUrl;
  final String? audioUrl; // Nouveau champ
  final String location;
  final DateTime createdAt;
  final int userId;
  final bool isSynced;

  Incident({
    required this.id,
    required this.incidentType,
    required this.description,
    this.photoUrl,
    this.audioUrl, // Nouveau champ
    required this.location,
    required this.createdAt,
    required this.userId,
    this.isSynced = true,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'],
      incidentType: json['incident_type'],
      description: json['description'],
      photoUrl: json['photo'] != null ? 'http://127.0.0.1:8000${json['photo']}' : null,
      audioUrl: json['audio'] != null ? 'http://127.0.0.1:8000${json['audio']}' : null, // Nouveau
      location: json['location'],
      createdAt: DateTime.parse(json['created_at']),
      userId: json['user'],
    );
  }

  factory Incident.fromHive(IncidentHive hive) {
    return Incident(
      id: -1,
      incidentType: hive.incidentType,
      description: hive.description,
      photoUrl: hive.imagePath,
      audioUrl: hive.audioPath, // Nouveau
      location: hive.location,
      createdAt: DateTime.now(),
      userId: 0,
      isSynced: hive.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'incident_type': incidentType,
      'description': description,
      'photo': photoUrl,
      'location': location,
      'user': userId,
    };
  }

  String get formattedDate => '${createdAt.day}/${createdAt.month}/${createdAt.year}';
}