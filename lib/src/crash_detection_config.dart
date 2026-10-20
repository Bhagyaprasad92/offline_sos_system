import 'package:flutter/foundation.dart';

/// Configuration policy for crash and anomaly detection in [SafePulseEngine].
///
/// Encapsulates thresholds for the hardware sensor gate, Edge AI model confidence,
/// fallback heuristic, and duplicate event suppression cooldown.
@immutable
class CrashDetectionConfig {
  /// Default impact threshold gate in g-force (3.0 G).
  static const double defaultImpactThresholdG = 3.0;

  /// Default minimum model confidence probability required to trigger a crash event (0.25).
  static const double defaultMinCrashProbability = 0.25;

  /// Default fallback heuristic impact threshold in g-force (5.0 G).
  static const double defaultFallbackImpactThresholdG = 5.0;

  /// Default cooldown duration to suppress duplicate crash events (30 seconds).
  static const Duration defaultCooldown = Duration(seconds: 30);

  /// The sensor impact threshold in g-force (units of g, ~9.81 m/s²) required to
  /// trigger neural inference evaluation or fallback inspection.
  ///
  /// Sensor readings are converted to g-force using user acceleration (with gravity removed).
  /// When calculated g-force is greater than or equal to [impactThresholdG] and the sensor
  /// window buffer is filled (250 samples / 5 seconds at 50 Hz), inference is evaluated.
  ///
  /// Must be a positive finite number (> 0). Defaults to [defaultImpactThresholdG] (3.0 G).
  final double impactThresholdG;

  /// The minimum acceptable model confidence probability (range `0.0` to `1.0`)
  /// required to classify an anomaly window as a crash event.
  ///
  /// A detection occurs when the model confidence is greater than or equal to
  /// [minCrashProbability]. Defaults to [defaultMinCrashProbability] (0.25).
  final double minCrashProbability;

  /// The impact threshold in g-force used by the fallback heuristic when the AI model
  /// is unavailable, offline, or encounters an inference error.
  ///
  /// When the model is offline, two consecutive impacts at or above this threshold
  /// within 2 seconds confirm a crash. On inference error, a single impact at or above
  /// this threshold triggers a fallback crash event with probability 1.0.
  ///
  /// Must be a positive finite number (> 0). Defaults to [defaultFallbackImpactThresholdG] (5.0 G).
  final double fallbackImpactThresholdG;

  /// The cooldown duration used to suppress duplicate crash events.
  ///
  /// After a crash is detected, subsequent detections occurring within this duration
  /// are suppressed. Setting this to [Duration.zero] disables cooldown suppression.
  /// Must not be negative. Defaults to [defaultCooldown] (30 seconds).
  final Duration cooldown;

  /// Creates a validated [CrashDetectionConfig].
  ///
  /// Throws an [ArgumentError] if any value violates validation constraints:
  /// - [impactThresholdG] must be a finite positive number (> 0).
  /// - [minCrashProbability] must be a finite number between `0.0` and `1.0` inclusive.
  /// - [fallbackImpactThresholdG] must be a finite positive number (> 0).
  /// - [cooldown] cannot be negative.
  CrashDetectionConfig({
    this.impactThresholdG = defaultImpactThresholdG,
    this.minCrashProbability = defaultMinCrashProbability,
    this.fallbackImpactThresholdG = defaultFallbackImpactThresholdG,
    this.cooldown = defaultCooldown,
  }) {
    validate();
  }

  /// Internal const constructor for default definitions and compile-time constants.
  const CrashDetectionConfig.raw({
    this.impactThresholdG = defaultImpactThresholdG,
    this.minCrashProbability = defaultMinCrashProbability,
    this.fallbackImpactThresholdG = defaultFallbackImpactThresholdG,
    this.cooldown = defaultCooldown,
  });

  /// Validates the configuration values and throws [ArgumentError] on invalid values.
  void validate() {
    if (impactThresholdG.isNaN ||
        impactThresholdG.isInfinite ||
        impactThresholdG <= 0) {
      throw ArgumentError.value(
        impactThresholdG,
        'impactThresholdG',
        'Impact threshold must be a finite positive number (> 0).',
      );
    }
    if (minCrashProbability.isNaN ||
        minCrashProbability < 0.0 ||
        minCrashProbability > 1.0) {
      throw ArgumentError.value(
        minCrashProbability,
        'minCrashProbability',
        'Minimum crash probability must be between 0.0 and 1.0 inclusive.',
      );
    }
    if (fallbackImpactThresholdG.isNaN ||
        fallbackImpactThresholdG.isInfinite ||
        fallbackImpactThresholdG <= 0) {
      throw ArgumentError.value(
        fallbackImpactThresholdG,
        'fallbackImpactThresholdG',
        'Fallback impact threshold must be a finite positive number (> 0).',
      );
    }
    if (cooldown.isNegative) {
      throw ArgumentError.value(
        cooldown,
        'cooldown',
        'Cooldown duration cannot be negative.',
      );
    }
  }

  /// Returns a copy of this configuration with the given fields replaced by the new values.
  CrashDetectionConfig copyWith({
    double? impactThresholdG,
    double? minCrashProbability,
    double? fallbackImpactThresholdG,
    Duration? cooldown,
  }) {
    return CrashDetectionConfig(
      impactThresholdG: impactThresholdG ?? this.impactThresholdG,
      minCrashProbability: minCrashProbability ?? this.minCrashProbability,
      fallbackImpactThresholdG:
          fallbackImpactThresholdG ?? this.fallbackImpactThresholdG,
      cooldown: cooldown ?? this.cooldown,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CrashDetectionConfig &&
        other.impactThresholdG == impactThresholdG &&
        other.minCrashProbability == minCrashProbability &&
        other.fallbackImpactThresholdG == fallbackImpactThresholdG &&
        other.cooldown == cooldown;
  }

  @override
  int get hashCode => Object.hash(
    impactThresholdG,
    minCrashProbability,
    fallbackImpactThresholdG,
    cooldown,
  );

  @override
  String toString() {
    return 'CrashDetectionConfig('
        'impactThresholdG: $impactThresholdG, '
        'minCrashProbability: $minCrashProbability, '
        'fallbackImpactThresholdG: $fallbackImpactThresholdG, '
        'cooldown: $cooldown)';
  }
}
