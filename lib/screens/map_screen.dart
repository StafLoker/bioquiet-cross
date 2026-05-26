import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
  final List<AnimationController> _mapAnimations = [];

  LatLng? _userLatLng;
  Timer? _moveDebounce;
  bool _isWarningActive = false;

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
    for (final controller in _mapAnimations) {
      controller.dispose();
    }
    _mapAnimations.clear();
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
    unawaited(_initNoiseTracking());
  }

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
    _mapAnimations.add(controller);

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
        _mapAnimations.remove(controller);
        controller.dispose();
      }
    });

    controller.forward();
  }

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

  void _initLocationTracking() {
    _positionSubscription = _locationProvider.positionStream.listen(
      (pos) => _onNewPositionAvailable(pos),
      onError: (err) {
        log.severe("GPS sensor error: $err");
        if (_userLatLng == null) {
          Fluttertoast.showToast(
            msg: "Location unavailable. Enable GPS and grant permissions.",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.black87,
            textColor: Colors.white,
          );
        }
      },
    );
  }

  void _onNewPositionAvailable(Position pos) {
    final newPos = LatLng(pos.latitude, pos.longitude);
    final isFirstFix = _userLatLng == null;
    setState(() => _userLatLng = newPos);

    if (isFirstFix) {
      _fetchVisibleZones();
    } else {
      _animatedMapMove(newPos, _mapController.camera.zoom);
      _zepaProvider.evaluatePosition(newPos);
    }
  }

  Future<void> _fetchVisibleZones() async {
    if (!mounted) return;
    final pos = _userLatLng;
    if (pos == null) return;
    final b = _mapController.camera.visibleBounds;
    await _zepaProvider.fetchZones(b.west, b.south, b.east, b.north);
    if (mounted) _zepaProvider.evaluatePosition(pos);
  }

  Color _getIndicatorStatusColor() {
    final t = _currentlyInsideZepa!.noiseThresholds;
    if (_lastDecibelReading >= t.dbWarning) return Colors.red;
    if (_lastDecibelReading >= t.dbSafe) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final userPos = _userLatLng;
    if (userPos == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text("Waiting for GPS coordinates..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userPos,
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
                  if (zepa.geometry.type != 'Polygon') return <Polygon>[];
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
                    point: userPos,
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

          if (_currentlyInsideZepa != null)
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
          try {
            final p = await _locationProvider.getCurrentLocation();
            _animatedMapMove(LatLng(p.latitude, p.longitude), 15.0);
          } catch (e) {
            log.warning("Could not retrieve current location: $e");
          }
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
