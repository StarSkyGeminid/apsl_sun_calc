import 'package:test/test.dart';
import 'package:apsl_sun_calc/apsl_sun_calc.dart';

void main() {
  group('SunCalc', () {
    test('getSunPosition returns correct keys', () {
      final pos =
          SunCalc.getSunPosition(DateTime.utc(2025, 7, 1, 12), 43.0, -79.0);
      expect(pos.containsKey('azimuth'), isTrue);
      expect(pos.containsKey('altitude'), isTrue);
    });

    test('getTimes returns solarNoon and nadir', () async {
      final times =
          await SunCalc.getTimes(DateTime(2025, 7, 1, 12), 43.0, -79.0);
      expect(times.containsKey('sunrise'), isTrue);
      expect(times['sunrise']?.year, 2025);
      expect(times['sunrise']?.month, 7);
      expect(times['sunrise']?.day, 1);
      expect(times.containsKey('solarNoon'), isTrue);
      expect(times.containsKey('nadir'), isTrue);
    });

    test('getMoonPosition returns correct keys', () {
      final pos =
          SunCalc.getMoonPosition(DateTime.utc(2025, 7, 1, 12), 43.0, -79.0);
      expect(pos.containsKey('azimuth'), isTrue);
      expect(pos.containsKey('altitude'), isTrue);
      expect(pos.containsKey('distance'), isTrue);
      expect(pos.containsKey('parallacticAngle'), isTrue);
    });

    test('getMoonIllumination returns correct keys', () {
      final illum = SunCalc.getMoonIllumination(DateTime.utc(2025, 7, 1));
      expect(illum.containsKey('fraction'), isTrue);
      expect(illum.containsKey('phase'), isTrue);
      expect(illum.containsKey('angle'), isTrue);
      expect(illum.containsKey('waxing'), isTrue);
    });

    test('getMoonTimes returns rise or set or alwaysUp/alwaysDown', () {
      final moonTimes =
          SunCalc.getMoonTimes(DateTime.utc(2025, 7, 1), 43.0, -79.0);
      expect(
        moonTimes.containsKey('rise') ||
            moonTimes.containsKey('set') ||
            moonTimes['alwaysUp'] == true ||
            moonTimes['alwaysDown'] == true,
        isTrue,
      );
      if (moonTimes.containsKey('rise')) {
        expect(moonTimes['rise']?.year, 2025);
        expect(moonTimes['rise']?.month, 7);
      }
    });

    test('addTime adds a new time to times list', () {
      final initialLength = times.length;
      SunCalc.addTime(-4, 'customRise', 'customSet');
      expect(times.length, initialLength + 1);
      expect(times.last[1], 'customRise');
      expect(times.last[2], 'customSet');
    });

    group('degrees output (international standard)', () {
      test('sun azimuth in [0, 360), altitude in [-90, 90]', () {
        final pos =
            SunCalc.getSunPosition(DateTime.utc(2025, 7, 1, 12), 43.0, -79.0);
        expect(pos['azimuth']! >= 0, isTrue);
        expect(pos['azimuth']! < 360, isTrue);
        expect(pos['altitude']! >= -90, isTrue);
        expect(pos['altitude']! <= 90, isTrue);
      });

      test('moon azimuth in [0, 360), altitude in [-90, 90]', () {
        final pos =
            SunCalc.getMoonPosition(DateTime.utc(2025, 7, 1, 12), 43.0, -79.0);
        expect(pos['azimuth']! >= 0, isTrue);
        expect(pos['azimuth']! < 360, isTrue);
        expect(pos['altitude']! >= -90, isTrue);
        expect(pos['altitude']! <= 90, isTrue);
      });

      test('moon illumination angle in degrees', () {
        final illum = SunCalc.getMoonIllumination(DateTime.utc(2025, 7, 1));
        expect(illum['angle']! >= -180, isTrue);
        expect(illum['angle']! <= 180, isTrue);
      });

      test('moon fraction in [0, 1], phase in [0, 1]', () {
        final illum = SunCalc.getMoonIllumination(DateTime.utc(2025, 7, 1));
        expect(illum['fraction']! >= 0, isTrue);
        expect(illum['fraction']! <= 1, isTrue);
        expect(illum['phase']! >= 0, isTrue);
        expect(illum['phase']! <= 1, isTrue);
      });
    });

    group('moon rise/set self-consistency', () {
      test('altitude at rise time ≈ 0 (upper limb at horizon)', () {
        final moonTimes =
            SunCalc.getMoonTimes(DateTime.utc(2025, 7, 1), 43.0, -79.0);
        if (moonTimes['rise'] != null) {
          final rise = moonTimes['rise'] as DateTime;
          final pos = SunCalc.getMoonPosition(rise, 43.0, -79.0);
          // moonHeight = altitude + semidiameter + 0.09° refraction ≈ 0
          // so altitude ≈ -(semidiameter + 0.09) ≈ -0.25° to -0.35°
          expect(pos['altitude']! > -0.5, isTrue);
          expect(pos['altitude']! < 0.5, isTrue);
        }
      });

      test('altitude at set time ≈ 0 (upper limb at horizon)', () {
        final moonTimes =
            SunCalc.getMoonTimes(DateTime.utc(2025, 7, 1), 43.0, -79.0);
        if (moonTimes['set'] != null) {
          final set = moonTimes['set'] as DateTime;
          final pos = SunCalc.getMoonPosition(set, 43.0, -79.0);
          expect(pos['altitude']! > -0.5, isTrue);
          expect(pos['altitude']! < 0.5, isTrue);
        }
      });
    });

    group('drift check', () {
      test('consecutive rises are ~24h±1h apart (lunar day)', () {
        final lat = -6.2, lng = 106.8; // Jakarta
        DateTime? prevRise;

        for (var day = 1; day <= 15; day++) {
          final mt = SunCalc.getMoonTimes(DateTime.utc(2025, 3, day), lat, lng);
          if (mt['rise'] != null) {
            final rise = mt['rise'] as DateTime;
            if (prevRise != null) {
              final diffMin = rise.difference(prevRise).inMinutes.toDouble();
              // Lunar day ≈ 24h50min; allow ±1h variation
              expect(diffMin > 23 * 60, isTrue);
              expect(diffMin < 26 * 60, isTrue);
            }
            prevRise = rise;
          }
        }
      });

      test('rise time wraps around within a lunar month (~30 days)', () {
        final lat = -6.2, lng = 106.8; // Jakarta
        final riseHours = <double>[];

        for (var day = 1; day <= 30; day++) {
          final mt = SunCalc.getMoonTimes(DateTime.utc(2025, 3, day), lat, lng);
          if (mt['rise'] != null) {
            final rise = mt['rise'] as DateTime;
            riseHours.add(rise.hour + rise.minute / 60.0);
          }
        }

        // Over ~30 days the rise time should span a wide range (not stuck in one part of day)
        final minH = riseHours.reduce((a, b) => a < b ? a : b);
        final maxH = riseHours.reduce((a, b) => a > b ? a : b);
        expect(maxH - minH > 6, isTrue); // should span > 6 hours of the day
      });

      test('moon rise time reasonable for Jakarta 2025-03-15', () {
        final mt = SunCalc.getMoonTimes(DateTime.utc(2025, 3, 15), -6.2, 106.8);
        expect(
          mt.containsKey('rise') || mt.containsKey('set') ||
              mt['alwaysUp'] == true || mt['alwaysDown'] == true,
          isTrue,
        );
      });
    });

    group('timezone handling', () {
      test('getTimes returns UTC DateTimes', () async {
        final times =
            await SunCalc.getTimes(DateTime(2025, 7, 1, 12), 43.0, -79.0);
        expect((times['sunrise'] as DateTime).isUtc, isTrue);
        expect((times['sunset'] as DateTime).isUtc, isTrue);
        expect((times['solarNoon'] as DateTime).isUtc, isTrue);
      });

      test('getMoonTimes returns UTC DateTimes', () {
        final mt = SunCalc.getMoonTimes(DateTime.utc(2025, 7, 1), 43.0, -79.0);
        if (mt['rise'] != null) {
          expect((mt['rise'] as DateTime).isUtc, isTrue);
        }
        if (mt['set'] != null) {
          expect((mt['set'] as DateTime).isUtc, isTrue);
        }
      });

      test('getTimes noon anchoring: midnight and noon give same day', () async {
        final t1 = await SunCalc.getTimes(DateTime(2025, 7, 1, 0), 43.0, -79.0);
        final t2 = await SunCalc.getTimes(DateTime(2025, 7, 1, 12), 43.0, -79.0);
        expect(t1['sunrise'], equals(t2['sunrise']));
        expect(t1['sunset'], equals(t2['sunset']));
      });

      test('getTimes Jakarta sunrise matches USNO within ±2 min', () async {
        final times = await SunCalc.getTimes(
            DateTime(2026, 8, 13, 12), -6.2088, 106.8456);
        final sunrise = times['sunrise'] as DateTime;
        final expected = DateTime.utc(2026, 8, 12, 23, 1);
        expect(sunrise.difference(expected).inMinutes.abs() <= 2, isTrue);
      });

      test('getMoonTimes Jakarta rise matches USNO within ±3 min', () {
        final mt = SunCalc.getMoonTimes(
            DateTime.utc(2026, 8, 12), -6.2088, 106.8456);
        final rise = mt['rise'] as DateTime?;
        expect(rise, isNotNull);
        final expected = DateTime.utc(2026, 8, 12, 23, 18);
        expect(rise!.difference(expected).inMinutes.abs() <= 3, isTrue);
      });
    });
  });
}
