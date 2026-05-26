import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../models/zepa.dart';

class ZepaService {
  static const String apiBaseUrl =
      "https://bioquiet-backend-production.up.railway.app";

  static final Logger _log = Logger("ZepaService");

  Future<List<Zepa>> fetchNearbyZepas(
    double lonWest,
    double latSouth,
    double lonEast,
    double latNorth,
  ) async {
    final url = Uri.parse("$apiBaseUrl/api/v1/zones/zepa").replace(
      queryParameters: {
        'lonWest': lonWest.toString(),
        'latSouth': latSouth.toString(),
        'lonEast': lonEast.toString(),
        'latNorth': latNorth.toString(),
      },
    );

    _log.fine("Requesting data from API: $url");

    const maxAttempts = 3;
    const timeout = Duration(seconds: 15);
    final delays = [Duration(seconds: 2), Duration(seconds: 5)];

    List<Zepa>? result;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts && result == null; attempt++) {
      try {
        final response = await http.get(url).timeout(timeout);
        final Map<String, dynamic> body = json.decode(response.body);

        if (response.statusCode != 200) {
          throw Exception("Server error (${response.statusCode})");
        }

        if (body['status'] != 'success') {
          throw Exception(body['message']);
        }

        result = (body['data'] as List)
            .map((item) => Zepa.fromJson(item))
            .toList();

        _log.info("Success: ${result.length} zones loaded (attempt $attempt).");
      } catch (e) {
        lastError = e;
        _log.warning("ZEPA request failed (attempt $attempt/$maxAttempts): $e");
        if (attempt < maxAttempts) {
          await Future.delayed(delays[attempt - 1]);
        }
      }
    }

    if (result != null) return result;

    _log.severe("ZEPA request abandoned after $maxAttempts attempts.");
    throw lastError ?? StateError('Max retries exceeded');
  }
}
