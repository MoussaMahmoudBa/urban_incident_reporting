import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_incident_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';
import 'models/incident_hive.dart';
import 'services/connectivity_service.dart';
import 'screens/registration_screen.dart'; // Ajoutez cette ligne
import 'dart:io'; // Ajout pour File
import 'package:geolocator/geolocator.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Geolocator.requestPermission();
  await Hive.initFlutter();
  Hive.registerAdapter(IncidentHiveAdapter());
  await Hive.openBox<IncidentHive>('incidentsBox');

  // Vérification de la configuration
  debugPrint('Configuration initialisée - démarrage de l\'app');
  
  runApp(MyApp());
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
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.blueAccent,
          elevation: 4,
        ),
      ),
      routes: {
        '/': (context) => FutureBuilder<String?>(
          future: AuthService.getAccessToken(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return snapshot.hasData ? HomeScreen() : LoginScreen();
          },
        ),
        '/home': (context) => HomeScreen(),
        '/report': (context) => ReportIncidentScreen(),
        '/history': (context) => HistoryScreen(),
        '/profile': (context) => ProfileScreen(),
        '/register': (context) => RegistrationScreen(),
      },
      initialRoute: '/',
    );
  }
}