<h1 align="center">Offline SOS System 🛡️</h1>

<p align="center">
  <strong>Edge AI • Zero-Latency Compute • 100% Offline Safety</strong>
</p>

<p align="center">
  <a href="https://pub.dev/packages/offline_sos_system"><img src="https://img.shields.io/pub/v/offline_sos_system.svg" alt="Pub Version"></a>
  <a href="https://github.com/bhagyaprasad92/offline_sos_system/blob/main/LICENSE"><img src="https://img.shields.io/github/license/bhagyaprasad92/offline_sos_system" alt="License"></a>
  <img src="https://img.shields.io/badge/Platform-Flutter-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/AI-TFLite-orange.svg" alt="TFLite">
</p>

---

## ⚡ The Problem: Cloud Dependency is a Fatal Flaw
In critical emergencies, network infrastructure is often the first thing to fail. Traditional safety applications rely entirely on the cloud to process data and detect crashes, leading to fatal latencies or complete system failure when offline.

**Offline SOS System** revolutionizes application safety. By harnessing **Edge AI** and high-frequency hardware telemetry (accelerometer & gyroscope), this headless engine detects physical crashes and anomalies in real-time, **100% on-device**. Zero ping. Zero cloud dependency. Maximum privacy.

## ✨ Capabilities
* 🧠 **Neural Telemetry:** Processes raw hardware data locally through an advanced, bundled TensorFlow Lite (`tflite_flutter`) model.
* ⚡ **Zero-Latency Compute:** By bringing inference to the edge, anomalies are flagged in milliseconds.
* 🔌 **Decoupled Architecture:** Strictly headless. We handle the complex math and ML; your app handles the UI, GPS, or SMS dispatching.
* ⚙️ **Configurable Policy:** Fine-tune impact gates, model confidence thresholds, fallback triggers, and duplicate suppression cooldowns.
* 📦 **Bring Your Own Model:** Seamlessly inject your own custom-trained `.tflite` model or fall back on our highly optimized default.

## 🚀 Instant Integration

We built this engine for maximum developer velocity. Instantiate the engine and start listening to the stream in under 3 lines of code.

### 1. Install
```yaml
dependencies:
  offline_sos_system: ^0.0.6
```

### 2. Implement
```dart
import 'package:offline_sos_system/offline_sos_system.dart';

// 1. Initialize the Edge AI Engine (uses safe production defaults)
final SafePulseEngine engine = SafePulseEngine();

// 2. Listen for ultra-fast crash inferences
engine.onCrashDetected.listen((CrashEvent event) {
  print('💥 CRASH DETECTED at ${event.timestamp}!');
  print('📊 Confidence Probability: ${(event.probability * 100).toStringAsFixed(1)}%');
  
  // Trigger your app's emergency UI, offline SMS, or siren here.
});

// 3. Start Telemetry Processing
await engine.start();
```

## ⚙️ Configurable Crash Detection (v0.0.6+)

Configure detection thresholds, confidence gates, fallback behaviors, and duplicate event suppression without modifying package source code.

```dart
final engine = SafePulseEngine(
  detectionConfig: CrashDetectionConfig(
    impactThresholdG: 3.5,            // G-force required to evaluate inference
    minCrashProbability: 0.30,        // Minimum model score (0.0 to 1.0)
    fallbackImpactThresholdG: 6.0,    // G-force fallback when model is offline
    cooldown: const Duration(seconds: 45), // Suppression interval
  ),
);

engine.onCrashDetected.listen((CrashEvent event) {
  print('Crash detected: ${event.probability} at ${event.timestamp}');
});

await engine.start();
```

### Configuration Parameters & Runtime Defaults

| Setting | Type | Default | Valid Range | Boundary Rule & Units |
|---|---|---|---|---|
| `impactThresholdG` | `double` | `3.0` | `> 0.0` (finite) | Expressed in units of g (~9.81 m/s², gravity removed). Evaluated as `gForce >= impactThresholdG` when sensor buffer has 250 samples (5s at 50Hz). |
| `minCrashProbability` | `double` | `0.25` | `0.0` to `1.0` | Minimum acceptable model confidence probability. An event is emitted when model inference score satisfies `probability >= minCrashProbability`. |
| `fallbackImpactThresholdG` | `double` | `5.0` | `> 0.0` (finite) | G-force threshold used by the fallback heuristic when AI model is offline or encounters an inference error. Evaluated as `maxGForce >= fallbackImpactThresholdG`. |
| `cooldown` | `Duration` | `Duration(seconds: 30)` | `>= Duration.zero` | Duration to suppress duplicate crash events following a confirmed detection. Setting to `Duration.zero` disables cooldown suppression. |

### Duplicate Event Cooldown & Boundary Behavior
After a crash is detected, subsequent events within the configured `cooldown` interval are suppressed to prevent duplicate emergency triggers, rapid SMS dispatching, or audio siren loops.
* **Exact Boundary:** If a subsequent crash occurs at or after the cooldown duration (`elapsed >= cooldown`), it is emitted and starts a new cooldown interval.
* **Zero Cooldown:** Supplying `Duration.zero` disables cooldown suppression entirely, allowing consecutive detections to be emitted without throttling.
* **Instance Isolation:** Cooldown timers and state are isolated per engine instance.

## 🛠️ Advanced Usage (Custom Models)
Trained a better model? Inject it instantly:
```dart
final customEngine = SafePulseEngine(
  customModelPath: 'assets/my_advanced_model.tflite',
  detectionConfig: CrashDetectionConfig(
    minCrashProbability: 0.40,
  ),
);
```

## ⚠️ Important Limitations of Sensor-Based Detection
* **Hardware & Sensor Variation:** Accelerometer and gyroscope telemetry varies between device manufacturers, sensor hardware quality, device mounting (e.g., dashboard phone mount vs. loose pocket), and vehicle dynamics.
* **No Guarantee of Zero Errors:** While on-device Edge AI significantly improves anomaly filtering compared to simple thresholds, **configuring detection thresholds does not guarantee the elimination of false positives or false negatives**.
* **Safety & Application Design:** This package provides headless mathematical processing and edge inference for integration into safety applications. It should be coupled with app-layer safety mechanisms, such as confirmation countdowns, cancellation timers, and audible alerts, before dispatching high-consequence emergency actions.

## 🤝 Contributing
Welcome to the edge computing revolution. PRs, issues, and feature requests are highly appreciated to help push offline-first safety forward.
