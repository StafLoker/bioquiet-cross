import 'package:flutter/material.dart';
import '../models/statistics.dart';

class StatisticsCard extends StatelessWidget {
  final Statistics stats;

  const StatisticsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatItem("Total registros", "${stats.totalRecords}"),
            const Divider(height: 30),
            _buildStatItem(
              "Ruido máximo",
              "${stats.maxDb.toStringAsFixed(2)} dB",
            ),
            const Divider(height: 30),
            _buildStatItem(
              "Ruido promedio",
              "${stats.averageDb.toStringAsFixed(2)} dB",
            ),
            const Divider(height: 40),
            Center(
              child: Text(
                stats.feedback,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
