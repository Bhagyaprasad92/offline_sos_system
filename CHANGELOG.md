## 0.0.6

* **Configurable Crash Detection:** Introduced `CrashDetectionConfig` to allow custom thresholds for the sensor impact gate (`impactThresholdG`), minimum model confidence probability (`minCrashProbability`), fallback impact threshold (`fallbackImpactThresholdG`), and duplicate suppression cooldown (`cooldown`).
* **Backward Compatibility:** Preserved all existing default behaviors (3.0 G impact gate, 0.25 probability, 5.0 G fallback, 30s cooldown). Applications calling `SafePulseEngine()` without arguments continue to behave identically.
* **Lifecycle & Reliability Improvements:** Fixed engine disposal to properly cancel active sensor subscriptions and timers, guarded stream controllers against post-disposal emissions, prevented restarted sensor retries after stop, and ensured idempotent disposal.
* **Comprehensive Automated Tests:** Added full test coverage for configuration validation, exact threshold boundaries, offline fallback heuristics, duplicate suppression, and engine lifecycle.

## 0.0.5

* Fixed dangling library doc comment lint to ensure perfect pub.dev score.

## 0.0.4

* Added comprehensive Dartdoc comments to all public API elements for perfect pub.dev scoring.

## 0.0.3

* Massive documentation overhaul: Introduced advanced Edge AI architecture guides and high-conversion implementation examples.

## 0.0.2

* Initial release.
* Extracted the core offline detection engine into a standalone, pure Dart package.
* Integrated `sensors_plus` for continuous accelerometer and gyroscope telemetry.
* Integrated `tflite_flutter` for offline, on-device anomaly inference.
* Added support for optional `customModelPath` injection with a bundled default model fallback.
* Exposed `Stream<CrashEvent>` for decoupled app-layer integration.
