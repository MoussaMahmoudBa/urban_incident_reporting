import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data'; // Ajout de cet import
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_incident_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/registration_screen.dart'; 
import 'services/auth_service.dart';
import 'models/incident_hive.dart';
import 'package:geolocator/geolocator.dart';
import 'screens/admin_dashboard.dart'; // Ajouter cet import
import '../models/user.dart'; // Ajoutez cette ligne


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Demande de permission de localisation
  await _requestLocationPermission();
  
  // Initialisation de Hive
  await _initializeHive();
  
  runApp(MyApp());
}

Future<void> _requestLocationPermission() async {
  try {
    await Geolocator.requestPermission();
  } catch (e) {
    debugPrint('Erreur permission localisation: $e');
  }
}

Future<void> _initializeHive() async {
  try {
    await Hive.initFlutter();
    Hive.registerAdapter(IncidentHiveAdapter());
    
    // Tentative normale d'ouverture
    await Hive.openBox<IncidentHive>('incidentsBox');
    debugPrint('Initialisation Hive réussie');
  } catch (e) {
    debugPrint('Erreur initialisation Hive: $e');
    await _recoverFromHiveError();
  }
}

Future<void> _recoverFromHiveError() async {
  try {
    // 1ère tentative: supprimer et recréer
    await Hive.deleteBoxFromDisk('incidentsBox');
    await Hive.openBox<IncidentHive>('incidentsBox');
    debugPrint('Réinitialisation de la boîte réussie');
  } catch (e) {
    debugPrint('Échec réinitialisation: $e');
    // 2ème tentative: version simplifiée
    try {
      await Hive.openBox<IncidentHive>('incidentsBox', bytes: Uint8List(0));
      debugPrint('Boîte vide créée en mémoire');
    } catch (e) {
      debugPrint('Échec création boîte mémoire: $e');
      // Dernier recours: utiliser une box temporaire
      await Hive.openBox<IncidentHive>('temp_incidentsBox');
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signalement Urbain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      routes: {
        '/': (context) => FutureBuilder<String?>(
          future: AuthService.getAccessToken(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            if (snapshot.hasData) {
              return FutureBuilder<User?>(
                future: AuthService.getCurrentUser(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  
                  if (userSnapshot.hasData && userSnapshot.data != null) {
                    final user = userSnapshot.data!;
                    return user.role == 'admin' 
                        ? AdminDashboardScreen() 
                        : HomeScreen();
                  }
                  return LoginScreen();
                },
              );
            }
            return LoginScreen();
          },
        ),
        '/home': (context) => HomeScreen(),
        '/admin': (context) => AdminDashboardScreen(),
        '/report': (context) => ReportIncidentScreen(),
        '/history': (context) => HistoryScreen(),
        '/profile': (context) => ProfileScreen(),
        '/register': (context) => RegistrationScreen(),
      },
      initialRoute: '/',
    );
  }
}