import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 저장소에서 읽어온 전체 앱 상태.
class PersistedState {
  const PersistedState({
    required this.sessions,
    required this.customExercises,
    required this.weeklyGoal,
    required this.darkMode,
    required this.seeded,
  });

  final List<WorkoutSession> sessions;
  final List<ExerciseDef> customExercises;
  final int weeklyGoal;
  final bool darkMode;

  /// 예시 데이터를 이미 한 번 넣었는지. 사용자가 지운 뒤 다시 생기지 않게 한다.
  final bool seeded;
}

/// shared_preferences 기반 저장소.
/// 웹에서는 localStorage, 모바일에서는 네이티브 preference 로 저장된다.
class WorkoutRepository {
  static const _kSessions = 'fitlog.sessions.v1';
  static const _kCustomExercises = 'fitlog.custom_exercises.v1';
  static const _kWeeklyGoal = 'fitlog.weekly_goal.v1';
  static const _kDarkMode = 'fitlog.dark_mode.v1';
  static const _kSeeded = 'fitlog.seeded.v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<PersistedState> load() async {
    final p = await _p;
    return PersistedState(
      sessions: _decodeList(p.getString(_kSessions), WorkoutSession.fromJson),
      customExercises: _decodeList(p.getString(_kCustomExercises), ExerciseDef.fromJson),
      weeklyGoal: p.getInt(_kWeeklyGoal) ?? 4,
      darkMode: p.getBool(_kDarkMode) ?? true,
      seeded: p.getBool(_kSeeded) ?? false,
    );
  }

  Future<void> saveSessions(List<WorkoutSession> sessions) async {
    final p = await _p;
    await p.setString(
      _kSessions,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> saveCustomExercises(List<ExerciseDef> exercises) async {
    final p = await _p;
    await p.setString(
      _kCustomExercises,
      jsonEncode(exercises.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveWeeklyGoal(int goal) async => (await _p).setInt(_kWeeklyGoal, goal);

  Future<void> saveDarkMode(bool dark) async => (await _p).setBool(_kDarkMode, dark);

  Future<void> saveSeeded(bool seeded) async => (await _p).setBool(_kSeeded, seeded);

  /// 저장된 JSON이 깨져 있어도 앱이 뜨지 않는 상황은 만들지 않는다.
  static List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: true);
    } on FormatException {
      return [];
    }
  }
}
