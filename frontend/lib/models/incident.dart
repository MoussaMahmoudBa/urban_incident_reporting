import 'incident_hive.dart';

class Incident {
  final int id;
  final String incidentType;
  final String description;
  final String? photoUrl;
  final String? audioUrl;
  final String location;
  final DateTime createdAt;
  final int userId;
  final bool isSynced;

  Incident({
    required this.id,
    required this.incidentType,
    required this.description,
    this.photoUrl,
    this.audioUrl,
    required this.location,
    required this.createdAt,
    required this.userId,
    this.isSynced = true,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    String? parsePhotoUrl(dynamic photo) {
  if (photo == null) return null;
  if (photo is String) {
    // Si c'est déjà une URL complète (pour les incidents en ligne)
    if (photo.startsWith('http')) return photo;
    // Si c'est un chemin local (pour les incidents hors ligne)
    if (photo.startsWith('/')) return 'http://10.0.2.2:8000$photo';
    // Si c'est un chemin de fichier local (pour Hive)
    return photo;
  }
  return null;
}

    return Incident(
      id: json['id'],
      incidentType: json['incident_type'],
      description: json['description'],
      photoUrl: parsePhotoUrl(json['photo']),
      audioUrl: json['audio'] != null ? 'http://10.0.2.2:8000${json['audio']}' : null,
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
      audioUrl: hive.audioPath,
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
      'audio': audioUrl,
      'location': location,
      'user': userId,
    };
  }

  String get formattedDate => '${createdAt.day}/${createdAt.month}/${createdAt.year}';
}