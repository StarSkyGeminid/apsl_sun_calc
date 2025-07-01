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
      expect(moonTimes['rise']?.year, 2025);
      expect(moonTimes['rise']?.month, 7);
      expect(moonTimes['rise']?.day, 1);
    });

    test('addTime adds a new time to times list', () {
      final initialLength = times.length;
      SunCalc.addTime(-4, 'customRise', 'customSet');
      expect(times.length, initialLength + 1);
      expect(times.last[1], 'customRise');
      expect(times.last[2], 'customSet');
    });
  });
}
