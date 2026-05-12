import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/location_provider.dart';
import '../models/zepa.dart';
import '../services/zepa_service.dart';
import '../services/statistics_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _logger = Logger('MapScreen');
  final MapController _mapController = MapController();
  final LocationProvider _locationProvider = LocationProvider();
  final ZepaService _zepaService = ZepaService();
  final StatisticsService _statsService = StatisticsService();
  
  // Gestión de ubicación y geocercas
  StreamSubscription<Position>? _positionSubscription;
  LatLng _userLatLng = const LatLng(40.4167, -3.7033);
  bool _isFirstFixDone = false;
  List<Zepa> _loadedZepas = [];
  Timer? _moveDebounce;
  Zepa? _currentlyInsideZepa;
  bool _isWarningActive = false;

  // Monitorización de audio
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  double _lastDecibelReading = 0.0;
  bool _isApiLoading = false;
  
  // Guardado periódico de datos
  Timer? _persistenceTimer;

  @override
  void initState() {
    super.initState();
    _setupMapLifecycle();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _noiseSubscription?.cancel();
    _moveDebounce?.cancel();
    _persistenceTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _setupMapLifecycle() {
    _initLocationTracking();
    _initNoiseSensing();
    _startPersistenceLoop();
  }

  // --- LÓGICA DE SENSORES Y ANIMACIÓN ---

  // Realiza un movimiento de cámara suave hacia el destino y zoom indicados.
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    final animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> _initNoiseSensing() async {
    final status = await Permission.microphone.status;
    if (status.isDenied) {
      await Permission.microphone.request();
    }

    if (!mounted) return;

    if (await Permission.microphone.isGranted) {
      try {
        _noiseMeter = NoiseMeter();
        _noiseSubscription = _noiseMeter?.noise.listen(
          (reading) {
            double db = reading.meanDecibel;
            if (db < 0) db = 0; 
            
            setState(() {
              _lastDecibelReading = db;
            });
            
            _verifyAcousticImpact(db);
          },
          onError: (error) {
            _logger.severe("Fallo en la comunicación con el micrófono: $error");
          },
        );
      } catch (e) {
        _logger.severe("Excepción al activar sensor de ruido: $e");
      }
    }
  }

  void _verifyAcousticImpact(double currentDb) {
    if (_currentlyInsideZepa == null) return;

    final thresholds = _currentlyInsideZepa!.noiseThresholds;
    if (currentDb >= thresholds.dbWarning) {
      if (!_isWarningActive) {
        _isWarningActive = true;
        _displayNoiseAlert();
      }
    } else {
      _isWarningActive = false;
    }
  }

  void _displayNoiseAlert() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Aviso: ${_currentlyInsideZepa!.name} es zona sensible. ¡Modera el ruido!"),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _startPersistenceLoop() {
    _persistenceTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentlyInsideZepa != null) {
        _statsService.saveNoiseRecord(_currentlyInsideZepa!, _lastDecibelReading);
      }
    });
  }

  // --- LOCALIZACIÓN Y ANÁLISIS GEOGRÁFICO ---

  void _initLocationTracking() {
    _positionSubscription = _locationProvider.positionStream.listen(
      (pos) => _onNewPositionAvailable(pos),
      onError: (err) => _logger.severe("Error de sensor GPS: $err"),
    );
  }

  void _onNewPositionAvailable(Position pos) {
    final newPos = LatLng(pos.latitude, pos.longitude);
    setState(() => _userLatLng = newPos);
    
    if (!_isFirstFixDone) {
      _isFirstFixDone = true;
      // Centramos instantáneamente la primera vez para que las peticiones a la API sean correctas.
      _mapController.move(newPos, 15.0);
      _fetchVisibleZones(); 
    } else {
      _evaluateUserProximity(newPos);
    }
  }

  bool _isInsideGeometricArea(LatLng p, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    var inside = false;
    var j = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > p.latitude) != (polygon[j].latitude > p.latitude)) &&
          (p.longitude < (polygon[j].longitude - polygon[i].longitude) * (p.latitude - polygon[i].latitude) / (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  void _evaluateUserProximity(LatLng currentPos) {
    Zepa? detectedZone;
    for (var zepa in _loadedZepas) {
      if (zepa.geometry.type == 'Polygon') {
        final ring = (zepa.geometry.coordinates as List)[0] as List;
        final vertices = ring.map((v) => LatLng(v[1].toDouble(), v[0].toDouble())).toList();
        if (_isInsideGeometricArea(currentPos, vertices)) {
          detectedZone = zepa;
          break;
        }
      }
    }

    if (detectedZone != _currentlyInsideZepa) {
      setState(() => _currentlyInsideZepa = detectedZone);
      if (detectedZone != null) {
        _logger.info("Entrada en zona: ${detectedZone.name}");
      } else {
        _logger.info("El dispositivo ya no se encuentra en una ZEPA.");
      }
    }
  }

  // --- GESTIÓN DE DATOS ---

  Future<void> _fetchVisibleZones() async {
    if (!mounted) return;
    setState(() => _isApiLoading = true);
    
    final viewBounds = _mapController.camera.visibleBounds;
    try {
      final zones = await _zepaService.fetchNearbyZepas(
        viewBounds.west, viewBounds.south, viewBounds.east, viewBounds.north,
      );
      if (mounted) {
        setState(() {
          _loadedZepas = zones;
          _isApiLoading = false;
        });
        // Comprobamos proximidad nada más cargar datos por si el usuario está quieto
        _evaluateUserProximity(_userLatLng);
      }
    } catch (e) {
      _logger.severe("Fallo crítico al actualizar zonas: $e");
      if (mounted) setState(() => _isApiLoading = false);
    }
  }

  Color _getIndicatorStatusColor() {
    if (_currentlyInsideZepa == null) return Colors.grey.withAlpha(160);
    
    final t = _currentlyInsideZepa!.noiseThresholds;
    if (_lastDecibelReading >= t.dbWarning) return Colors.red;
    if (_lastDecibelReading >= t.dbSafe) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLatLng,
              initialZoom: 15.0,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _moveDebounce?.cancel();
                  _moveDebounce = Timer(const Duration(milliseconds: 400), _fetchVisibleZones);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'es.upm.etsisi.mad.bioquiet_cross',
              ),
              PolygonLayer(
                polygons: _loadedZepas.expand((zepa) {
                  final ring = (zepa.geometry.coordinates as List)[0] as List;
                  return [Polygon(
                    points: ring.map((v) => LatLng(v[1].toDouble(), v[0].toDouble())).toList(),
                    color: Colors.green.withAlpha(65),
                    borderColor: Colors.green,
                    borderStrokeWidth: 1.0,
                    isFilled: true,
                  )];
                }).toList(),
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLatLng,
                    width: 40, height: 40,
                    child: const Icon(Icons.location_history, color: Colors.blue, size: 40),
                  ),
                ],
              ),
            ],
          ),
          
          // Indicador de red
          Positioned(
            top: 50, left: 20,
            child: Container(
              width: 45, height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4)],
              ),
              child: Center(
                child: _isApiLoading 
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                  : Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              ),
            ),
          ),

          // Monitor acústico
          Positioned(
            top: 50, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                decoration: BoxDecoration(
                  color: _getIndicatorStatusColor(),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8)],
                ),
                child: Text(
                  "${_lastDecibelReading.toInt()} dB",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ),

          // Botones de zoom
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMapControl(Icons.remove, -1.0),
                const SizedBox(width: 30),
                _buildMapControl(Icons.add, 1.0),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () async {
          final p = await _locationProvider.getCurrentLocation();
          _animatedMapMove(LatLng(p.latitude, p.longitude), 15.0);
        },
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }

  Widget _buildMapControl(IconData icon, double delta) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4)]
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: () {
          final targetZoom = _mapController.camera.zoom + delta;
          _animatedMapMove(_mapController.camera.center, targetZoom);
        }
      ),
    );
  }
}
