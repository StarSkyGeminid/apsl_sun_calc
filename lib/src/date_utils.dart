import './constants.dart';

num toJulian(DateTime date) {
  return date.millisecondsSinceEpoch / dayMs - 0.5 + j1970;
}

DateTime fromJulian(num j) {
  return DateTime.fromMillisecondsSinceEpoch(
      ((j + 0.5 - j1970) * dayMs).round());
}

num toDays(DateTime date) {
  return toJulian(date) - j2000;
}

// ΔT = TT − UT in seconds (Espenak & Meeus polynomial fits, good ~1900–2150). The Meeus position
// series are defined in Terrestrial Time, but SunCalc's input Dates are UT — so the position math
// runs on days-since-J2000 shifted by deltaT, while sidereal time stays on UT. ~69 s today;
// negligible for the Sun (<0.001°), real for the Moon. d only needs ~month accuracy here (ΔT
// changes <1 s/yr), so the decimal year is derived arithmetically from d rather than from the Date.
num deltaT(num d) {
  final y = 2000 + d / 365.2425;
  num t;
  if (y < 1920) {
    t = y - 1900;
    return -2.79 + t * (1.494119 + t * (-0.0598939 + t * (0.0061966 - t * 0.000197)));
  }
  if (y < 1941) {
    t = y - 1920;
    return 21.20 + t * (0.84493 + t * (-0.076100 + t * 0.0020936));
  }
  if (y < 1961) {
    t = y - 1950;
    return 29.07 + t * (0.407 + t * (-1 / 233 + t / 2547));
  }
  if (y < 1986) {
    t = y - 1975;
    return 45.45 + t * (1.067 + t * (-1 / 260 - t / 718));
  }
  if (y < 2005) {
    t = y - 2000;
    return 63.86 +
        t * (0.3345 +
            t * (-0.060374 + t * (0.0017275 + t * (0.000651814 + t * 0.00002373599))));
  }
  if (y < 2050) {
    t = y - 2000;
    return 62.92 + t * (0.32217 + t * 0.005589);
  }
  t = (y - 1820) / 100;
  return -20 + 32 * t * t - 0.5628 * (2150 - y);
}

// Days since J2000 in Terrestrial Time (UT days shifted by ΔT).
num toDaysTT(num d) {
  return d + deltaT(d) / 86400;
}
