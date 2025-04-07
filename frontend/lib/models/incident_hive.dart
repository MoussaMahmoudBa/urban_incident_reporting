import 'package:hive/hive.dart';

part 'incident_hive.g.dart'; // Ce fichier sera généré automatiquement

@HiveType(typeId: 0)
class IncidentHive {
  @HiveField(0) final String incidentType;
  @HiveField(1) final String description;
  @HiveField(2) final String? imagePath;
  @HiveField(3) final String? audioPath; 
  @HiveField(4) final String location;
  @HiveField(5) bool isSynced;

  IncidentHive({
    required this.incidentType,
    required this.description,
    this.imagePath,
    this.audioPath, 
    required this.location,
    this.isSynced = false,
  });
}