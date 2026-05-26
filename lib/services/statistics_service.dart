import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../models/statistics.dart';
import '../models/zepa.dart';

class StatisticsService {
  static final String filename = "statistic.csv";
  static final String csvHeader = "date,zepa_id,decibels\n";
  static final double warningArgDb = 60.0;

  static final Logger log = Logger("StatisticService");

  Future<void> addRecord(Zepa zepa, double decibels) async {
    log.fine("Add record | ZEPA ID=${zepa.id} | Decibels=${decibels}db");

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${filename}');
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    if (!await file.exists()) {
      await file.writeAsString(csvHeader, mode: FileMode.write);
    }

    await file.writeAsString(
      '$timestamp,${zepa.id},$decibels',
      mode: FileMode.append,
    );
  }

  Future<Statistics> getStatistics() async {
    log.fine("Retrieved current statistics");

    int totalRecords = 0;
    double averageDb = 0, maxDb = 0, sum = 0;
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');

    if (!await file.exists()) {
      log.warning("Statistics file not found");
      return Statistics(
        totalRecords: 0,
        maxDb: 0,
        averageDb: 0,
        feedback: "Sin registros",
      );
    }

    await file
        .openRead()
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .skip(1)
        .forEach((line) {
          if (line.trim().isEmpty) return;

          final cols = line.split(',');

          if (cols.length < 3) return;

          final decibels = double.tryParse(cols[2].trim()) ?? 0.0;
          if (decibels > maxDb) maxDb = decibels;
          sum += decibels;
          totalRecords++;
        });

    averageDb = totalRecords > 0 ? sum / totalRecords : 0.0;

    return Statistics(
      totalRecords: totalRecords,
      maxDb: maxDb,
      averageDb: averageDb,
      feedback: averageDb > warningArgDb
          ? "¡Advertencia! Nivel de ruido promedio alto."
          : "¡Buen trabajo manteniéndolo silencioso!",
    );
  }
}
