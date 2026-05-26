import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';
import '../providers/location_provider.dart';
import '../providers/noise_provider.dart';
import '../providers/zepa_provider.dart';
import '../models/zepa.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final Logger log = Logger('MapScreen');
  final MapController _mapController = MapController();
  final LocationProvider _locationProvider = LocationProvider();
  final NoiseProvider _noiseProvider = NoiseProvider();
  final ZepaProvider _zepaProvider = ZepaProvider();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<double>? _noiseSubscription;
  StreamSubscription<ZepaState>? _zepaSubscription;

  LatLng _userLatLng = const LatLng(40.4167, -3.7033);
  bool _isFirstFixDone = false;
  Timer? _moveDebounce;
  bool _isWarningActive = false;

  // Estado derivado del ZepaProvider para rebuild de UI
  List<Zepa> _loadedZepas = [];
  Zepa? _currentlyInsideZepa;
  bool _isApiLoading = false;
  double _lastDecibelReading = 0.0;

  @override
  void initState() {
    super.initState();
    _setupLifecycle();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _noiseSubscription?.cancel();
    _zepaSubscription?.cancel();
    _noiseProvider.dispose();
    _zepaProvider.dispose();
    _moveDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _setupLifecycle() {
    _zepaSubscription = _zepaProvider.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _loadedZepas = state.zones;
        _isApiLoading = state.isLoading;
        _currentlyInsideZepa = state.currentZone;
      });
    });

    _zepaProvider.startPersistenceLoop(() => _lastDecibelReading);
    _initLocationTracking();
    // unawaited: el Future se gestiona internamente con guardas de mounted
    unawaited(_initNoiseTracking());
  }

  // --- ANIMACIÓN DE MAPA ---

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  // --- RUIDO ---

  Future<void> _initNoiseTracking() async {
    await _noiseProvider.init();
    if (!mounted) return;
    _noiseSubscription = _noiseProvider.decibelStream.listen((db) {
      _verifyAcousticImpact(db);
      if (db.toInt() != _lastDecibelReading.toInt()) {
        setState(() => _lastDecibelReading = db);
      } else {
        _lastDecibelReading = db;
      }
    });
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
        content: Text(
          "Aviso: ${_currentlyInsideZepa!.name} es zona sensible. ¡Modera el ruido!",
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- LOCALIZACIÓN ---

  void _initLocationTracking() {
    _positionSubscription = _locationProvider.positionStream.listen(
      (pos) => _onNewPositionAvailable(pos),
      onError: (err) => log.severe("Error de sensor GPS: $err"),
    );
  }

  void _onNewPositionAvailable(Position pos) {
    final newPos = LatLng(pos.latitude, pos.longitude);
    setState(() => _userLatLng = newPos);

    if (!_isFirstFixDone) {
      _isFirstFixDone = true;
      _mapController.move(newPos, 15.0);
      _fetchVisibleZones();
    } else {
      _zepaProvider.evaluatePosition(newPos);
    }
  }

  // --- ZONAS ---

  Future<void> _fetchVisibleZones() async {
    if (!mounted) return;
    final b = _mapController.camera.visibleBounds;
    await _zepaProvider.fetchZones(b.west, b.south, b.east, b.north);
    if (mounted) _zepaProvider.evaluatePosition(_userLatLng);
  }

  // --- UI ---

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
                  _moveDebounce = Timer(
                    const Duration(milliseconds: 400),
                    _fetchVisibleZones,
                  );
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
                  return [
                    Polygon(
                      points: ring
                          .map((v) => LatLng(v[1].toDouble(), v[0].toDouble()))
                          .toList(),
                      color: Colors.green.withAlpha(65),
                      borderColor: Colors.green,
                      borderStrokeWidth: 1.0,
                      isFilled: true,
                    ),
                  ];
                }).toList(),
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLatLng,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_history,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Indicador de red
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4),
                ],
              ),
              child: Center(
                child: _isApiLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.green,
                        ),
                      )
                    : Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
          ),

          // Monitor acústico
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _getIndicatorStatusColor(),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8),
                  ],
                ),
                child: Text(
                  "${_lastDecibelReading.toInt()} dB",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),

          // Botones de zoom
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
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
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: () {
          final targetZoom = _mapController.camera.zoom + delta;
          _animatedMapMove(_mapController.camera.center, targetZoom);
        },
      ),
    );
  }
}
