import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../models/zepa.dart';

class ZepaService {
  static final _logger = Logger("ZepaService");
  
  // IP del host local para acceso desde el emulador de Android
  static const String _apiBaseUrl = "http://10.0.2.2:5000";

  // Obtiene el listado de zonas ZEPA presentes en el área geográfica visible.
  Future<List<Zepa>> fetchNearbyZepas(
    double lonWest,
    double latSouth,
    double lonEast,
    double latNorth,
  ) async {
    final url = Uri.parse("$_apiBaseUrl/api/v1/zones/zepa").replace(
      queryParameters: {
        'lonWest': lonWest.toString(),
        'latSouth': latSouth.toString(),
        'lonEast': lonEast.toString(),
        'latNorth': latNorth.toString(),
      },
    );

    _logger.info("Solicitando datos a la API: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);

        if (body['status'] == 'success') {
          final List<dynamic> data = body['data'];
          final List<Zepa> zepas = data.map((item) => Zepa.fromJson(item)).toList();

          _logger.info("Operación exitosa: ${zepas.length} zonas cargadas.");
          return zepas;
        } else {
          _logger.warning("Error de negocio en la API: ${body['message']}");
          throw Exception(body['message']);
        }
      } else {
        _logger.severe("Fallo de conexión. Código: ${response.statusCode}");
        throw Exception("Error de servidor (${response.statusCode})");
      }
    } catch (e) {
      _logger.severe("Error durante la petición ZEPA: $e");
      rethrow;
    }
  }
}
