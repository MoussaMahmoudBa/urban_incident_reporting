import 'package:flutter/material.dart';
import 'history_screen.dart';
import 'report_incident_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    _HomeContent(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Signalement Urbain'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_alert),
            onPressed: () => Navigator.pushNamed(context, '/report'),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => Navigator.pushNamed(context, '/report'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historique'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Bienvenue !', style: Theme.of(context).textTheme.displaySmall),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.add_alert),
            label: Text('Signaler un incident'),
            onPressed: () => Navigator.pushNamed(context, '/report'),
          ),
          SizedBox(height: 10),
          Text('Ou utilisez le bouton + en bas'),
        ],
      ),
    );
  }
}