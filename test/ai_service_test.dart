import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sos_system/offline_sos_system.dart';
import 'package:offline_sos_system/src/ai_service.dart';

void main() {
  group('AIService', () {
    // Helper to generate a quiet sensor sample (0.0 G)
    List<double> quietSample() => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

    // Helper to generate a sample with an exact desired g-force along the z-axis
    List<double> impactSample(double gForce) => [
      0.0,
      0.0,
      gForce * 9.81,
      0.0,
      0.0,
      0.0,
    ];

    test('retains buffer up to 250 samples', () {
      final ai = AIService();
      for (int i = 0; i < 300; i++) {
        ai.addData(quietSample());
      }
      expect(ai.bufferLength, equals(250));
      ai.dispose();
    });

    test('does not evaluate inference until buffer reaches 250 samples', () {
      bool inferenceAttempted = false;
      final ai = AIService(
        inferenceRunner: (input, output) {
          inferenceAttempted = true;
        },
      );

      // Ingest 249 samples with high g-force
      for (int i = 0; i < 249; i++) {
        ai.addData(impactSample(4.0));
      }
      expect(inferenceAttempted, isFalse);

      // 250th sample with high g-force triggers inference
      ai.addData(impactSample(4.0));
      expect(inferenceAttempted, isTrue);

      ai.dispose();
    });

    test('impact below impactThresholdG does not trigger inference', () {
      bool inferenceAttempted = false;
      final ai = AIService(
        config: CrashDetectionConfig(impactThresholdG: 3.5),
        inferenceRunner: (input, output) {
          inferenceAttempted = true;
        },
      );

      // Fill buffer with 249 quiet samples
      for (int i = 0; i < 249; i++) {
        ai.addData(quietSample());
      }

      // Add 250th sample with 3.4 G (< 3.5 G threshold)
      ai.addData(impactSample(3.4));
      expect(inferenceAttempted, isFalse);

      ai.dispose();
    });

    test('impact exactly at impactThresholdG triggers inference', () {
      bool inferenceAttempted = false;
      final ai = AIService(
        config: CrashDetectionConfig(impactThresholdG: 3.5),
        inferenceRunner: (input, output) {
          inferenceAttempted = true;
        },
      );

      for (int i = 0; i < 249; i++) {
        ai.addData(quietSample());
      }

      // Add 250th sample with exactly 3.5 G
      ai.addData(impactSample(3.5));
      expect(inferenceAttempted, isTrue);

      ai.dispose();
    });

    group('model score threshold boundary rules', () {
      test(
        'score below minCrashProbability is filtered and does not emit crash event',
        () {
          double? detectedProb;
          final ai = AIService(
            config: CrashDetectionConfig(minCrashProbability: 0.30),
            inferenceRunner: (input, output) {
              (output as List)[0][0] = 0.29;
            },
          );
          ai.onCrashDetected = (prob) => detectedProb = prob;

          for (int i = 0; i < 250; i++) {
            ai.addData(impactSample(3.5));
          }

          expect(detectedProb, isNull);
          ai.dispose();
        },
      );

      test('score exactly at minCrashProbability emits crash event', () {
        double? detectedProb;
        final ai = AIService(
          config: CrashDetectionConfig(minCrashProbability: 0.30),
          inferenceRunner: (input, output) {
            (output as List)[0][0] = 0.30;
          },
        );
        ai.onCrashDetected = (prob) => detectedProb = prob;

        for (int i = 0; i < 250; i++) {
          ai.addData(impactSample(3.5));
        }

        expect(detectedProb, equals(0.30));
        ai.dispose();
      });

      test('score above minCrashProbability emits crash event', () {
        double? detectedProb;
        final ai = AIService(
          config: CrashDetectionConfig(minCrashProbability: 0.30),
          inferenceRunner: (input, output) {
            (output as List)[0][0] = 0.75;
          },
        );
        ai.onCrashDetected = (prob) => detectedProb = prob;

        for (int i = 0; i < 250; i++) {
          ai.addData(impactSample(3.5));
        }

        expect(detectedProb, equals(0.75));
        ai.dispose();
      });
    });

    group('fallback impact threshold', () {
      test('offline AI filters impact below fallbackImpactThresholdG', () {
        double? detectedProb;
        final ai = AIService(
          config: CrashDetectionConfig(
            impactThresholdG: 3.0,
            fallbackImpactThresholdG: 6.0,
          ),
          // No interpreter and no inferenceRunner -> AI offline
        );
        ai.onCrashDetected = (prob) => detectedProb = prob;

        for (int i = 0; i < 250; i++) {
          ai.addData(quietSample());
        }
        // Impact is 5.5 G (above impact gate 3.0, but below fallback 6.0)
        ai.addData(impactSample(5.5));

        expect(detectedProb, isNull);
        ai.dispose();
      });

      test(
        'offline AI detects crash on two consecutive spikes at or above fallbackImpactThresholdG',
        () {
          double? detectedProb;
          final ai = AIService(
            config: CrashDetectionConfig(
              impactThresholdG: 3.0,
              fallbackImpactThresholdG: 5.0,
            ),
          );
          ai.onCrashDetected = (prob) => detectedProb = prob;

          // Fill buffer
          for (int i = 0; i < 249; i++) {
            ai.addData(quietSample());
          }

          // First spike >= 5.0 G
          ai.addData(impactSample(5.0));
          expect(detectedProb, isNull); // Awaiting confirmation

          // Buffer cleared after trigger, fill again to 249
          for (int i = 0; i < 249; i++) {
            ai.addData(quietSample());
          }

          // Second spike >= 5.0 G
          ai.addData(impactSample(5.2));
          expect(detectedProb, equals(1.0));

          ai.dispose();
        },
      );

      test(
        'inference exception triggers fallback crash if maxGForce >= fallbackImpactThresholdG',
        () {
          double? detectedProb;
          final ai = AIService(
            config: CrashDetectionConfig(
              impactThresholdG: 3.0,
              fallbackImpactThresholdG: 5.5,
            ),
            inferenceRunner: (input, output) {
              throw Exception('Model inference failed!');
            },
          );
          ai.onCrashDetected = (prob) => detectedProb = prob;

          for (int i = 0; i < 249; i++) {
            ai.addData(quietSample());
          }

          // Trigger with 5.5 G >= fallbackImpactThresholdG
          ai.addData(impactSample(5.5));
          expect(detectedProb, equals(1.0));

          ai.dispose();
        },
      );

      test(
        'inference exception does not trigger fallback crash if maxGForce < fallbackImpactThresholdG',
        () {
          double? detectedProb;
          final ai = AIService(
            config: CrashDetectionConfig(
              impactThresholdG: 3.0,
              fallbackImpactThresholdG: 5.5,
            ),
            inferenceRunner: (input, output) {
              throw Exception('Model inference failed!');
            },
          );
          ai.onCrashDetected = (prob) => detectedProb = prob;

          for (int i = 0; i < 249; i++) {
            ai.addData(quietSample());
          }

          // Trigger with 4.0 G (< 5.5 G)
          ai.addData(impactSample(4.0));
          expect(detectedProb, isNull);

          ai.dispose();
        },
      );
    });

    test('resetProcessingState clears buffer and flags', () {
      final ai = AIService();
      for (int i = 0; i < 100; i++) {
        ai.addData(quietSample());
      }
      expect(ai.bufferLength, equals(100));

      ai.resetProcessingState();
      expect(ai.bufferLength, equals(0));

      ai.dispose();
    });

    test('disposed AIService stops accepting samples and does not emit', () {
      double? detectedProb;
      final ai = AIService(
        inferenceRunner: (input, output) {
          (output as List)[0][0] = 0.99;
        },
      );
      ai.onCrashDetected = (prob) => detectedProb = prob;
      ai.dispose();

      for (int i = 0; i < 260; i++) {
        ai.addData(impactSample(10.0));
      }

      expect(detectedProb, isNull);
      expect(ai.bufferLength, equals(0));
    });
  });
}
