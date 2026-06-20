// lib/src/safepulse_engine.dart
import 'dart:async';
import 'ai_service.dart';
import 'sensor_service.dart';
import 'enums.dart';

class CrashEvent {
  final double probability;
  final DateTime timestamp;

  CrashEvent({
    required this.probability,
    required this.timestamp,
  });
}

class SafePulseEngine {
  final String? customModelPath;
  
  SafePulseEngine({this.customModelPath}) {
    _initializeServices();
  }

  // Services
  final AIService aiService = AIService();
  final SensorService sensorService = SensorService();

  // Streams
  final _crashStreamController = StreamController<CrashEvent>.broadcast();
  Stream<CrashEvent> get onCrashDetected => _crashStreamController.stream;

  final logStream = StreamController<LogMessage>.broadcast();

  bool _isRunning = false;
  DateTime? _lastEmergencyTrigger;

  void _initializeServices() {
    // Bind loggers
    aiService.onLog = (msg) => log(msg, level: LogLevel.info);
    sensorService.onLog = (msg) => log(msg, level: LogLevel.info);

    sensorService.onRawData = (data) {
      aiService.addData(data);
    };

    aiService.onCrashDetected = (probability) {
      _handleCrash(probability);
    };

    // Init AI
    aiService.initialize(customModelPath: customModelPath);
  }

  void log(String message, {LogLevel level = LogLevel.info}) {
    logStream.add(LogMessage(message, level: level));
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    log("🛡️ SafePulse Engine STARTED.");
    sensorService.start();
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    await sensorService.stop();
    log("🛑 SafePulse Engine STOPPED.");
  }

  void _handleCrash(double probability) {
    if (_lastEmergencyTrigger != null) {
      final diff = DateTime.now().difference(_lastEmergencyTrigger!);
      if (diff.inSeconds < 30) {
        return;
      }
    }

    _lastEmergencyTrigger = DateTime.now();
    log("🚀 CRASH DETECTED AUTONOMOUSLY BY AI!", level: LogLevel.critical);
    
    _crashStreamController.add(CrashEvent(
      probability: probability,
      timestamp: DateTime.now(),
    ));
  }

  void dispose() {
    logStream.close();
    _crashStreamController.close();
    aiService.dispose();
  }
}
