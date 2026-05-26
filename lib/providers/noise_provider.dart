import 'dart:async';
import 'package:logging/logging.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

class NoiseProvider {
  final Logger _log = Logger('NoiseProvider');

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _subscription;

  double _lastDecibels = 0.0;
  double get lastDecibels => _lastDecibels;

  final StreamController<double> _controller =
      StreamController<double>.broadcast();
  Stream<double> get decibelStream => _controller.stream;

  Future<void> init() async {
    final status = await Permission.microphone.status;
    if (status.isDenied) {
      await Permission.microphone.request();
    }

    if (!await Permission.microphone.isGranted) return;

    try {
      _noiseMeter = NoiseMeter();
      _subscription = _noiseMeter!.noise.listen(
        (reading) {
          double db = reading.meanDecibel;
          if (db < 0) db = 0;
          _lastDecibels = db;
          _controller.add(db);
        },
        onError: (error) {
          _log.severe("Fallo en la comunicación con el micrófono: $error");
        },
      );
    } catch (e) {
      _log.severe("Excepción al activar sensor de ruido: $e");
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
