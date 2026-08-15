import '../data/exercise_catalog.dart';
import '../models/models.dart';
import 'date_x.dart';

/// 통계 화면의 기간 선택.
enum StatsRange {
  week('주간', 7),
  month('월간', 30),
  quarter('3개월', 90),
  year('1년', 365);

  const StatsRange(this.label, this.days);

  final String label;
  final int days;
}

/// 차트 한 칸.
class ChartPoint {
  const ChartPoint({required this.label, required this.value, this.date});

  final String label;
  final double value;
  final DateTime? date;
}

/// 도넛 차트 한 조각.
class GroupSlice {
  const GroupSlice({required this.group, required this.value, required this.ratio});

  final MuscleGroup group;
  final double value;
  final double ratio;
}

/// 종목별 개인 최고 기록.
class PersonalRecord {
  const PersonalRecord({
    required this.exercise,
    required this.topWeight,
    required this.best1rm,
    required this.date,
  });

  final ExerciseDef exercise;
  final double topWeight;
  final double best1rm;
  final DateTime date;
}

/// 기간 요약 지표.
class SummaryStats {
  const SummaryStats({
    required this.sessionCount,
    required this.totalVolume,
    required this.totalSets,
    required this.totalReps,
    required this.totalMinutes,
  });

  final int sessionCount;
  final double totalVolume;
  final int totalSets;
  final int totalReps;
  final int totalMinutes;

  static const empty = SummaryStats(
    sessionCount: 0,
    totalVolume: 0,
    totalSets: 0,
    totalReps: 0,
    totalMinutes: 0,
  );

  int get avgMinutes => sessionCount == 0 ? 0 : (totalMinutes / sessionCount).round();

  double get avgVolume => sessionCount == 0 ? 0 : totalVolume / sessionCount;
}

/// 세션 목록 위에서 돌아가는 순수 통계 계산기.
///
/// 화면과 분리해 두었기 때문에 단위 테스트로 검증할 수 있다.
class StatsEngine {
  StatsEngine(this.sessions, this.catalog);

  final List<WorkoutSession> sessions;
  final ExerciseCatalog catalog;

  /// [from] 이상 [to] 이하(양끝 포함, 날짜 기준)인 세션.
  List<WorkoutSession> inRange(DateTime from, DateTime to) {
    final f = dateOnly(from);
    final t = dateOnly(to);
    return sessions.where((s) {
      final d = dateOnly(s.date);
      return !d.isBefore(f) && !d.isAfter(t);
    }).toList();
  }

  /// 오늘을 마지막 날로 하는 최근 [range] 구간.
  List<WorkoutSession> forRange(StatsRange range, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    return inRange(today.subtract(Duration(days: range.days - 1)), today);
  }

  SummaryStats summarize(List<WorkoutSession> list) {
    if (list.isEmpty) return SummaryStats.empty;
    var volume = 0.0;
    var sets = 0;
    var reps = 0;
    var minutes = 0;
    for (final s in list) {
      volume += s.totalVolume;
      sets += s.totalSets;
      reps += s.totalReps;
      minutes += s.durationMin;
    }
    return SummaryStats(
      sessionCount: list.length,
      totalVolume: volume,
      totalSets: sets,
      totalReps: reps,
      totalMinutes: minutes,
    );
  }

  /// 연속 운동 일수. 오늘 아직 운동을 안 했어도 어제까지 이어졌다면 유지된 것으로 본다.
  int currentStreak({DateTime? now}) {
    if (sessions.isEmpty) return 0;
    final days = sessions.map((s) => dateOnly(s.date)).toSet();
    final today = dateOnly(now ?? DateTime.now());

    // 오늘 기록이 없으면 어제부터 세기 시작한다.
    var cursor = days.contains(today) ? today : today.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 가장 길었던 연속 기록.
  int longestStreak() {
    if (sessions.isEmpty) return 0;
    final days = sessions.map((s) => dateOnly(s.date)).toSet().toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      if (daysBetween(days[i - 1], days[i]) == 1) {
        run++;
        best = run > best ? run : best;
      } else {
        run = 1;
      }
    }
    return best;
  }

  /// 일별 볼륨 시계열. 운동하지 않은 날도 0으로 채워 넣어 차트가 끊기지 않게 한다.
  List<ChartPoint> dailyVolume(StatsRange range, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final start = today.subtract(Duration(days: range.days - 1));
    final byDay = <DateTime, double>{};
    for (final s in inRange(start, today)) {
      final d = dateOnly(s.date);
      byDay[d] = (byDay[d] ?? 0) + s.totalVolume;
    }
    return List.generate(range.days, (i) {
      final d = start.add(Duration(days: i));
      return ChartPoint(label: formatShort(d), value: byDay[d] ?? 0, date: d);
    });
  }

  /// 주 단위로 묶은 볼륨. 월간 이상 구간에서 일별 막대가 너무 촘촘해질 때 쓴다.
  List<ChartPoint> weeklyVolume({int weeks = 8, DateTime? now}) {
    final thisWeek = startOfWeek(now ?? DateTime.now());
    return List.generate(weeks, (i) {
      final ws = thisWeek.subtract(Duration(days: 7 * (weeks - 1 - i)));
      final we = ws.add(const Duration(days: 6));
      final volume = inRange(ws, we).fold(0.0, (sum, s) => sum + s.totalVolume);
      return ChartPoint(label: formatShort(ws), value: volume, date: ws);
    });
  }

  /// 요일별 평균 운동 횟수 — 생활 패턴 확인용.
  List<ChartPoint> byWeekday(StatsRange range, {DateTime? now}) {
    final list = forRange(range, now: now);
    final counts = List<double>.filled(7, 0);
    for (final s in list) {
      counts[s.date.weekday - 1] += 1;
    }
    return List.generate(
      7,
      (i) => ChartPoint(label: kWeekdayShort[i], value: counts[i]),
    );
  }

  /// 부위별 볼륨 분포. 유산소는 볼륨이 0이라 운동 시간을 대신 환산해 넣는다.
  List<GroupSlice> groupDistribution(StatsRange range, {DateTime? now}) {
    final list = forRange(range, now: now);
    final totals = <MuscleGroup, double>{};
    for (final session in list) {
      for (final we in session.exercises) {
        final def = catalog.byId(we.exerciseId);
        final value = def.tracking == TrackingType.cardio
            // 유산소 1분을 볼륨 100kg 상당으로 환산해 한 차트에 같이 보여준다.
            ? we.durationMin * 100.0
            : we.volume;
        if (value <= 0) continue;
        totals[def.group] = (totals[def.group] ?? 0) + value;
      }
    }
    final sum = totals.values.fold(0.0, (a, b) => a + b);
    if (sum <= 0) return const [];
    final slices = totals.entries
        .map((e) => GroupSlice(group: e.key, value: e.value, ratio: e.value / sum))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return slices;
  }

  /// 특정 종목의 추정 1RM 추이(기록이 있는 날만).
  List<ChartPoint> oneRepMaxTrend(String exerciseId) {
    final points = <ChartPoint>[];
    final sorted = [...sessions]..sort((a, b) => a.date.compareTo(b.date));
    for (final s in sorted) {
      for (final we in s.exercises) {
        if (we.exerciseId != exerciseId) continue;
        final best = we.best1rm;
        if (best <= 0) continue;
        points.add(ChartPoint(label: formatShort(s.date), value: best, date: s.date));
      }
    }
    return points;
  }

  /// 종목별 개인 최고 기록. 추정 1RM이 높은 순.
  List<PersonalRecord> personalRecords() {
    final best = <String, PersonalRecord>{};
    for (final s in sessions) {
      for (final we in s.exercises) {
        final def = catalog.byId(we.exerciseId);
        if (def.tracking == TrackingType.cardio) continue;
        final oneRm = we.best1rm;
        if (oneRm <= 0) continue;
        final current = best[we.exerciseId];
        if (current == null || oneRm > current.best1rm) {
          best[we.exerciseId] = PersonalRecord(
            exercise: def,
            topWeight: we.topWeight,
            best1rm: oneRm,
            date: s.date,
          );
        }
      }
    }
    return best.values.toList()..sort((a, b) => b.best1rm.compareTo(a.best1rm));
  }

  /// 가장 많이 한 종목 상위 [limit]개 (세트 수 기준).
  List<ChartPoint> topExercises(StatsRange range, {int limit = 5, DateTime? now}) {
    final list = forRange(range, now: now);
    final counts = <String, int>{};
    for (final s in list) {
      for (final we in s.exercises) {
        counts[we.exerciseId] = (counts[we.exerciseId] ?? 0) + we.doneSets.length;
      }
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(limit)
        .map((e) => ChartPoint(label: catalog.byId(e.key).name, value: e.value.toDouble()))
        .toList();
  }

  /// 직전 동일 길이 구간 대비 볼륨 증감률(%). 비교 대상이 없으면 null.
  double? volumeChangePercent(StatsRange range, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final currentStart = today.subtract(Duration(days: range.days - 1));
    final prevEnd = currentStart.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: range.days - 1));

    final current = inRange(currentStart, today).fold(0.0, (a, s) => a + s.totalVolume);
    final previous = inRange(prevStart, prevEnd).fold(0.0, (a, s) => a + s.totalVolume);
    if (previous <= 0) return null;
    return (current - previous) / previous * 100;
  }

  /// 날짜별 총 볼륨 — 캘린더 히트맵용.
  Map<DateTime, double> volumeByDay() {
    final map = <DateTime, double>{};
    for (final s in sessions) {
      final d = dateOnly(s.date);
      map[d] = (map[d] ?? 0) + s.totalVolume;
    }
    return map;
  }
}
