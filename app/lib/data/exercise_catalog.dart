import '../models/models.dart';

/// 앱에 기본 내장된 종목 목록.
const List<ExerciseDef> kBuiltInExercises = [
  // 가슴
  ExerciseDef(id: 'bench_press', name: '벤치프레스', group: MuscleGroup.chest),
  ExerciseDef(id: 'incline_bench', name: '인클라인 벤치프레스', group: MuscleGroup.chest),
  ExerciseDef(id: 'db_fly', name: '덤벨 플라이', group: MuscleGroup.chest),
  ExerciseDef(id: 'chest_press', name: '체스트 프레스 머신', group: MuscleGroup.chest),
  ExerciseDef(
    id: 'push_up',
    name: '푸시업',
    group: MuscleGroup.chest,
    tracking: TrackingType.bodyweight,
  ),

  // 등
  ExerciseDef(id: 'deadlift', name: '데드리프트', group: MuscleGroup.back),
  ExerciseDef(id: 'barbell_row', name: '바벨 로우', group: MuscleGroup.back),
  ExerciseDef(id: 'lat_pulldown', name: '랫풀다운', group: MuscleGroup.back),
  ExerciseDef(id: 'seated_row', name: '시티드 로우', group: MuscleGroup.back),
  ExerciseDef(
    id: 'pull_up',
    name: '풀업',
    group: MuscleGroup.back,
    tracking: TrackingType.bodyweight,
  ),

  // 하체
  ExerciseDef(id: 'squat', name: '스쿼트', group: MuscleGroup.legs),
  ExerciseDef(id: 'leg_press', name: '레그프레스', group: MuscleGroup.legs),
  ExerciseDef(id: 'leg_extension', name: '레그 익스텐션', group: MuscleGroup.legs),
  ExerciseDef(id: 'leg_curl', name: '레그 컬', group: MuscleGroup.legs),
  ExerciseDef(id: 'lunge', name: '런지', group: MuscleGroup.legs),

  // 어깨
  ExerciseDef(id: 'ohp', name: '오버헤드 프레스', group: MuscleGroup.shoulders),
  ExerciseDef(id: 'side_lateral', name: '사이드 래터럴 레이즈', group: MuscleGroup.shoulders),
  ExerciseDef(id: 'face_pull', name: '페이스 풀', group: MuscleGroup.shoulders),

  // 팔
  ExerciseDef(id: 'barbell_curl', name: '바벨 컬', group: MuscleGroup.arms),
  ExerciseDef(id: 'db_curl', name: '덤벨 컬', group: MuscleGroup.arms),
  ExerciseDef(id: 'cable_pushdown', name: '케이블 푸시다운', group: MuscleGroup.arms),

  // 코어
  ExerciseDef(
    id: 'plank',
    name: '플랭크',
    group: MuscleGroup.core,
    tracking: TrackingType.bodyweight,
  ),
  ExerciseDef(
    id: 'hanging_leg_raise',
    name: '행잉 레그레이즈',
    group: MuscleGroup.core,
    tracking: TrackingType.bodyweight,
  ),
  ExerciseDef(
    id: 'crunch',
    name: '크런치',
    group: MuscleGroup.core,
    tracking: TrackingType.bodyweight,
  ),

  // 유산소
  ExerciseDef(
    id: 'running',
    name: '러닝',
    group: MuscleGroup.cardio,
    tracking: TrackingType.cardio,
  ),
  ExerciseDef(
    id: 'cycling',
    name: '사이클',
    group: MuscleGroup.cardio,
    tracking: TrackingType.cardio,
  ),
  ExerciseDef(
    id: 'rowing',
    name: '로잉머신',
    group: MuscleGroup.cardio,
    tracking: TrackingType.cardio,
  ),
  ExerciseDef(
    id: 'incline_walk',
    name: '경사 걷기',
    group: MuscleGroup.cardio,
    tracking: TrackingType.cardio,
  ),
];

/// 내장 종목 + 사용자 추가 종목을 합쳐 id로 조회할 수 있게 감싼 것.
class ExerciseCatalog {
  ExerciseCatalog(List<ExerciseDef> customExercises)
      : _all = [...kBuiltInExercises, ...customExercises],
        _byId = {
          for (final e in [...kBuiltInExercises, ...customExercises]) e.id: e,
        };

  final List<ExerciseDef> _all;
  final Map<String, ExerciseDef> _byId;

  List<ExerciseDef> get all => List.unmodifiable(_all);

  /// 알 수 없는 id는 삭제된 커스텀 종목일 수 있으므로 자리표시자를 돌려준다.
  ExerciseDef byId(String id) =>
      _byId[id] ??
      ExerciseDef(id: id, name: '알 수 없는 종목', group: MuscleGroup.chest, custom: true);

  List<ExerciseDef> byGroup(MuscleGroup group) =>
      _all.where((e) => e.group == group).toList();

  List<ExerciseDef> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return all;
    return _all.where((e) => e.name.contains(q)).toList();
  }
}
