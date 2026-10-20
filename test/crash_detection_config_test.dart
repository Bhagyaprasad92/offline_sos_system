import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sos_system/offline_sos_system.dart';

void main() {
  group('CrashDetectionConfig', () {
    test(
      'default constructor creates instance with expected default values',
      () {
        final config = CrashDetectionConfig();

        expect(config.impactThresholdG, equals(3.0));
        expect(config.minCrashProbability, equals(0.25));
        expect(config.fallbackImpactThresholdG, equals(5.0));
        expect(config.cooldown, equals(const Duration(seconds: 30)));
      },
    );

    test('const raw constructor creates matching defaults', () {
      const config = CrashDetectionConfig.raw();

      expect(
        config.impactThresholdG,
        equals(CrashDetectionConfig.defaultImpactThresholdG),
      );
      expect(
        config.minCrashProbability,
        equals(CrashDetectionConfig.defaultMinCrashProbability),
      );
      expect(
        config.fallbackImpactThresholdG,
        equals(CrashDetectionConfig.defaultFallbackImpactThresholdG),
      );
      expect(config.cooldown, equals(CrashDetectionConfig.defaultCooldown));
    });

    test('accepts custom valid values and boundaries', () {
      final config = CrashDetectionConfig(
        impactThresholdG: 2.5,
        minCrashProbability: 0.0,
        fallbackImpactThresholdG: 4.0,
        cooldown: Duration.zero,
      );

      expect(config.impactThresholdG, equals(2.5));
      expect(config.minCrashProbability, equals(0.0));
      expect(config.fallbackImpactThresholdG, equals(4.0));
      expect(config.cooldown, equals(Duration.zero));

      final upperBoundary = CrashDetectionConfig(minCrashProbability: 1.0);
      expect(upperBoundary.minCrashProbability, equals(1.0));
    });

    group('validation', () {
      test('rejects non-positive and non-finite impactThresholdG', () {
        expect(
          () => CrashDetectionConfig(impactThresholdG: 0.0),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(impactThresholdG: -1.0),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(impactThresholdG: double.nan),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(impactThresholdG: double.infinity),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(impactThresholdG: double.negativeInfinity),
          throwsArgumentError,
        );
      });

      test('rejects minCrashProbability outside [0.0, 1.0] and non-finite', () {
        expect(
          () => CrashDetectionConfig(minCrashProbability: -0.01),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(minCrashProbability: 1.01),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(minCrashProbability: double.nan),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(minCrashProbability: double.infinity),
          throwsArgumentError,
        );
      });

      test('rejects non-positive and non-finite fallbackImpactThresholdG', () {
        expect(
          () => CrashDetectionConfig(fallbackImpactThresholdG: 0.0),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(fallbackImpactThresholdG: -2.0),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(fallbackImpactThresholdG: double.nan),
          throwsArgumentError,
        );
        expect(
          () => CrashDetectionConfig(fallbackImpactThresholdG: double.infinity),
          throwsArgumentError,
        );
      });

      test('rejects negative cooldown duration', () {
        expect(
          () => CrashDetectionConfig(cooldown: const Duration(seconds: -1)),
          throwsArgumentError,
        );
        expect(
          () =>
              CrashDetectionConfig(cooldown: const Duration(milliseconds: -1)),
          throwsArgumentError,
        );
      });
    });

    group('copyWith', () {
      test('replaces specified fields and preserves others', () {
        final original = CrashDetectionConfig(
          impactThresholdG: 2.0,
          minCrashProbability: 0.3,
          fallbackImpactThresholdG: 4.5,
          cooldown: const Duration(seconds: 15),
        );

        final updated = original.copyWith(
          impactThresholdG: 3.5,
          cooldown: const Duration(seconds: 20),
        );

        expect(updated.impactThresholdG, equals(3.5));
        expect(updated.minCrashProbability, equals(0.3));
        expect(updated.fallbackImpactThresholdG, equals(4.5));
        expect(updated.cooldown, equals(const Duration(seconds: 20)));
      });

      test('validates newly updated values in copyWith', () {
        final config = CrashDetectionConfig();
        expect(
          () => config.copyWith(impactThresholdG: -1.0),
          throwsArgumentError,
        );
        expect(
          () => config.copyWith(minCrashProbability: 2.0),
          throwsArgumentError,
        );
        expect(
          () => config.copyWith(fallbackImpactThresholdG: 0.0),
          throwsArgumentError,
        );
        expect(
          () => config.copyWith(cooldown: const Duration(seconds: -5)),
          throwsArgumentError,
        );
      });
    });

    group('equality and toString', () {
      test('equals and hashCode match for identical properties', () {
        final a = CrashDetectionConfig(
          impactThresholdG: 3.2,
          minCrashProbability: 0.4,
          fallbackImpactThresholdG: 6.0,
          cooldown: const Duration(seconds: 40),
        );
        final b = CrashDetectionConfig(
          impactThresholdG: 3.2,
          minCrashProbability: 0.4,
          fallbackImpactThresholdG: 6.0,
          cooldown: const Duration(seconds: 40),
        );
        final c = CrashDetectionConfig(impactThresholdG: 3.5);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a, isNot(equals(c)));
      });

      test('toString includes field names and values', () {
        final config = CrashDetectionConfig();
        final str = config.toString();
        expect(str, contains('impactThresholdG: 3.0'));
        expect(str, contains('minCrashProbability: 0.25'));
        expect(str, contains('fallbackImpactThresholdG: 5.0'));
        expect(str, contains('cooldown: 0:00:30.000000'));
      });
    });
  });
}
