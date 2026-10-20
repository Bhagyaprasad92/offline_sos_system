// lib/src/safepulse_engine.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'sensor_service.dart';
import 'enums.dart';
import 'crash_detection_config.dart';

/// Represents a discrete anomaly or physical crash detected by the hardware sensors and AI model.
class CrashEvent {
  /// The AI's confidence that the event is an actual crash. Ranges from 0.0 to 1.0.
  final double probability;

  /// The exact timestamp when the anomaly was detected.
  final DateTime timestamp;

  /// Creates a [CrashEvent] with the given [probability] and [timestamp].
  CrashEvent({required this.probability, required this.timestamp});
}

/// The core headless engine responsible for orchestrating sensor telemetry and AI inference.
///
/// It listens to the device's accelerometer and gyroscope, buffers the data, and passes
/// it to the TensorFlow Lite model for crash detection according to [detectionConfig].
class SafePulseEngine {
  /// The optional path to a custom `.tflite` model asset. If null, the default bundled model is used.
  final String? customModelPath;

  /// The active crash detection configuration policy.
  final CrashDetectionConfig detectionConfig;

  /// The internal AI service responsible for handling TFLite inference.
  final AIService aiService;

  /// The internal sensor service responsible for gathering hardware telemetry.
  final SensorService sensorService;

  final DateTime Function() _clock;

  // Streams
  final _crashStreamController = StreamController<CrashEvent>.broadcast();

  /// A stream that emits a [CrashEvent] whenever the engine confidently detects a crash.
  Stream<CrashEvent> get onCrashDetected => _crashStreamController.stream;

  /// A stream of [LogMessage] objects for debugging and system status updates.
  final logStream = StreamController<LogMessage>.broadcast();

  bool _isRunning = false;
  bool _isDisposed = false;
  DateTime? _lastEmergencyTrigger;

  /// Whether the engine is currently running and processing telemetry.
  bool get isRunning => _isRunning;

  /// Whether the engine has been disposed.
  bool get isDisposed => _isDisposed;

  /// Initializes the engine with optional custom model asset, detection configuration,
  /// and injectable services.
  SafePulseEngine({
    this.customModelPath,
    CrashDetectionConfig? detectionConfig,
    AIService? aiService,
    SensorService? sensorService,
    @visibleForTesting DateTime Function()? clock,
  }) : detectionConfig = detectionConfig ?? const CrashDetectionConfig.raw(),
       aiService =
           aiService ??
           AIService(
             config: detectionConfig ?? const CrashDetectionConfig.raw(),
           ),
       sensorService = sensorService ?? SensorService(),
       _clock = clock ?? DateTime.now {
    this.detectionConfig.validate();
    _initializeServices();
  }

  void _initializeServices() {
    // Bind loggers
    aiService.onLog = (msg) => log(msg, level: LogLevel.info);
    sensorService.onLog = (msg) => log(msg, level: LogLevel.info);

    sensorService.onRawData = (data) {
      if (_isDisposed) return;
      aiService.addData(data);
    };

    aiService.onCrashDetected = (probability) {
      if (_isDisposed) return;
      _handleCrash(probability);
    };

    // Init AI
    aiService.initialize(customModelPath: customModelPath);
  }

  /// Dispatches a log [message] with the specified [level] to the [logStream].
  void log(String message, {LogLevel level = LogLevel.info}) {
    if (_isDisposed || logStream.isClosed) return;
    logStream.add(LogMessage(message, level: level));
  }

  /// Starts the engine. It will begin gathering sensor telemetry and evaluating it against the AI model.
  ///
  /// Throws a [StateError] if called after the engine has been disposed.
  Future<void> start() async {
    if (_isDisposed) {
      throw StateError(
        'Cannot start SafePulseEngine after it has been disposed.',
      );
    }
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
    if (_isDisposed || _crashStreamController.isClosed) return;

    if (_lastEmergencyTrigger != null &&
        detectionConfig.cooldown > Duration.zero) {
      final diff = _clock().difference(_lastEmergencyTrigger!);
      if (diff < detectionConfig.cooldown) {
        return;
      }
    }

    _lastEmergencyTrigger = _clock();
    log("🚀 CRASH DETECTED AUTONOMOUSLY BY AI!", level: LogLevel.critical);

    _crashStreamController.add(
      CrashEvent(probability: probability, timestamp: _lastEmergencyTrigger!),
    );
  }

  /// Disposes of the engine resources, closing all active streams, stopping sensor
  /// telemetry, and shutting down the AI interpreter.
  ///
  /// This operation is idempotent. Calling it multiple times is safe.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _isRunning = false;
    unawaited(sensorService.stop());
    aiService.dispose();
    _crashStreamController.close();
    logStream.close();
  }
}
