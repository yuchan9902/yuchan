import 'dart:math';

import '../models/models.dart';
import '../utils/date_x.dart';

/// 첫 실행 때 채워 넣는 예시 기록.
///
/// 통계 화면이 빈 상태로 보이면 무엇을 보여주는 앱인지 알기 어렵기 때문에,
/// 10주치 3분할 루틴을 점진적 과부하가 보이도록 생성한다.
/// 시드를 고정해서 실행할 때마다 같은 데이터가 나온다.
List<WorkoutSession> generateSampleSessions({DateTime? now, int weeks = 10}) {
  final today = dateOnly(now ?? DateTime.now());
  final rand = Random(20260815);
  final sessions = <WorkoutSession>[];

  // 3분할: 월/목 가슴+삼두, 화/금 등+이두, 수/토 하체+어깨
  const routines = <String, List<String>>{
    '가슴 · 삼두': ['bench_press', 'incline_bench', 'db_fly', 'cable_pushdown'],
    '등 · 이두': ['deadlift', 'lat_pulldown', 'seated_row', 'barbell_curl'],
    '하체 · 어깨': ['squat', 'leg_press', 'ohp', 'side_lateral'],
  };
  final routineNames = routines.keys.toList();

  // 종목별 시작 무게와 주당 증가량.
  const baseWeights = <String, double>{
    'bench_press': 55,
    'incline_bench': 42.5,
    'db_fly': 14,
    'cable_pushdown': 25,
    'deadlift': 80,
    'lat_pulldown': 50,
    'seated_row': 45,
    'barbell_curl': 22.5,
    'squat': 70,
    'leg_press': 120,
    'ohp': 32.5,
    'side_lateral': 8,
  };
  const weeklyGain = <String, double>{
    'bench_press': 1.25,
    'incline_bench': 1.0,
    'db_fly': 0.5,
    'cable_pushdown': 0.75,
    'deadlift': 2.5,
    'lat_pulldown': 1.25,
    'seated_row': 1.25,
    'barbell_curl': 0.5,
    'squat': 2.0,
    'leg_press': 4.0,
    'ohp': 0.75,
    'side_lateral': 0.25,
  };

  var sessionSeq = 0;

  for (var week = weeks - 1; week >= 0; week--) {
    // 주당 운동 요일: 월, 화, 목, 금, 토 중에서 3~5일.
    const candidateWeekdays = [1, 2, 4, 5, 6];
    final trainingDays = 3 + rand.nextInt(3);
    final picked = [...candidateWeekdays]..shuffle(rand);
    final weekdays = picked.take(trainingDays).toList()..sort();

    final weekStart = startOfWeek(today).subtract(Duration(days: 7 * week));

    for (var i = 0; i < weekdays.length; i++) {
      final date = weekStart.add(Duration(days: weekdays[i] - 1));
      if (date.isAfter(today)) continue;

      final routineName = routineNames[sessionSeq % routineNames.length];
      final exerciseIds = routines[routineName]!;
      sessionSeq++;

      final progressWeek = (weeks - 1 - week).toDouble();
      final exercises = <WorkoutExercise>[];

      for (final id in exerciseIds) {
        final base = baseWeights[id]!;
        final gain = weeklyGain[id]!;
        // 2.5kg 단위로 떨어지도록 반올림하고, 컨디션에 따른 흔들림을 조금 준다.
        final raw = base + gain * progressWeek + (rand.nextInt(3) - 1) * 1.25;
        final weight = (raw / 1.25).round() * 1.25;

        final setCount = 3 + (rand.nextInt(10) < 4 ? 1 : 0);
        final sets = List.generate(setCount, (s) {
          // 뒤 세트로 갈수록 횟수가 조금씩 준다.
          final reps = (10 - s + rand.nextInt(3) - 1).clamp(5, 12);
          return SetEntry(weight: weight, reps: reps);
        });
        exercises.add(WorkoutExercise(exerciseId: id, sets: sets));
      }

      // 5회 중 1회 정도는 마무리 유산소를 붙인다.
      if (rand.nextInt(5) == 0) {
        final minutes = 15 + rand.nextInt(21);
        exercises.add(
          WorkoutExercise(
            exerciseId: 'running',
            durationMin: minutes,
            distanceKm: (minutes / 6.2 * 10).round() / 10,
          ),
        );
      }

      sessions.add(
        WorkoutSession(
          id: 'sample_${date.millisecondsSinceEpoch}_$sessionSeq',
          date: date,
          title: routineName,
          exercises: exercises,
          durationMin: 55 + rand.nextInt(35),
          condition: 3 + rand.nextInt(3) - (rand.nextInt(6) == 0 ? 1 : 0),
          memo: rand.nextInt(4) == 0 ? '컨디션 좋았음. 마지막 세트까지 깔끔하게.' : '',
        ),
      );
    }
  }

  sessions.sort((a, b) => b.date.compareTo(a.date));
  return sessions;
}
