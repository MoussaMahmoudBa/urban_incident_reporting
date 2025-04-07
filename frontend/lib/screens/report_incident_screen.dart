import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/incident_service.dart';
import 'dart:io';

class ReportIncidentScreen extends StatefulWidget {
  @override
  _ReportIncidentScreenState createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _imagePath;
  String? _selectedLocation;
  String? _selectedIncidentType = 'other';
  bool _showMap = false;
  LatLng? _selectedPosition;
  final MapController _mapController = MapController();

  // Reconnaissance vocale
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
    setState(() {});
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords;
              if (result.finalResult) {
                _descriptionController.text = _lastWords;
              }
            });
          },
        );
      }
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_lastWords.isNotEmpty) {
        _descriptionController.text = _lastWords;
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  final List<Map<String, String>> incidentTypes = [
    {'value': 'fire', 'label': 'Incendie'},
    {'value': 'accident', 'label': 'Accident'},
    {'value': 'theft', 'label': 'Vol'},
    {'value': 'other', 'label': 'Autre'},
  ];

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Les permissions de localisation sont requises')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Les permissions de localisation sont définitivement refusées')),
      );
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activez la localisation dans les paramètres de votre appareil')),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _selectedLocation = '${position.latitude},${position.longitude}';
        _showMap = true;
        _mapController.move(_selectedPosition!, 15.0);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la récupération de la position: $e')),
      );
    }
  }

  Future<void> _openMapPicker() async {
    setState(() {
      _showMap = true;
      if (_selectedPosition != null) {
        _mapController.move(_selectedPosition!, 15.0);
      }
    });
  }

  Future<void> _takePhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner une localisation')),
      );
      return;
    }

    try {
      await IncidentService.reportIncident(
        incidentType: _selectedIncidentType!,
        description: _descriptionController.text,
        imagePath: _imagePath,
        location: _selectedLocation!,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incident signalé avec succès!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Signaler un incident')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedIncidentType,
                items: incidentTypes.map((type) {
                  return DropdownMenuItem(
                    value: type['value'],
                    child: Text(type['label']!),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedIncidentType = value),
                decoration: InputDecoration(labelText: 'Type d\'incident'),
              ),
              SizedBox(height: 20),
              if (_imagePath != null) 
                Image.file(File(_imagePath!), height: 200),
              ElevatedButton(
                onPressed: _takePhoto,
                child: Text('Choisir une photo'),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  suffixIcon: IconButton(
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                    onPressed: () {
                      if (_isListening) {
                        _stopListening();
                      } else {
                        _startListening();
                      }
                    },
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Requis' : null,
                maxLines: 3,
              ),
              if (_isListening)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _lastWords.isEmpty ? 'Écoute...' : _lastWords,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              SizedBox(height: 20),
              Text(_selectedLocation != null
                  ? 'Localisation: $_selectedLocation'
                  : 'Localisation non sélectionnée'),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _getCurrentLocation,
                      child: Text('Localisation actuelle'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _openMapPicker,
                      child: Text('Choisir sur la carte'),
                    ),
                  ),
                ],
              ),
              if (_showMap)
                Container(
                  height: 300,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedPosition ?? LatLng(48.8566, 2.3522),
                      initialZoom: 12.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedPosition = point;
                          _selectedLocation = '${point.latitude},${point.longitude}';
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      if (_selectedPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 40,
                              height: 40,
                              point: _selectedPosition!,
                              child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitReport,
                child: Text('Envoyer le rapport'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}