// lib/src/safepulse_engine.dart
import 'dart:async';
import 'ai_service.dart';
import 'sensor_service.dart';
import 'enums.dart';

/// Represents a discrete anomaly or physical crash detected by the hardware sensors and AI model.
class CrashEvent {
  /// The AI's confidence that the event is an actual crash. Ranges from 0.0 to 1.0.
  final double probability;

  /// The exact timestamp when the anomaly was detected.
  final DateTime timestamp;

  /// Creates a [CrashEvent] with the given [probability] and [timestamp].
  CrashEvent({
    required this.probability,
    required this.timestamp,
  });
}

/// The core headless engine responsible for orchestrating sensor telemetry and AI inference.
///
/// It listens to the device's accelerometer and gyroscope, buffers the data, and passes
/// it to the TensorFlow Lite model for crash detection.
class SafePulseEngine {
  /// The optional path to a custom `.tflite` model asset. If null, the default bundled model is used.
  final String? customModelPath;
  
  /// Initializes the engine, optionally overriding the underlying AI model via [customModelPath].
  SafePulseEngine({this.customModelPath}) {
    _initializeServices();
  }

  /// The internal AI service responsible for handling TFLite inference.
  final AIService aiService = AIService();

  /// The internal sensor service responsible for gathering hardware telemetry.
  final SensorService sensorService = SensorService();

  // Streams
  final _crashStreamController = StreamController<CrashEvent>.broadcast();

  /// A stream that emits a [CrashEvent] whenever the engine confidently detects a crash.
  Stream<CrashEvent> get onCrashDetected => _crashStreamController.stream;

  /// A stream of [LogMessage] objects for debugging and system status updates.
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

  /// Dispatches a log [message] with the specified [level] to the [logStream].
  void log(String message, {LogLevel level = LogLevel.info}) {
    logStream.add(LogMessage(message, level: level));
  }

  /// Starts the engine. It will begin gathering sensor telemetry and evaluating it against the AI model.
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    log("🛡️ SafePulse Engine STARTED.");
    sensorService.start();
  }

  /// Stops the engine. Sensor data gathering is halted to conserve battery.
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

  /// Disposes of the engine resources, closing all active streams and the AI interpreter.
  void dispose() {
    logStream.close();
    _crashStreamController.close();
    aiService.dispose();
  }
}
