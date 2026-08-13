import 'dart:math' as math;

import './constants.dart';

// Sun's apparent equatorial coordinates, Meeus ch. 25. d = days since J2000 (TT); t = Julian centuries.
Map<String, num> sunCoords(num d) {
  final t = d / 36525;
  final L0 = rad * (280.46646 + t * (36000.76983 + t * 0.0003032)); // 25.2 geometric mean longitude
  final M = rad * (357.52911 + t * (35999.05029 - t * 0.0001537)); // 25.3 mean anomaly
  final sinM = math.sin(M);
  final cosM = math.cos(M);
  final C = rad * ((1.914602 - t * (0.004817 + t * 0.000014)) * sinM + // equation of center
      (0.019993 - 0.000101 * t) * 2 * sinM * cosM + 0.000289 * sinM * (3 - 4 * sinM * sinM));
  final Om = rad * (125.04 - 1934.136 * t); // longitude of the ascending node
  final L = L0 + C - rad * (0.00569 + 0.00478 * math.sin(Om)); // apparent longitude (nutation + aberration)
  // 22.2 mean obliquity + 25.8 correction for apparent position
  final e = rad * (23.439291 - t * (0.0130042 + t * (0.00000016 - t * 0.000000504))) +
      rad * 0.00256 * math.cos(Om);

  return {
    "ra": math.atan2(math.cos(e) * math.sin(L), math.cos(L)), // 25.6
    "dec": math.asin(math.sin(e) * math.sin(L)) // 25.7
  };
}
