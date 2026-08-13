library flutter_suncalc;

import 'dart:math' as math;

import 'src/constants.dart';
import 'src/date_utils.dart';
import 'src/moon_utils.dart';
import 'src/position_utils.dart';
import 'src/sun_utils.dart';
import 'src/time_utils.dart';

// Define the Julian epoch reference.
final julianEpoch = DateTime.utc(-4713, 11, 24, 12, 0, 0);

// calculations for sun times
var times = <List<dynamic>>[
  [-0.833, 'sunrise', 'sunset'],
  [-0.3, 'sunriseEnd', 'sunsetStart'],
  [-6, 'dawn', 'dusk'],
  [-12, 'nauticalDawn', 'nauticalDusk'],
  [-18, 'nightEnd', 'night'],
  [6, 'goldenHourEnd', 'goldenHour']
];

DateTime hoursLater(DateTime date, num h) {
  var ms = h * 60 * 60 * 1000;
  return date.add(Duration(milliseconds: ms.toInt()));
}

class SunCalc {
  static void addTime(num angle, String riseName, String setName) {
    times.add([angle, riseName, setName]);
  }

  // Calculate the position of the sun at a given date and latitude/longitude.
  static Map<String, num> getPosition(DateTime date, num lat, num lng) {
    var lw = rad * -lng;
    var phi = rad * lat;
    var d = toDays(date);

    var c = sunCoords(toDaysTT(d));
    var H = siderealTime(d, lw) - (c["ra"] ?? 0.0);
    var h = altitude(H, phi, (c["dec"] ?? 0.0));

    return {
      "azimuth": azimuth(H, phi, (c["dec"] ?? 0.0)),
      "altitude": (h + astroRefraction(h)) / rad
    };
  }

  static Map<String, num> getSunPosition(DateTime date, num lat, num lng) {
    return SunCalc.getPosition(date, lat, lng);
  }

  // Calculate sunrise, sunset times and related solar phases for a given date and latitude/longitude.
  static Future<Map<String, dynamic>> getTimes(
      DateTime date, num lat, num lng, [num height = 0]) async {
    var lw = rad * -lng;
    var phi = rad * lat;
    var dh = observerAngle(height);
    var noon = date.isUtc
        ? DateTime.utc(date.year, date.month, date.day, 12)
        : DateTime(date.year, date.month, date.day, 12);
    var d = (toDays(noon).round() - j0 - lw / (2 * pi)).round().toDouble();
    var dt = solarTransit(d + j0 + lw / (2 * pi), lw);
    var dec = sunCoords(toDaysTT(dt))["dec"]!;

    var result = <String, dynamic>{
      "solarNoon": fromJulian(dt + j2000),
      "nadir": fromJulian(dt + j2000 - 0.5)
    };

    for (var i = 0; i < times.length; i += 1) {
      var time = times[i];
      var h0 = (time[0] + dh) * rad;
      var jrise = getSetJ(h0, dt, -1, lw, phi, dec);
      var jset = getSetJ(h0, dt, 1, lw, phi, dec);
      result[time[1]] = jrise.isNaN ? null : fromJulian(jrise + j2000);
      result[time[2]] = jset.isNaN ? null : fromJulian(jset + j2000);
    }

    if (result["sunrise"] == null) {
      var noonAlt = altitude(0, phi, dec);
      var riseSetAlt = (times[0][0] + dh) * rad;
      result["alwaysUp"] = noonAlt > riseSetAlt;
      result["alwaysDown"] = noonAlt <= riseSetAlt;
    }

    return result;
  }

  // Calculate the position of the moon at a given date and latitude/longitude.
  static Map<String, num> getMoonPosition(DateTime date, num lat, num lng) {
    var lw = rad * -lng;
    var phi = rad * lat;
    var d = toDays(date);

    var c = moonCoords(toDaysTT(d));
    var H = siderealTime(d, lw) - (c["ra"] ?? 0.0);
    var hGeo = altitude(H, phi, (c["dec"] ?? 0.0));
    // geocentric parallax (Meeus ch.40) lowers the moon along its vertical circle
    var h = hGeo - math.asin(earthRadius / (c["dist"] ?? 0.0) * math.cos(hGeo));
    // parallactic angle, Meeus 14.1
    var pa = math.atan2(
      math.sin(H),
      math.tan(phi) * math.cos(c["dec"] ?? 0.0) -
          math.sin(c["dec"] ?? 0.0) * math.cos(H),
    );

    h = h + astroRefraction(h);

    return {
      "azimuth": azimuth(H, phi, (c["dec"] ?? 0.0)),
      "altitude": h / rad,
      "distance": c["dist"] ?? 0.0,
      "parallacticAngle": pa / rad
    };
  }

  // Calculate the illumination of the moon at a given date.
  static Map<String, dynamic> getMoonIllumination(DateTime date) {
    var d = toDaysTT(toDays(date));
    var s = sunCoords(d);
    var m = moonCoords(d);

    var sdist = 149598000; // distance from Earth to Sun in km

    var phi = math.acos(math.sin(s["dec"] ?? 0.0) * math.sin(m["dec"] ?? 0.0) +
        math.cos(s["dec"] ?? 0.0) *
            math.cos(m["dec"] ?? 0.0) *
            math.cos((s["ra"] ?? 0) - (m["ra"] ?? 0.0)));
    var inc = math.atan2(
        sdist * math.sin(phi), (m["dist"] ?? 0.0) - sdist * math.cos(phi));
    var angle = math.atan2(
        math.cos(s["dec"] ?? 0.0) *
            math.sin((s["ra"] ?? 0.0) - (m["ra"] ?? 0.0)),
        math.sin(s["dec"] ?? 0.0) * math.cos(m["dec"] ?? 0.0) -
            math.cos(s["dec"] ?? 0.0) *
                math.sin(m["dec"] ?? 0.0) *
                math.cos((s["ra"] ?? 0.0) - (m["ra"] ?? 0.0)));

    var waxing = angle < 0;

    return {
      "fraction": (1 + math.cos(inc)) / 2,
      "phase": 0.5 + 0.5 * inc * (waxing ? -1 : 1) / pi,
      "angle": angle / rad,
      "waxing": waxing,
    };
  }

  // Height of the moon's upper limb above the rise/set horizon (degrees): topocentric centre
  // altitude plus the moon's semidiameter (0.2725 * equatorial horizontal parallax, tracks distance)
  // plus the residual horizon refraction (~0.09°, tuned vs USNO).
  static num _moonHeight(DateTime date, num lat, num lng) {
    var p = SunCalc.getMoonPosition(date, lat, lng);
    return (p["altitude"] ?? 0.0) +
        0.2725 * math.asin(earthRadius / (p["distance"] ?? 0.0)) / rad +
        0.09;
  }

  // Polish a crossing time (ms): the quadratic sampler's parabola root sits up to ~0.2° off the true
  // altitude curve, so Newton-refine against the real _moonHeight. Two central-difference steps.
  static int _refineMoonCross(int tMs, num lat, num lng) {
    for (var i = 0; i < 2; i++) {
      var h = _moonHeight(
          DateTime.fromMillisecondsSinceEpoch(tMs, isUtc: true), lat, lng);
      var h1 = _moonHeight(
          DateTime.fromMillisecondsSinceEpoch(tMs + 30000, isUtc: true), lat, lng);
      var h2 = _moonHeight(
          DateTime.fromMillisecondsSinceEpoch(tMs - 30000, isUtc: true), lat, lng);
      var dh = (h1 - h2) / 60000;
      if (dh.abs() < 1e-9) break;
      tMs = (tMs - h / dh).round();
    }
    return tMs;
  }

  // Calculate moonrise and moonset times for a given date, latitude, and longitude.
  static Map<String, dynamic> getMoonTimes(DateTime date, num lat, num lng) {
    var t = date.isUtc
        ? DateTime.utc(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day);

    var h0 = _moonHeight(t, lat, lng);
    double? rise, set;
    var hMax = h0;

    for (var i = 1; i <= 24; i += 2) {
      var h1 = _moonHeight(hoursLater(t, i), lat, lng);
      var h2 = _moonHeight(hoursLater(t, i + 1), lat, lng);
      hMax = math.max(hMax, math.max(h1, h2));
      var a = (h0 + h2) / 2 - h1;
      var b = (h2 - h0) / 2;
      var xe = -b / (2 * a);
      var disc = b * b - 4 * a * h1;
      var roots = 0;
      var x1 = 0.0, x2 = 0.0;
      var ye = (a * xe + b) * xe + h1;

      if (disc >= 0) {
        var dx = math.sqrt(disc) / (a.abs() * 2);
        x1 = xe - dx;
        x2 = xe + dx;
        if (x1.abs() <= 1) roots++;
        if (x2.abs() <= 1) roots++;
        if (x1 < -1) x1 = x2;
      }

      if (roots == 1) {
        if (h0 < 0) {
          rise = i + x1;
        } else {
          set = i + x1;
        }
      } else if (roots == 2) {
        rise = i + (ye < 0 ? x2 : x1);
        set = i + (ye < 0 ? x1 : x2);
      }

      if (rise != null && set != null) break;

      h0 = h2;
    }

    Map<String, dynamic> result = {};

    if (rise != null) {
      result["rise"] = DateTime.fromMillisecondsSinceEpoch(
          _refineMoonCross(hoursLater(t, rise).millisecondsSinceEpoch, lat, lng),
          isUtc: true);
    }
    if (set != null) {
      result["set"] = DateTime.fromMillisecondsSinceEpoch(
          _refineMoonCross(hoursLater(t, set).millisecondsSinceEpoch, lat, lng),
          isUtc: true);
    }

    if (rise == null && set == null) {
      result["alwaysUp"] = hMax > 0;
      result["alwaysDown"] = hMax <= 0;
    } else {
      result["alwaysUp"] = false;
      result["alwaysDown"] = false;
    }

    return result;
  }
}
