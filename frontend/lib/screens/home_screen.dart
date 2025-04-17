import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'history_screen.dart';
import 'report_incident_screen.dart';
import 'profile_screen.dart';
import '../theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  final List<Widget> _screens = [
    const _HomeContent(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 8.0, end: 15.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('URBAN GUARDIAN', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 1,
        backgroundColor: themeProvider.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round, color: Colors.white),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.add_alert, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/report'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              themeProvider.backgroundColor,
              themeProvider.isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFE3F2FD),
            ],
          ),
        ),
        child: _screens[_currentIndex],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: themeProvider.accentColor.withOpacity(0.5),
                  blurRadius: _glowAnimation.value,
                  spreadRadius: _glowAnimation.value / 4,
                ),
              ],
            ),
            child: FloatingActionButton(
              backgroundColor: themeProvider.accentColor,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () => Navigator.pushNamed(context, '/report'),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: themeProvider.primaryColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.home, size: 28,
                  color: _currentIndex == 0 ? Colors.white : Colors.white70),
              onPressed: () => setState(() => _currentIndex = 0),
            ),
            IconButton(
              icon: Icon(Icons.history, size: 28,
                  color: _currentIndex == 1 ? Colors.white : Colors.white70),
              onPressed: () => setState(() => _currentIndex = 1),
            ),
            IconButton(
              icon: Icon(Icons.person, size: 28,
                  color: _currentIndex == 2 ? Colors.white : Colors.white70),
              onPressed: () => setState(() => _currentIndex = 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textColor = themeProvider.textColor;
    final secondaryTextColor = themeProvider.secondaryTextColor;
    final buttonColor = themeProvider.accentColor;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Icon(
              Icons.security,
              size: 120,
              color: buttonColor,
            ),
            const SizedBox(height: 30),
            Text(
              'Votre ville, notre priorité',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: textColor,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'SIGNALEZ • SURVEILLEZ • PROTÉGEZ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: buttonColor,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Participez activement à la sécurité de votre communauté en signalant les incidents urbains en temps réel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: secondaryTextColor,
                ),
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_alert, size: 24, color: Colors.white),
              label: const Text(
                'Signaler un incident',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
                shadowColor: buttonColor.withOpacity(0.4),
              ),
              onPressed: () => Navigator.pushNamed(context, '/report'),
            ),
            const SizedBox(height: 30),
            Text(
              'Appuyez sur le bouton + pour commencer',
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}