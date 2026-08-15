import 'package:flutter/material.dart';

/// 운동 부위 분류. 통계 화면의 부위별 분포에 사용된다.
enum MuscleGroup {
  chest('가슴', Color(0xFF7C5CFF)),
  back('등', Color(0xFF3B9EFF)),
  legs('하체', Color(0xFF26E5A1)),
  shoulders('어깨', Color(0xFFFFB020)),
  arms('팔', Color(0xFFFF6B9D)),
  core('코어', Color(0xFF9B8AFF)),
  cardio('유산소', Color(0xFFFF5A6E));

  const MuscleGroup(this.label, this.color);

  final String label;
  final Color color;

  static MuscleGroup fromName(String name) =>
      MuscleGroup.values.firstWhere((g) => g.name == name, orElse: () => MuscleGroup.chest);
}

/// 종목이 어떤 값을 입력받는지 결정한다.
enum TrackingType {
  /// 무게 × 횟수 (웨이트 트레이닝)
  weightReps,

  /// 맨몸 — 횟수만
  bodyweight,

  /// 시간 + 거리 (유산소)
  cardio,
}

/// 종목 정의(카탈로그 항목). 사용자가 추가한 종목도 같은 형태로 저장된다.
@immutable
class ExerciseDef {
  const ExerciseDef({
    required this.id,
    required this.name,
    required this.group,
    this.tracking = TrackingType.weightReps,
    this.custom = false,
  });

  final String id;
  final String name;
  final MuscleGroup group;
  final TrackingType tracking;
  final bool custom;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'group': group.name,
        'tracking': tracking.name,
        'custom': custom,
      };

  static ExerciseDef fromJson(Map<String, dynamic> json) => ExerciseDef(
        id: json['id'] as String,
        name: json['name'] as String,
        group: MuscleGroup.fromName(json['group'] as String),
        tracking: TrackingType.values.firstWhere(
          (t) => t.name == json['tracking'],
          orElse: () => TrackingType.weightReps,
        ),
        custom: json['custom'] as bool? ?? false,
      );
}

/// 한 세트의 기록.
@immutable
class SetEntry {
  const SetEntry({this.weight = 0, this.reps = 0, this.done = true});

  /// kg. 맨몸 운동은 0.
  final double weight;
  final int reps;

  /// 체크되지 않은 세트는 볼륨 계산에서 제외된다.
  final bool done;

  /// 이 세트가 만들어낸 볼륨(kg).
  /// 맨몸 운동(무게 0)은 횟수만큼의 볼륨으로 환산하지 않고 0으로 둔다.
  double get volume => done ? weight * reps : 0;

  /// Epley 공식 기반 1RM 추정치.
  double get estimated1rm {
    if (!done || weight <= 0 || reps <= 0) return 0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }

  SetEntry copyWith({double? weight, int? reps, bool? done}) => SetEntry(
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {'w': weight, 'r': reps, 'd': done};

  static SetEntry fromJson(Map<String, dynamic> json) => SetEntry(
        weight: (json['w'] as num?)?.toDouble() ?? 0,
        reps: (json['r'] as num?)?.toInt() ?? 0,
        done: json['d'] as bool? ?? true,
      );
}

/// 한 세션 안에서 수행한 하나의 종목.
@immutable
class WorkoutExercise {
  const WorkoutExercise({
    required this.exerciseId,
    this.sets = const [],
    this.durationMin = 0,
    this.distanceKm = 0,
  });

  final String exerciseId;
  final List<SetEntry> sets;

  /// 유산소 전용.
  final int durationMin;
  final double distanceKm;

  List<SetEntry> get doneSets => sets.where((s) => s.done).toList();

  double get volume => sets.fold(0.0, (sum, s) => sum + s.volume);

  int get totalReps => sets.where((s) => s.done).fold(0, (sum, s) => sum + s.reps);

  double get best1rm =>
      sets.fold(0.0, (best, s) => s.estimated1rm > best ? s.estimated1rm : best);

  double get topWeight =>
      sets.where((s) => s.done).fold(0.0, (best, s) => s.weight > best ? s.weight : best);

  WorkoutExercise copyWith({
    List<SetEntry>? sets,
    int? durationMin,
    double? distanceKm,
  }) =>
      WorkoutExercise(
        exerciseId: exerciseId,
        sets: sets ?? this.sets,
        durationMin: durationMin ?? this.durationMin,
        distanceKm: distanceKm ?? this.distanceKm,
      );

  Map<String, dynamic> toJson() => {
        'e': exerciseId,
        's': sets.map((s) => s.toJson()).toList(),
        'dur': durationMin,
        'dist': distanceKm,
      };

  static WorkoutExercise fromJson(Map<String, dynamic> json) => WorkoutExercise(
        exerciseId: json['e'] as String,
        sets: (json['s'] as List<dynamic>? ?? const [])
            .map((s) => SetEntry.fromJson(s as Map<String, dynamic>))
            .toList(),
        durationMin: (json['dur'] as num?)?.toInt() ?? 0,
        distanceKm: (json['dist'] as num?)?.toDouble() ?? 0,
      );
}

/// 하루의 운동 세션 하나.
@immutable
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.date,
    this.title = '',
    this.exercises = const [],
    this.durationMin = 0,
    this.memo = '',
    this.condition = 3,
  });

  final String id;

  /// 날짜만 의미가 있다(시각은 자정으로 정규화해서 저장).
  final DateTime date;
  final String title;
  final List<WorkoutExercise> exercises;

  /// 총 운동 시간(분).
  final int durationMin;
  final String memo;

  /// 컨디션 1~5.
  final int condition;

  double get totalVolume => exercises.fold(0.0, (sum, e) => sum + e.volume);

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.doneSets.length);

  int get totalReps => exercises.fold(0, (sum, e) => sum + e.totalReps);

  bool get isEmpty => exercises.isEmpty;

  WorkoutSession copyWith({
    DateTime? date,
    String? title,
    List<WorkoutExercise>? exercises,
    int? durationMin,
    String? memo,
    int? condition,
  }) =>
      WorkoutSession(
        id: id,
        date: date ?? this.date,
        title: title ?? this.title,
        exercises: exercises ?? this.exercises,
        durationMin: durationMin ?? this.durationMin,
        memo: memo ?? this.memo,
        condition: condition ?? this.condition,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'ex': exercises.map((e) => e.toJson()).toList(),
        'dur': durationMin,
        'memo': memo,
        'cond': condition,
      };

  static WorkoutSession fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        title: json['title'] as String? ?? '',
        exercises: (json['ex'] as List<dynamic>? ?? const [])
            .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        durationMin: (json['dur'] as num?)?.toInt() ?? 0,
        memo: json['memo'] as String? ?? '',
        condition: (json['cond'] as num?)?.toInt() ?? 3,
      );
}
