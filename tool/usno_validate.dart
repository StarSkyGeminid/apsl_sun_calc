import '../lib/apsl_sun_calc.dart';

class UsnoRow {
  final String date;
  final String? moonRise, moonTransit, moonSet;
  final String? sunRise, sunSet;
  final int fracillum;
  UsnoRow(this.date, this.moonRise, this.moonTransit, this.moonSet,
      this.sunRise, this.sunSet, this.fracillum);
}

// USNO reference data for Jakarta (-6.2088, 106.8456) UTC+7
// Dates span 2018-2032, covering solstices, equinoxes, all moon phases.
final usnoData = <UsnoRow>[
  UsnoRow('2018-11-03', '01:52', '08:00', '14:08', '05:26', '17:46', 23),
  UsnoRow('2020-06-15', '01:05', '07:15', '13:24', '06:00', '17:46', 32),
  UsnoRow('2021-09-28', '23:41', '04:51', '10:51', '05:39', '17:47', 58),
  UsnoRow('2022-12-21', '03:10', '09:32', '15:57', '05:36', '18:05', 7),
  UsnoRow('2024-03-10', '05:41', '11:58', '18:13', '05:58', '18:08', 0),
  UsnoRow('2026-02-05', '20:54', '02:23', '08:33', '05:56', '18:17', 88),
  UsnoRow('2026-08-13', '06:18', '12:23', '18:30', '06:01', '17:54', 0),
  UsnoRow('2026-08-14', '07:05', '13:13', '19:22', '06:00', '17:54', 3),
  UsnoRow('2026-08-15', '07:49', '13:59', '20:11', '06:00', '17:54', 8),
  UsnoRow('2026-08-20', '11:25', '17:49', null, '05:58', '17:54', 51),
  UsnoRow('2026-08-27', '17:16', '23:32', '05:06', '05:55', '17:53', 99),
  UsnoRow('2026-09-03', '23:12', '04:15', '10:17', '05:52', '17:52', 63),
  UsnoRow('2028-09-15', '02:23', '08:26', '14:31', '05:46', '17:50', 18),
  UsnoRow('2030-01-10', '10:44', '16:51', '22:57', '05:46', '18:14', 37),
  UsnoRow('2032-07-20', '15:26', '21:50', '03:14', '06:05', '17:53', 91),
];

const lat = -6.2088;
const lng = 106.8456;
const tz = 7;

DateTime localMidnightUtc(String dateStr) {
  final parts = dateStr.split('-');
  return DateTime.utc(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]), 0, 0)
    .subtract(const Duration(hours: tz));
}

String? fmtLocal(DateTime? utc) {
  if (utc == null) return null;
  final local = utc.add(const Duration(hours: tz));
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String fmtDiff(String? usno, String? computed) {
  if (usno == null || computed == null) return 'n/a';
  final u = usno.split(':');
  final c = computed.split(':');
  final um = int.parse(u[0]) * 60 + int.parse(u[1]);
  final cm = int.parse(c[0]) * 60 + int.parse(c[1]);
  final diff = cm - um;
  // wrap around midnight (e.g. 23:55 vs 00:05 = +10 min)
  var wrapped = diff;
  if (wrapped > 720) wrapped -= 1440;
  if (wrapped < -720) wrapped += 1440;
  final sign = wrapped >= 0 ? '+' : '';
  return '$sign$wrapped min';
}

int? diffMin(String? usno, String? computed) {
  if (usno == null || computed == null) return null;
  final u = usno.split(':');
  final c = computed.split(':');
  final um = int.parse(u[0]) * 60 + int.parse(u[1]);
  final cm = int.parse(c[0]) * 60 + int.parse(c[1]);
  var diff = cm - um;
  if (diff > 720) diff -= 1440;
  if (diff < -720) diff += 1440;
  return diff;
}

void main() async {
  print('=== USNO Validation: Jakarta (-6.2088, 106.8456) UTC+7 ===');
  print('=== ${usnoData.length} dates, 2018-2032 ===\n');

  final diffs = <String, List<int>>{
    'moonRise': [], 'moonTransit': [], 'moonSet': [],
    'sunRise': [], 'sunSet': [], 'illum': [],
  };

  for (final row in usnoData) {
    final localMid = localMidnightUtc(row.date);
    final dParts = row.date.split('-');
    final utcDate = DateTime.utc(
        int.parse(dParts[0]), int.parse(dParts[1]), int.parse(dParts[2]));

    // Sun times
    final sunTimes = await SunCalc.getTimes(utcDate, lat, lng);
    final sunRise = fmtLocal(sunTimes['sunrise'] as DateTime?);
    final sunSet = fmtLocal(sunTimes['sunset'] as DateTime?);

    // Moon times — scan two UTC-day windows, pick events in local day
    final moonA = SunCalc.getMoonTimes(utcDate, lat, lng);
    final moonB = SunCalc.getMoonTimes(
        utcDate.subtract(const Duration(days: 1)), lat, lng);

    final localEnd = localMid.add(const Duration(hours: 24));

    DateTime? pickInWindow(Map<String, dynamic> m, String key) {
      final v = m[key];
      if (v is DateTime && v.isAfter(localMid) && v.isBefore(localEnd)) {
        return v;
      }
      return null;
    }

    DateTime? moonRise =
        pickInWindow(moonA, 'rise') ?? pickInWindow(moonB, 'rise');
    DateTime? moonSet =
        pickInWindow(moonA, 'set') ?? pickInWindow(moonB, 'set');

    // Moon transit (upper) — find max altitude in local day
    DateTime? moonTransit;
    num maxAlt = -999;
    for (int i = 0; i <= 144; i++) {
      final t = localMid.add(Duration(minutes: i * 10));
      final alt = SunCalc.getMoonPosition(t, lat, lng)['altitude'] as num;
      if (alt > maxAlt) {
        maxAlt = alt;
        moonTransit = t;
      }
    }
    final approx = moonTransit;
    if (approx != null) {
      for (int i = -10; i <= 10; i++) {
        final t = approx.add(Duration(minutes: i));
        final alt = SunCalc.getMoonPosition(t, lat, lng)['altitude'] as num;
        if (alt > maxAlt) {
          maxAlt = alt;
          moonTransit = t;
        }
      }
    }
    final moonTransitStr = fmtLocal(moonTransit);

    // Moon illumination at local noon
    final localNoon = localMid.add(const Duration(hours: 12));
    final illum = SunCalc.getMoonIllumination(localNoon);
    final fracPct = ((illum['fraction'] as num) * 100).round();

    // Collect diffs
    for (final entry in [
      ['moonRise', row.moonRise, fmtLocal(moonRise)],
      ['moonTransit', row.moonTransit, moonTransitStr],
      ['moonSet', row.moonSet, fmtLocal(moonSet)],
      ['sunRise', row.sunRise, sunRise],
      ['sunSet', row.sunSet, sunSet],
    ]) {
      final d = diffMin(entry[1] as String?, entry[2] as String?);
      if (d != null) diffs[entry[0] as String]!.add(d);
    }
    diffs['illum']!.add(fracPct - row.fracillum);

    print('Date: ${row.date}  (illum: USNO ${row.fracillum}% / ours $fracPct%  ${fracPct - row.fracillum >= 0 ? '+' : ''}${fracPct - row.fracillum}%)');
    print('  Moon Rise:    USNO ${row.moonRise ?? "—"}  ours ${fmtLocal(moonRise) ?? "—"}  ${fmtDiff(row.moonRise, fmtLocal(moonRise))}');
    print('  Moon Transit: USNO ${row.moonTransit ?? "—"}  ours $moonTransitStr  ${fmtDiff(row.moonTransit, moonTransitStr)}');
    print('  Moon Set:     USNO ${row.moonSet ?? "—"}  ours ${fmtLocal(moonSet) ?? "—"}  ${fmtDiff(row.moonSet, fmtLocal(moonSet))}');
    print('  Sun Rise:     USNO ${row.sunRise ?? "—"}  ours $sunRise  ${fmtDiff(row.sunRise, sunRise)}');
    print('  Sun Set:      USNO ${row.sunSet ?? "—"}  ours $sunSet  ${fmtDiff(row.sunSet, sunSet)}');
    print('');
  }

  // Summary
  print('=== SUMMARY ===');
  for (final key in ['moonRise', 'moonTransit', 'moonSet', 'sunRise', 'sunSet', 'illum']) {
    final list = diffs[key]!;
    if (list.isEmpty) {
      print('  $key: no data');
      continue;
    }
    final max = list.reduce((a, b) => a.abs() > b.abs() ? a : b);
    final mean = list.map((v) => v.abs()).reduce((a, b) => a + b) / list.length;
    print('  $key: ${list.length} samples, max=${max >= 0 ? '+' : ''}$max min, mean=${mean.toStringAsFixed(1)} min');
  }
}
