import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../models/statistics.dart';
import '../services/statistics_service.dart';
import '../widgets/statistics_card.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => AccountScreenState();
}

class AccountScreenState extends State<AccountScreen> {
  final _log = Logger('AccountScreen');
  final _statsService = StatisticsService();

  Statistics? _userStatistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadUserStatistics());
  }

  Future<void> loadUserStatistics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final stats = await _statsService.getStatistics();
      if (mounted) {
        setState(() {
          _userStatistics = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      _log.severe("Error loading user statistics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadUserStatistics,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 10),
              _buildSectionTitle("CUENTA"),
              const SizedBox(height: 15),
              _buildUserLoginCard(),

              const SizedBox(height: 35),

              _buildSectionTitle("ESTADÍSTICAS EN TIEMPO REAL"),
              const SizedBox(height: 15),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_userStatistics != null)
                StatisticsCard(stats: _userStatistics!)
              else
                const Center(child: Text("No se pudieron cargar los datos.")),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildUserLoginCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Usuario",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              "Sesión no iniciada",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Divider(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Implementar lógica de autenticación
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Entrar / Crear cuenta",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
