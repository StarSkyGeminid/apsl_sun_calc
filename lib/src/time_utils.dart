import 'dart:math' as math;

import './constants.dart';
import './date_utils.dart';
import './position_utils.dart';
import './sun_utils.dart';

// Observer elevation correction to the rise/set altitude (degrees), Meeus ch.15.
num observerAngle(num height) {
  return -2.076 * math.sqrt(height) / 60;
}

// Refines a transit time so the Sun's local hour angle is zero (Meeus 15.2; dH/dd ~= 2*PI/day,
// the sidereal excess and the Sun's own motion cancelling to one solar day).
num solarTransit(num dt, num lw) {
  for (var i = 0; i < 3; i++) {
    final H = wrapPi(siderealTime(dt, lw) - sunCoords(toDaysTT(dt))["ra"]!);
    dt -= H / (2 * pi);
  }
  return dt;
}

// Time the Sun reaches altitude h0 on the given side of transit (sign -1 = rise, +1 = set);
// starts from the hour angle at transit and converges with Meeus' altitude correction (15.2).
num getSetJ(num h0, num dt, num sign, num lw, num phi, num decT) {
  final cosH0 = (math.sin(h0) - math.sin(phi) * math.sin(decT)) /
      (math.cos(phi) * math.cos(decT));
  if (cosH0 < -1 || cosH0 > 1) return double.nan; // sun stays above / below this altitude all day

  var d = dt + sign * math.acos(cosH0) / (2 * pi);
  for (var i = 0; i < 2; i++) {
    final c = sunCoords(toDaysTT(d));
    final H = wrapPi(siderealTime(d, lw) - c["ra"]!);
    final h = altitude(H, phi, c["dec"]!);
    final sinH = math.cos(phi) * math.cos(c["dec"]!) * math.sin(H);
    if (sinH.abs() < 1e-6) break; // grazing the horizon — correction is ill-conditioned
    d += (h - h0) / (2 * pi * sinH);
  }
  return d;
}
