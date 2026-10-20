// lib/src/ai_service.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'crash_detection_config.dart';

/// Runner function signature used for executing TFLite model inference.
typedef ModelInferenceRunner = void Function(Object input, Object output);

/// Service responsible for buffering sensor telemetry, evaluating the impact gate,
/// and executing TFLite Edge AI inference or fallback logic.
class AIService {
  Interpreter? _interpreter;
  final ModelInferenceRunner? _inferenceRunner;
  final List<List<double>> _sensorBuffer = [];

  /// The active crash detection configuration.
  final CrashDetectionConfig config;

  /// Callback invoked when a crash is detected, passing the model confidence probability.
  Function(double probability)? onCrashDetected;

  /// Callback for diagnostic logs emitted during analysis.
  Function(String message)? onLog;

  /// Callback invoked right before starting inference analysis.
  Function()? onInferenceAttempt;

  /// Callback invoked when an inference attempt completes.
  Function()? onInferenceCompleted;

  bool _isProcessing = false;
  bool _resetting = false;
  bool _isDisposed = false;
  int _recentSpikeCount = 0;

  /// Whether this service has been disposed.
  bool get isDisposed => _isDisposed;

  /// Current number of buffered sensor samples.
  int get bufferLength => _sensorBuffer.length;

  /// Creates an [AIService] configured with [config].
  AIService({
    CrashDetectionConfig? config,
    @visibleForTesting ModelInferenceRunner? inferenceRunner,
  }) : config = config ?? const CrashDetectionConfig.raw(),
       _inferenceRunner = inferenceRunner {
    this.config.validate();
  }

  /// Asynchronously loads the TFLite model from assets.
  Future<void> initialize({String? customModelPath}) async {
    if (_isDisposed) return;
    try {
      final modelPath = customModelPath ?? 'assets/crash_model.tflite';
      _interpreter = await Interpreter.fromAsset(modelPath);
      onLog?.call("🧠 TFLite AI Crash Model Loaded from $modelPath!");
    } catch (e) {
      onLog?.call(
        "❌ ERROR: Failed to load AI model ($e). Check assets folder.",
      );
    }
  }

  /// Ingests a 6-axis sensor sample: `[ax, ay, az, gx, gy, gz]`.
  ///
  /// Accelerations are expected in m/s² with gravity removed. The calculated g-force
  /// is checked against [CrashDetectionConfig.impactThresholdG]. If the threshold is met
  /// and the 250-sample window is full, inference analysis is triggered.
  void addData(List<double> data) {
    if (_resetting || _isDisposed) return;

    _sensorBuffer.add(data);

    if (_sensorBuffer.length > 250) {
      _sensorBuffer.removeAt(0); // Keep exactly 5 seconds
    }

    double ax = data[0], ay = data[1], az = data[2];
    double gForce = sqrt(pow(ax, 2) + pow(ay, 2) + pow(az, 2)) / 9.81;

    if (gForce >= config.impactThresholdG && _sensorBuffer.length == 250) {
      if (!_isProcessing) {
        onLog?.call(
          "⚠️ IMPACT: ${gForce.toStringAsFixed(1)} Gs. AI Analyzing...",
        );
        _runAIAnalysis(List.from(_sensorBuffer), gForce);
        if (!_resetting && !_isDisposed) {
          _sensorBuffer.clear();
        }
      }
    }
  }

  /// Clears buffered telemetry and resets processing flags.
  void resetProcessingState() {
    _resetting = true;
    _isProcessing = false;
    _sensorBuffer.clear();
    _resetting = false;
  }

  void _runAIAnalysis(List<List<double>> windowToAnalyze, double maxGForce) {
    if (_isDisposed) return;
    _isProcessing = true;
    onInferenceAttempt?.call();

    final bool hasModel = _interpreter != null || _inferenceRunner != null;

    if (!hasModel) {
      if (maxGForce >= config.fallbackImpactThresholdG) {
        _recentSpikeCount++;
        if (_recentSpikeCount >= 2) {
          onLog?.call("⚠️ Basic Threshold Crash Detected! (AI offline)");
          onCrashDetected?.call(1.0);
        } else {
          onLog?.call("⚠️ Spike detected. Awaiting temporal confirmation...");
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isDisposed) {
            _recentSpikeCount = 0;
          }
        });
      } else {
        onLog?.call("⚠️ Impact filtered by Basic Threshold (AI offline)");
      }
      _isProcessing = false;
      onInferenceCompleted?.call();
      return;
    }

    try {
      var input = [windowToAnalyze];
      var output = List.filled(1, 0.0).reshape([1, 1]);

      if (_inferenceRunner != null) {
        _inferenceRunner(input, output);
      } else {
        _interpreter?.run(input, output);
      }
      double crashProbability = output[0][0];

      if (crashProbability >= config.minCrashProbability) {
        onCrashDetected?.call(crashProbability);
      } else {
        onLog?.call(
          "✅ AI Filtered: Just a drop/bump. (${(crashProbability * 100).toStringAsFixed(1)}%)",
        );
      }
    } catch (e) {
      onLog?.call("❌ AI Error: $e. Falling back to basic threshold.");
      if (maxGForce >= config.fallbackImpactThresholdG) {
        onCrashDetected?.call(1.0);
      }
    } finally {
      _isProcessing = false;
      onInferenceCompleted?.call();
    }
  }

  /// Disposes of the service, closes the TFLite interpreter, and clears buffers.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _sensorBuffer.clear();
    _interpreter?.close();
    _interpreter = null;
  }
}
