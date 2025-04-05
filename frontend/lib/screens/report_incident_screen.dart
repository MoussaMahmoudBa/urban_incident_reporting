import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
// import 'dart:html' as html;
import '../services/incident_service.dart';
import 'dart:io'; // Pour la classe File
import 'package:speech_to_text/speech_to_text.dart' as stt;


class ReportIncidentScreen extends StatefulWidget {
  @override
  _ReportIncidentScreenState createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _imagePath;
  Position? _position;
  String? _selectedIncidentType = 'other';

  // Ajouts pour la reconnaissance vocale
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

  Future<void> _getLocation() async {
  // Vérifiez les permissions
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
    _position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {});
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur lors de la récupération de la position: $e')),
    );
  }
}

  Future<void> _takePhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez obtenir votre position')),
      );
      return;
    }

    try {
      await IncidentService.reportIncident(
        incidentType: _selectedIncidentType!,
        description: _descriptionController.text,
        imagePath: _imagePath,
        location: '${_position!.latitude},${_position!.longitude}',
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
              Text(_position != null
                  ? 'Localisation: ${_position!.latitude}, ${_position!.longitude}'
                  : 'Localisation non détectée'),
              ElevatedButton(
                onPressed: _getLocation,
                child: Text('Obtenir la localisation'),
              ),
              SizedBox(height: 30),
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