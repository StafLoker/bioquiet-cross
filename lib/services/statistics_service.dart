
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../models/statistics.dart';
import '../models/zepa.dart';

class StatisticsService {
  static const String _filename = "statistic.csv";
  static const String _csvHeader = "date,zepa_id,decibels\n";
  static const double _highNoiseThreshold = 60.0;

  static final _logger = Logger("StatisticService");

  // Registra una nueva entrada de ruido asociada a una zona protegida.
  Future<void> saveNoiseRecord(Zepa zepa, double decibels) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_filename');
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      if (!await file.exists()) {
        await file.writeAsString(_csvHeader, mode: FileMode.write);
      }

      await file.writeAsString(
        '$timestamp,${zepa.id},$decibels\n',
        mode: FileMode.append,
      );
    } catch (e) {
      _logger.severe("Error al persistir el registro de ruido: $e");
    }
  }

  // Recupera y procesa todos los registros para generar el resumen estadístico.
  Future<Statistics> calculateGlobalStatistics() async {
    int totalEntries = 0;
    double maxNoise = 0;
    double noiseSum = 0;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_filename');

      if (!await file.exists()) {
        return Statistics(
          totalRecords: 0, 
          maxDb: 0, 
          averageDb: 0, 
          feedback: "No hay actividad registrada."
        );
      }

      final lines = await file.readAsLines();
      if (lines.length <= 1) {
        return Statistics(
          totalRecords: 0, 
          maxDb: 0, 
          averageDb: 0, 
          feedback: "Inicia un recorrido para ver tus datos."
        );
      }

      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;

        final parts = line.split(',');
        if (parts.length < 3) continue;

        final db = double.tryParse(parts[2].trim()) ?? 0.0;
        if (db > maxNoise) maxNoise = db;
        noiseSum += db;
        totalEntries++;
      }

      final avgNoise = totalEntries > 0 ? noiseSum / totalEntries : 0.0;

      return Statistics(
        totalRecords: totalEntries,
        maxDb: maxNoise,
        averageDb: avgNoise,
        feedback: avgNoise > _highNoiseThreshold
            ? "¡Cuidado! Tu impacto acústico promedio es elevado."
            : "¡Genial! Mantienes un perfil sonoro respetuoso.",
      );
    } catch (e) {
      _logger.severe("Fallo al procesar estadísticas: $e");
      return Statistics(
        totalRecords: 0, 
        maxDb: 0, 
        averageDb: 0, 
        feedback: "Error al cargar los datos."
      );
    }
  }
}
