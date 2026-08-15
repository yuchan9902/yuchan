import 'package:flutter/foundation.dart';

import '../data/exercise_catalog.dart';
import '../data/sample_data.dart';
import '../data/workout_repository.dart';
import '../models/models.dart';
import '../utils/date_x.dart';
import '../utils/stats.dart';

/// 앱 전체의 단일 상태 소유자.
///
/// 화면은 여기서 읽고 여기로만 쓴다. 변경이 생기면 저장소에 비동기로 반영한다.
class WorkoutStore extends ChangeNotifier {
  WorkoutStore(this._repo);

  final WorkoutRepository _repo;

  List<WorkoutSession> _sessions = [];
  List<ExerciseDef> _customExercises = [];
  int _weeklyGoal = 4;
  bool _darkMode = true;
  bool _loading = true;

  bool get loading => _loading;

  /// 최신순으로 정렬된 세션 목록.
  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);

  List<ExerciseDef> get customExercises => List.unmodifiable(_customExercises);

  int get weeklyGoal => _weeklyGoal;

  bool get darkMode => _darkMode;

  ExerciseCatalog get catalog => ExerciseCatalog(_customExercises);

  StatsEngine get stats => StatsEngine(_sessions, catalog);

  Future<void> init() async {
    final state = await _repo.load();
    _sessions = state.sessions;
    _customExercises = state.customExercises;
    _weeklyGoal = state.weeklyGoal;
    _darkMode = state.darkMode;

    // 완전히 처음 켠 경우에만 예시 기록을 넣는다.
    if (!state.seeded && _sessions.isEmpty) {
      _sessions = generateSampleSessions();
      await _repo.saveSessions(_sessions);
      await _repo.saveSeeded(true);
    }

    _sort();
    _loading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- 세션 CRUD

  WorkoutSession? sessionById(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<WorkoutSession> sessionsOn(DateTime day) =>
      _sessions.where((s) => isSameDay(s.date, day)).toList();

  WorkoutSession? get latestSession => _sessions.isEmpty ? null : _sessions.first;

  /// 새 세션을 만들어 돌려준다(저장은 [upsertSession] 시점에).
  WorkoutSession draftSession({DateTime? date}) => WorkoutSession(
        id: 'w${DateTime.now().microsecondsSinceEpoch}',
        date: dateOnly(date ?? DateTime.now()),
        durationMin: 60,
      );

  Future<void> upsertSession(WorkoutSession session) async {
    final normalized = session.copyWith(date: dateOnly(session.date));
    final index = _sessions.indexWhere((s) => s.id == normalized.id);
    if (index >= 0) {
      _sessions[index] = normalized;
    } else {
      _sessions.add(normalized);
    }
    _sort();
    notifyListeners();
    await _repo.saveSessions(_sessions);
  }

  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    notifyListeners();
    await _repo.saveSessions(_sessions);
  }

  /// 지난 세션을 오늘 날짜로 복제한다. 무게/횟수는 그대로 가져오고 완료 표시만 초기화.
  Future<WorkoutSession> repeatSession(WorkoutSession source, {DateTime? date}) async {
    final copy = WorkoutSession(
      id: 'w${DateTime.now().microsecondsSinceEpoch}',
      date: dateOnly(date ?? DateTime.now()),
      title: source.title,
      durationMin: source.durationMin,
      condition: 3,
      exercises: source.exercises
          .map(
            (e) => e.copyWith(
              sets: e.sets.map((s) => s.copyWith(done: false)).toList(),
            ),
          )
          .toList(),
    );
    await upsertSession(copy);
    return copy;
  }

  /// 직전에 이 종목을 했을 때의 세트 구성. 새 세트를 추가할 때 기본값으로 쓴다.
  WorkoutExercise? lastPerformed(String exerciseId, {String? excludeSessionId}) {
    for (final s in _sessions) {
      if (s.id == excludeSessionId) continue;
      for (final e in s.exercises) {
        if (e.exerciseId == exerciseId && e.sets.isNotEmpty) return e;
      }
    }
    return null;
  }

  // ------------------------------------------------------------- 커스텀 종목

  Future<ExerciseDef> addCustomExercise({
    required String name,
    required MuscleGroup group,
    required TrackingType tracking,
  }) async {
    final def = ExerciseDef(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      group: group,
      tracking: tracking,
      custom: true,
    );
    _customExercises.add(def);
    notifyListeners();
    await _repo.saveCustomExercises(_customExercises);
    return def;
  }

  Future<void> deleteCustomExercise(String id) async {
    _customExercises.removeWhere((e) => e.id == id);
    notifyListeners();
    await _repo.saveCustomExercises(_customExercises);
  }

  // ------------------------------------------------------------------ 설정

  Future<void> setWeeklyGoal(int goal) async {
    _weeklyGoal = goal.clamp(1, 7);
    notifyListeners();
    await _repo.saveWeeklyGoal(_weeklyGoal);
  }

  Future<void> setDarkMode(bool dark) async {
    _darkMode = dark;
    notifyListeners();
    await _repo.saveDarkMode(dark);
  }

  Future<void> clearAll() async {
    _sessions = [];
    notifyListeners();
    await _repo.saveSessions(_sessions);
    await _repo.saveSeeded(true);
  }

  Future<void> restoreSampleData() async {
    _sessions = generateSampleSessions();
    _sort();
    notifyListeners();
    await _repo.saveSessions(_sessions);
    await _repo.saveSeeded(true);
  }

  // --------------------------------------------------------------- 파생 지표

  /// 이번 주(월~일) 운동한 날 수.
  int get thisWeekCount {
    final start = startOfWeek(DateTime.now());
    final end = start.add(const Duration(days: 6));
    return stats
        .inRange(start, end)
        .map((s) => dateOnly(s.date))
        .toSet()
        .length;
  }

  double get weeklyGoalProgress =>
      _weeklyGoal == 0 ? 0 : (thisWeekCount / _weeklyGoal).clamp(0.0, 1.0);

  void _sort() => _sessions.sort((a, b) => b.date.compareTo(a.date));
}
