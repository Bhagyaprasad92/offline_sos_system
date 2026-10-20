import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sos_system/offline_sos_system.dart';
import 'package:offline_sos_system/src/sensor_service.dart';

class _FakeSensorService extends SensorService {
  bool _mockRunning = false;

  @override
  bool get isRunning => _mockRunning;

  @override
  void start() {
    _mockRunning = true;
    onLog?.call('Sensors active. Reading at 50Hz.');
  }

  @override
  Future<void> stop() async {
    _mockRunning = false;
    onLog?.call('Sensors stopped.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SafePulseEngine', () {
    test(
      'backward compatibility: compiles with default constructor and defaults',
      () {
        final engine = SafePulseEngine();

        expect(engine.detectionConfig, isNotNull);
        expect(engine.detectionConfig.impactThresholdG, equals(3.0));
        expect(engine.detectionConfig.minCrashProbability, equals(0.25));
        expect(engine.detectionConfig.fallbackImpactThresholdG, equals(5.0));
        expect(
          engine.detectionConfig.cooldown,
          equals(const Duration(seconds: 30)),
        );
        expect(engine.aiService.config, equals(engine.detectionConfig));
        expect(engine.isRunning, isFalse);
        expect(engine.isDisposed, isFalse);

        engine.dispose();
      },
    );

    test('accepts custom configuration policy', () {
      final customConfig = CrashDetectionConfig(
        impactThresholdG: 4.2,
        minCrashProbability: 0.5,
        fallbackImpactThresholdG: 7.0,
        cooldown: const Duration(seconds: 10),
      );

      final engine = SafePulseEngine(detectionConfig: customConfig);

      expect(engine.detectionConfig, equals(customConfig));
      expect(engine.aiService.config, equals(customConfig));

      engine.dispose();
    });

    group('cooldown and duplicate suppression', () {
      test(
        'suppresses events within cooldown and emits at exact boundary',
        () async {
          DateTime currentTime = DateTime(2026, 1, 1, 12, 0, 0);
          final events = <CrashEvent>[];

          final engine = SafePulseEngine(
            detectionConfig: CrashDetectionConfig(
              cooldown: const Duration(seconds: 30),
            ),
            clock: () => currentTime,
          );

          final subscription = engine.onCrashDetected.listen(events.add);

          // 1. Initial crash detection at t = 0s
          engine.aiService.onCrashDetected?.call(0.8);
          await pumpEventQueue();
          expect(events.length, equals(1));
          expect(events.first.probability, equals(0.8));
          expect(events.first.timestamp, equals(currentTime));

          // 2. Detection within cooldown at t = 15s -> suppressed
          currentTime = currentTime.add(const Duration(seconds: 15));
          engine.aiService.onCrashDetected?.call(0.9);
          await pumpEventQueue();
          expect(events.length, equals(1));

          // 3. Detection just before boundary at t = 29s -> suppressed
          currentTime = currentTime.add(
            const Duration(seconds: 14),
          ); // total 29s
          engine.aiService.onCrashDetected?.call(0.85);
          await pumpEventQueue();
          expect(events.length, equals(1));

          // 4. Detection at exact boundary t = 30s -> emitted!
          currentTime = currentTime.add(
            const Duration(seconds: 1),
          ); // total 30s
          engine.aiService.onCrashDetected?.call(0.95);
          await pumpEventQueue();
          expect(events.length, equals(2));
          expect(events.last.probability, equals(0.95));
          expect(events.last.timestamp, equals(currentTime));

          // 5. Subsequent detection after boundary at t = 61s -> emitted!
          currentTime = currentTime.add(
            const Duration(seconds: 31),
          ); // total 61s
          engine.aiService.onCrashDetected?.call(0.7);
          await pumpEventQueue();
          expect(events.length, equals(3));
          expect(events.last.probability, equals(0.7));

          await subscription.cancel();
          engine.dispose();
        },
      );

      test(
        'zero cooldown disables suppression and emits consecutive events',
        () async {
          final currentTime = DateTime(2026, 1, 1, 12, 0, 0);
          final events = <CrashEvent>[];

          final engine = SafePulseEngine(
            detectionConfig: CrashDetectionConfig(cooldown: Duration.zero),
            clock: () => currentTime,
          );

          final subscription = engine.onCrashDetected.listen(events.add);

          // Multiple rapid detections at same timestamp
          engine.aiService.onCrashDetected?.call(0.5);
          await pumpEventQueue();
          engine.aiService.onCrashDetected?.call(0.6);
          await pumpEventQueue();
          engine.aiService.onCrashDetected?.call(0.7);
          await pumpEventQueue();

          expect(events.length, equals(3));
          expect(
            events.map((e) => e.probability).toList(),
            equals([0.5, 0.6, 0.7]),
          );

          await subscription.cancel();
          engine.dispose();
        },
      );

      test('independent engine instances do not leak cooldown state', () async {
        final currentTime = DateTime(2026, 1, 1, 12, 0, 0);
        final eventsA = <CrashEvent>[];
        final eventsB = <CrashEvent>[];

        final engineA = SafePulseEngine(
          detectionConfig: CrashDetectionConfig(
            cooldown: const Duration(seconds: 30),
          ),
          clock: () => currentTime,
        );
        final engineB = SafePulseEngine(
          detectionConfig: CrashDetectionConfig(
            cooldown: const Duration(seconds: 30),
          ),
          clock: () => currentTime,
        );

        final subA = engineA.onCrashDetected.listen(eventsA.add);
        final subB = engineB.onCrashDetected.listen(eventsB.add);

        // Trigger on engine A
        engineA.aiService.onCrashDetected?.call(0.8);
        await pumpEventQueue();
        expect(eventsA.length, equals(1));
        expect(eventsB.length, equals(0));

        // Immediate trigger on engine B is NOT suppressed by engine A's trigger
        engineB.aiService.onCrashDetected?.call(0.9);
        await pumpEventQueue();
        expect(eventsB.length, equals(1));

        await subA.cancel();
        await subB.cancel();
        engineA.dispose();
        engineB.dispose();
      });
    });

    group('lifecycle and safety', () {
      test('start and stop update isRunning status', () async {
        final fakeSensor = _FakeSensorService();
        final engine = SafePulseEngine(sensorService: fakeSensor);
        expect(engine.isRunning, isFalse);

        await engine.start();
        expect(engine.isRunning, isTrue);
        expect(fakeSensor.isRunning, isTrue);

        // Calling start again is idempotent
        await engine.start();
        expect(engine.isRunning, isTrue);

        await engine.stop();
        expect(engine.isRunning, isFalse);
        expect(fakeSensor.isRunning, isFalse);

        // Calling stop again is idempotent
        await engine.stop();
        expect(engine.isRunning, isFalse);

        engine.dispose();
      });

      test('dispose is idempotent and cleans up resources', () {
        final fakeSensor = _FakeSensorService();
        final engine = SafePulseEngine(sensorService: fakeSensor);

        expect(engine.isDisposed, isFalse);
        engine.dispose();
        expect(engine.isDisposed, isTrue);
        expect(engine.isRunning, isFalse);
        expect(fakeSensor.isRunning, isFalse);

        // Subsequent dispose calls are safe
        expect(() => engine.dispose(), returnsNormally);
        expect(() => engine.dispose(), returnsNormally);
      });

      test('start after dispose throws StateError', () async {
        final engine = SafePulseEngine();
        engine.dispose();

        expect(() => engine.start(), throwsStateError);
      });

      test('emissions and logs after dispose are safely ignored', () {
        final engine = SafePulseEngine();
        engine.dispose();

        // Neither logging nor crash callbacks should throw on closed streams
        expect(() => engine.log('Test message after dispose'), returnsNormally);
        expect(
          () => engine.aiService.onCrashDetected?.call(1.0),
          returnsNormally,
        );
      });
    });
  });
}
