import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:typed_data'; 
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_incident_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/registration_screen.dart'; 
import 'services/auth_service.dart';
import 'models/incident_hive.dart';
import 'package:geolocator/geolocator.dart';
import 'screens/admin_dashboard.dart'; 
import '../models/user.dart'; 
import 'theme_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Demande de permission de localisation
  await _requestLocationPermission();
  
  // Initialisation de Hive
  await _initializeHive();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(),
    ),
  );
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'Signalement Urbain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1565C0),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF1565C0),
          secondary: const Color(0xFF0D47A1),
        ),
        appBarTheme: AppBarTheme(
          color: const Color(0xFF1565C0),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF1A237E),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF1A237E),
          secondary: const Color(0xFF64B5F6),
        ),
        appBarTheme: AppBarTheme(
          color: const Color(0xFF1A237E),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        cardColor: const Color(0xFF1E1E1E),
      ),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routes: {
        '/': (context) => FutureBuilder<String?>(
          future: AuthService.getAccessToken(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            if (snapshot.hasData) {
              return FutureBuilder<User?>(
                future: AuthService.getCurrentUser(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  
                  if (userSnapshot.hasData && userSnapshot.data != null) {
                    final user = userSnapshot.data!;
                    return user.role == 'admin' 
                        ? const AdminDashboardScreen() 
                        : const HomeScreen();
                  }
                  return const LoginScreen();
                },
              );
            }
            return const LoginScreen();
          },
        ),
        '/home': (context) => const HomeScreen(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/report': (context) => const ReportIncidentScreen(),
        '/history': (context) => const HistoryScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/register': (context) => const RegistrationScreen(),
      },
      initialRoute: '/',
    );
  }
}