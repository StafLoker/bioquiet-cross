import 'package:flutter/cupertino.dart';
import 'package:logging/logging.dart';

class MapScreen extends StatefulWidget{
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>{
  final log = Logger('MapScreen');

  @override
  Widget build(BuildContext context) {
    log.fine("Build screen");

    return const CupertinoPageScaffold(
      child: Center(
        child: Text('Map Screen'),
      ),
    );
  }
}