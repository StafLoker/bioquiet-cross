import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
      '$timestamp,${zepa.id},$decibels\n',
      mode: FileMode.append,
    );
  }

  Future<Statistics> getStatistics() async {
    log.fine("Retrieved current statistics");

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

    final content = await file.readAsString();
    return compute(_parseCsv, content);
  }

  static Statistics _parseCsv(String content) {
    int totalRecords = 0;
    double maxDb = 0, sum = 0;

    final lines = const LineSplitter().convert(content);
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = line.split(',');
      if (cols.length < 3) continue;

      final decibels = double.tryParse(cols[2].trim()) ?? 0.0;
      if (decibels > maxDb) maxDb = decibels;
      sum += decibels;
      totalRecords++;
    }

    final averageDb = totalRecords > 0 ? sum / totalRecords : 0.0;

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
