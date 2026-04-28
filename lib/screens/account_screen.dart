import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../models/statistics.dart';
import '../widgets/statistics_card.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static final log = Logger('AccountScreen');

  @override
  Widget build(BuildContext context) {
    log.fine("Build screen");

    // Simulacion
    final myStats = Statistics(
      totalRecords: 27,
      maxDb: 71,
      averageDb: 60,
      feedback: "¡Buen trabajo manteniéndolo silencioso!",
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 16),
          children: [
            // Sección de Usuario (Login)
            const Text(
                "CUENTA",
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.1
                )
            ),
            const SizedBox(height: 15),
            _buildLoginCard(),

            const SizedBox(height: 30),

            // Sección de Estadísticas
            const Text(
                "ESTADÍSTICAS",
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.1
                )
            ),
            const SizedBox(height: 15),
            StatisticsCard(stats: myStats),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Usuario", style: TextStyle(color: Colors.grey)),
            const Text("—", style: TextStyle(fontSize: 18)),
            const Divider(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Entrar / Crear cuenta"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}