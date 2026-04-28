import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';

class LocationProvider {
  static final Logger log = Logger("LocationProvider");
  static final LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );

  Future<void> _checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      log.warning("Location services are disabled");
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        log.warning("Location permissions are denied");
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      log.warning("Location permissions are permanently denied");
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }
  }

  Stream<Position> get positionStream async* {
    await _checkPermissions();
    yield* Geolocator.getPositionStream(locationSettings: _settings);
  }

  Future<Position> getCurrentLocation() async {
    await _checkPermissions();

    final position = await Geolocator.getCurrentPosition(locationSettings: _settings);
    log.fine(
      "Position retrieved | LAT=${position.latitude} | LON=${position.longitude}",
    );

    return position;
  }
}
