import 'package:bioquiet_cross/screens/account_screen.dart';
import 'package:bioquiet_cross/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name} | ${record.loggerName} | ${record.time} | ${record.message}');
  });

  runApp(const BioQuietApp());
}

class BioQuietApp extends StatelessWidget {
  const BioQuietApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioQuiet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentTabIndex = 0;
  final GlobalKey<AccountScreenState> _accountKey = GlobalKey<AccountScreenState>();
  
  late final List<Widget> _appScreens;

  @override
  void initState() {
    super.initState();
    _appScreens = [
      const MapScreen(),
      AccountScreen(key: _accountKey)
    ];
  }

  void _onTabChanged(int index) {
    setState(() {
      _currentTabIndex = index;
    });

    // Si el usuario cambia a la pestaña de Cuenta, refrescamos los datos automáticamente
    if (index == 1) {
      _accountKey.currentState?.loadUserStatistics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTabIndex,
        children: _appScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
        currentIndex: _currentTabIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onTabChanged,
      ),
    );
  }
}
