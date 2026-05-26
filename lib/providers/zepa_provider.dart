import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';

import '../models/zepa.dart';
import '../services/statistics_service.dart';
import '../services/zepa_service.dart';

class ZepaState {
  final List<Zepa> zones;
  final bool isLoading;
  final Zepa? currentZone;

  const ZepaState({
    required this.zones,
    required this.isLoading,
    required this.currentZone,
  });
}

class ZepaProvider {
  final Logger _log = Logger('ZepaProvider');
  final ZepaService _zepaService = ZepaService();
  final StatisticsService _statsService = StatisticsService();

  List<Zepa> _zones = [];

  List<Zepa> get zones => _zones;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Zepa? _currentZone;

  Zepa? get currentZone => _currentZone;

  final StreamController<ZepaState> _controller =
      StreamController<ZepaState>.broadcast();

  Stream<ZepaState> get stateStream => _controller.stream;

  Timer? _persistenceTimer;

  void startPersistenceLoop(double Function() getDecibels) {
    _persistenceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_currentZone != null) {
        _statsService.addRecord(_currentZone!, getDecibels());
      }
    });
  }

  Future<void> fetchZones(
    double west,
    double south,
    double east,
    double north,
  ) async {
    _isLoading = true;
    _controller.add(
      ZepaState(zones: _zones, isLoading: true, currentZone: _currentZone),
    );

    try {
      _zones = await _zepaService.fetchNearbyZepas(west, south, east, north);
    } catch (e) {
      _log.severe("Fallo crítico al actualizar zonas: $e");
    } finally {
      _isLoading = false;
      _controller.add(
        ZepaState(zones: _zones, isLoading: false, currentZone: _currentZone),
      );
    }
  }

  void evaluatePosition(LatLng pos) {
    Zepa? detected;
    for (var zepa in _zones) {
      if (zepa.geometry.type == 'Polygon') {
        final ring = (zepa.geometry.coordinates as List)[0] as List;
        final vertices = ring
            .map((v) => LatLng(v[1].toDouble(), v[0].toDouble()))
            .toList();
        if (_isInsidePolygon(pos, vertices)) {
          detected = zepa;
          break;
        }
      }
    }

    if (detected != _currentZone) {
      _currentZone = detected;
      if (detected != null) {
        _log.info("Entrada en zona: ${detected.name}");
      } else {
        _log.info("El dispositivo ya no se encuentra en una ZEPA.");
      }
      _controller.add(
        ZepaState(
          zones: _zones,
          isLoading: _isLoading,
          currentZone: _currentZone,
        ),
      );
    }
  }

  bool _isInsidePolygon(LatLng p, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    var inside = false;
    var j = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > p.latitude) !=
              (polygon[j].latitude > p.latitude)) &&
          (p.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (p.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  void dispose() {
    _persistenceTimer?.cancel();
    _controller.close();
  }
}
