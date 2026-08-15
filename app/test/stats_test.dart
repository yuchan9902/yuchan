import 'package:fitlog/data/exercise_catalog.dart';
import 'package:fitlog/models/models.dart';
import 'package:fitlog/utils/date_x.dart';
import 'package:fitlog/utils/stats.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession session(
  DateTime date, {
  List<WorkoutExercise> exercises = const [],
  int durationMin = 60,
}) =>
    WorkoutSession(
      id: 'w${date.millisecondsSinceEpoch}',
      date: date,
      exercises: exercises,
      durationMin: durationMin,
    );

WorkoutExercise lift(String id, List<(double, int)> sets) => WorkoutExercise(
      exerciseId: id,
      sets: sets.map((s) => SetEntry(weight: s.$1, reps: s.$2)).toList(),
    );

void main() {
  final catalog = ExerciseCatalog(const []);
  final today = DateTime(2026, 8, 15);

  group('볼륨 계산', () {
    test('완료된 세트만 볼륨에 포함된다', () {
      const exercise = WorkoutExercise(
        exerciseId: 'bench_press',
        sets: [
          SetEntry(weight: 60, reps: 10),
          SetEntry(weight: 60, reps: 8, done: false),
        ],
      );
      expect(exercise.volume, 600);
      expect(exercise.totalReps, 10);
    });

    test('세션 볼륨은 모든 종목의 합', () {
      final s = session(
        today,
        exercises: [
          lift('bench_press', [(60, 10), (60, 10)]),
          lift('squat', [(100, 5)]),
        ],
      );
      expect(s.totalVolume, 1700);
      expect(s.totalSets, 3);
    });
  });

  group('1RM 추정 (Epley)', () {
    test('1회 반복은 무게 그대로', () {
      const set = SetEntry(weight: 100, reps: 1);
      expect(set.estimated1rm, 100);
    });

    test('10회 100kg는 약 133.3kg', () {
      const set = SetEntry(weight: 100, reps: 10);
      expect(set.estimated1rm, closeTo(133.33, 0.01));
    });

    test('완료하지 않은 세트는 0', () {
      const set = SetEntry(weight: 100, reps: 5, done: false);
      expect(set.estimated1rm, 0);
    });
  });

  group('연속 기록', () {
    test('오늘 포함해 이어지면 그만큼 센다', () {
      final engine = StatsEngine([
        session(today),
        session(today.subtract(const Duration(days: 1))),
        session(today.subtract(const Duration(days: 2))),
      ], catalog);
      expect(engine.currentStreak(now: today), 3);
    });

    test('오늘 안 했어도 어제까지 이어졌으면 유지된다', () {
      final engine = StatsEngine([
        session(today.subtract(const Duration(days: 1))),
        session(today.subtract(const Duration(days: 2))),
      ], catalog);
      expect(engine.currentStreak(now: today), 2);
    });

    test('이틀 이상 비면 0', () {
      final engine = StatsEngine([
        session(today.subtract(const Duration(days: 3))),
      ], catalog);
      expect(engine.currentStreak(now: today), 0);
    });

    test('최장 연속 기록을 찾는다', () {
      final engine = StatsEngine([
        session(DateTime(2026, 8, 1)),
        session(DateTime(2026, 8, 2)),
        session(DateTime(2026, 8, 3)),
        session(DateTime(2026, 8, 4)),
        session(DateTime(2026, 8, 10)),
      ], catalog);
      expect(engine.longestStreak(), 4);
    });
  });

  group('기간 집계', () {
    test('주간 구간은 오늘 포함 7일', () {
      final engine = StatsEngine([
        session(today),
        session(today.subtract(const Duration(days: 6))),
        session(today.subtract(const Duration(days: 7))), // 범위 밖
      ], catalog);
      expect(engine.forRange(StatsRange.week, now: today).length, 2);
    });

    test('일별 볼륨은 쉰 날도 0으로 채운다', () {
      final engine = StatsEngine([
        session(today, exercises: [lift('squat', [(100, 10)])]),
      ], catalog);
      final points = engine.dailyVolume(StatsRange.week, now: today);
      expect(points.length, 7);
      expect(points.last.value, 1000);
      expect(points.first.value, 0);
    });

    test('직전 기간 대비 증감률', () {
      final engine = StatsEngine([
        // 이번 주: 2000
        session(today, exercises: [lift('squat', [(100, 20)])]),
        // 지난 주: 1000
        session(
          today.subtract(const Duration(days: 8)),
          exercises: [lift('squat', [(100, 10)])],
        ),
      ], catalog);
      expect(engine.volumeChangePercent(StatsRange.week, now: today), 100);
    });

    test('비교할 이전 기록이 없으면 null', () {
      final engine = StatsEngine([
        session(today, exercises: [lift('squat', [(100, 10)])]),
      ], catalog);
      expect(engine.volumeChangePercent(StatsRange.week, now: today), isNull);
    });
  });

  group('부위별 분포', () {
    test('비율의 합은 1', () {
      final engine = StatsEngine([
        session(today, exercises: [
          lift('bench_press', [(60, 10)]), // 가슴 600
          lift('squat', [(100, 10)]), // 하체 1000
        ]),
      ], catalog);
      final slices = engine.groupDistribution(StatsRange.week, now: today);
      expect(slices.length, 2);
      expect(slices.fold(0.0, (a, s) => a + s.ratio), closeTo(1.0, 1e-9));
      // 큰 것부터 정렬된다.
      expect(slices.first.group, MuscleGroup.legs);
    });

    test('유산소는 시간을 볼륨으로 환산해 포함된다', () {
      final engine = StatsEngine([
        session(today, exercises: [
          const WorkoutExercise(exerciseId: 'running', durationMin: 30),
        ]),
      ], catalog);
      final slices = engine.groupDistribution(StatsRange.week, now: today);
      expect(slices.single.group, MuscleGroup.cardio);
      expect(slices.single.value, 3000);
    });
  });

  group('개인 기록', () {
    test('가장 높은 추정 1RM이 남는다', () {
      final engine = StatsEngine([
        session(today, exercises: [lift('bench_press', [(70, 5)])]),
        session(
          today.subtract(const Duration(days: 7)),
          exercises: [lift('bench_press', [(60, 10)])],
        ),
      ], catalog);
      final records = engine.personalRecords();
      expect(records.length, 1);
      // 70×5 = 81.67 vs 60×10 = 80 → 70kg 세트가 이긴다.
      expect(records.first.best1rm, closeTo(81.67, 0.01));
      expect(records.first.topWeight, 70);
    });

    test('유산소는 개인 기록에서 제외된다', () {
      final engine = StatsEngine([
        session(today, exercises: [
          const WorkoutExercise(exerciseId: 'running', durationMin: 30),
        ]),
      ], catalog);
      expect(engine.personalRecords(), isEmpty);
    });
  });

  group('날짜 헬퍼', () {
    test('주 시작은 월요일', () {
      // 2026-08-15는 토요일.
      expect(startOfWeek(DateTime(2026, 8, 15)), DateTime(2026, 8, 10));
    });

    test('상대 날짜 표기', () {
      expect(formatRelativeKo(today, now: today), '오늘');
      expect(
        formatRelativeKo(today.subtract(const Duration(days: 1)), now: today),
        '어제',
      );
    });

    test('큰 수는 축약한다', () {
      expect(compactNumber(12340), '12.3k');
      expect(compactNumber(1234), '1,234');
    });
  });

  group('직렬화', () {
    test('세션을 JSON으로 저장하고 되읽는다', () {
      final original = WorkoutSession(
        id: 'w1',
        date: DateTime(2026, 8, 15),
        title: '가슴 · 삼두',
        durationMin: 75,
        condition: 4,
        memo: '좋았음',
        exercises: [lift('bench_press', [(60, 10), (65, 8)])],
      );
      final restored = WorkoutSession.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.date, original.date);
      expect(restored.title, original.title);
      expect(restored.condition, 4);
      expect(restored.totalVolume, original.totalVolume);
      expect(restored.exercises.single.sets.length, 2);
    });
  });
}
