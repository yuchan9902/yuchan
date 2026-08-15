import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/workout_store.dart';
import '../theme/app_theme.dart';
import '../utils/date_x.dart';
import '../widgets/common.dart';
import 'exercise_picker_screen.dart';

/// 세션 작성/편집 화면.
///
/// 편집 중에는 로컬 사본만 고치고, 나가거나 저장을 누를 때 스토어에 반영한다.
class SessionEditorScreen extends StatefulWidget {
  const SessionEditorScreen({
    super.key,
    required this.session,
    this.isNew = false,
  });

  final WorkoutSession session;
  final bool isNew;

  @override
  State<SessionEditorScreen> createState() => _SessionEditorScreenState();
}

class _SessionEditorScreenState extends State<SessionEditorScreen> {
  late WorkoutSession _draft = widget.session;
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.session.title);
  late final TextEditingController _memoCtrl =
      TextEditingController(text: widget.session.memo);
  bool _dirty = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  void _update(WorkoutSession next) {
    setState(() {
      _draft = next;
      _dirty = true;
    });
  }

  Future<void> _save({bool pop = true}) async {
    final store = context.read<WorkoutStore>();
    final toSave = _draft.copyWith(
      title: _titleCtrl.text.trim(),
      memo: _memoCtrl.text.trim(),
    );

    // 새로 만든 세션인데 종목이 하나도 없으면 저장하지 않는다.
    if (widget.isNew && toSave.isEmpty) {
      if (pop && mounted) Navigator.of(context).pop();
      return;
    }

    await store.upsertSession(toSave);
    if (!mounted) return;
    if (pop) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dirty = false);
    }
  }

  Future<void> _addExercise() async {
    final store = context.read<WorkoutStore>();
    final picked = await Navigator.of(context).push<ExerciseDef>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (picked == null || !mounted) return;

    // 직전에 같은 종목을 했다면 그때 무게/횟수를 기본값으로 가져온다.
    final last = store.lastPerformed(picked.id, excludeSessionId: _draft.id);
    final WorkoutExercise entry;
    if (picked.tracking == TrackingType.cardio) {
      entry = WorkoutExercise(exerciseId: picked.id, durationMin: 20, distanceKm: 3);
    } else if (last != null) {
      entry = WorkoutExercise(
        exerciseId: picked.id,
        sets: last.sets.map((s) => s.copyWith(done: false)).toList(),
      );
    } else {
      entry = WorkoutExercise(
        exerciseId: picked.id,
        sets: List.generate(
          3,
          (_) => SetEntry(
            weight: picked.tracking == TrackingType.bodyweight ? 0 : 20,
            reps: 10,
            done: false,
          ),
        ),
      );
    }

    _update(_draft.copyWith(exercises: [..._draft.exercises, entry]));
  }

  void _updateExercise(int index, WorkoutExercise next) {
    final list = [..._draft.exercises];
    list[index] = next;
    _update(_draft.copyWith(exercises: list));
  }

  void _removeExercise(int index) {
    final list = [..._draft.exercises]..removeAt(index);
    _update(_draft.copyWith(exercises: list));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) _update(_draft.copyWith(date: dateOnly(picked)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final c = context.colors;
    final catalog = store.catalog;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_dirty) {
          await _save();
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(
          title: Text(widget.isNew ? '운동 기록' : '기록 편집'),
          actions: [
            if (!widget.isNew)
              IconButton(
                tooltip: '삭제',
                icon: Icon(Icons.delete_outline_rounded, color: c.negative),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final ok = await _confirmDelete();
                  if (!ok || !mounted) return;
                  await store.deleteSession(_draft.id);
                  if (mounted) navigator.pop();
                },
              ),
            TextButton(
              onPressed: () => _save(),
              child: const Text(
                '저장',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
          children: [
            _SummaryBar(session: _draft),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  _Field(
                    label: '날짜',
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatDayKo(_draft.date),
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_calendar_outlined,
                                size: 16, color: c.textFaint),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleCtrl,
                    onChanged: (_) => _dirty = true,
                    style: TextStyle(color: c.textPrimary),
                    decoration: const InputDecoration(
                      labelText: '루틴 이름',
                      hintText: '예: 가슴 · 삼두',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: '운동 시간',
                    child: _Stepper(
                      value: _draft.durationMin.toDouble(),
                      step: 5,
                      min: 0,
                      max: 300,
                      format: (v) => '${v.round()}분',
                      onChanged: (v) =>
                          _update(_draft.copyWith(durationMin: v.round())),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    label: '컨디션',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        final level = i + 1;
                        final active = level <= _draft.condition;
                        return GestureDetector(
                          onTap: () => _update(_draft.copyWith(condition: level)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Icon(
                              active
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 24,
                              color: active ? c.warning : c.textFaint,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionHeader(
              title: '종목',
              subtitle: _draft.exercises.isEmpty
                  ? '아래에서 종목을 추가하세요'
                  : '${_draft.exercises.length}개 종목',
            ),
            for (var i = 0; i < _draft.exercises.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExerciseBlock(
                  key: ValueKey('${_draft.exercises[i].exerciseId}_$i'),
                  def: catalog.byId(_draft.exercises[i].exerciseId),
                  entry: _draft.exercises[i],
                  onChanged: (next) => _updateExercise(i, next),
                  onRemove: () => _removeExercise(i),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('종목 추가'),
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '메모'),
            TextField(
              controller: _memoCtrl,
              onChanged: (_) => _dirty = true,
              maxLines: 3,
              style: TextStyle(color: c.textPrimary),
              decoration: const InputDecoration(
                hintText: '오늘 운동은 어땠나요?',
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _save(),
                child: const Text('저장하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: const Text('기록을 삭제할까요?'),
        content: const Text('삭제한 기록은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.negative),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// 편집 중 실시간으로 갱신되는 합계 바.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.accent, c.accent.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _SummaryMetric(
            value: compactNumber(session.totalVolume),
            unit: 'kg',
            label: '총 볼륨',
          ),
          _SummaryMetric(
            value: '${session.totalSets}',
            unit: '세트',
            label: '완료 세트',
          ),
          _SummaryMetric(
            value: '${session.totalReps}',
            unit: '회',
            label: '총 횟수',
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 종목 하나 + 그 세트들.
class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    super.key,
    required this.def,
    required this.entry,
    required this.onChanged,
    required this.onRemove,
  });

  final ExerciseDef def;
  final WorkoutExercise entry;
  final ValueChanged<WorkoutExercise> onChanged;
  final VoidCallback onRemove;

  void _addSet() {
    // 마지막 세트를 복제해서 이어가는 게 가장 흔한 동작.
    final last = entry.sets.isNotEmpty
        ? entry.sets.last
        : SetEntry(weight: def.tracking == TrackingType.bodyweight ? 0 : 20, reps: 10);
    onChanged(
      entry.copyWith(sets: [...entry.sets, last.copyWith(done: false)]),
    );
  }

  void _updateSet(int index, SetEntry next) {
    final sets = [...entry.sets];
    sets[index] = next;
    onChanged(entry.copyWith(sets: sets));
  }

  void _removeSet(int index) {
    final sets = [...entry.sets]..removeAt(index);
    onChanged(entry.copyWith(sets: sets));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCardio = def.tracking == TrackingType.cardio;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GroupDot(group: def.group, size: 9),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  def.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isCardio)
                Text(
                  '${compactNumber(entry.volume)}kg',
                  style: TextStyle(
                    color: c.textFaint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              IconButton(
                onPressed: onRemove,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, color: c.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isCardio)
            _CardioInputs(entry: entry, onChanged: onChanged)
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 8, bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text('#',
                        style: TextStyle(color: c.textFaint, fontSize: 11)),
                  ),
                  Expanded(
                    child: Text('무게 (kg)',
                        style: TextStyle(color: c.textFaint, fontSize: 11)),
                  ),
                  Expanded(
                    child: Text('횟수',
                        style: TextStyle(color: c.textFaint, fontSize: 11)),
                  ),
                  const SizedBox(width: 74),
                ],
              ),
            ),
            for (var i = 0; i < entry.sets.length; i++)
              _SetRow(
                key: ValueKey('set_$i'),
                index: i,
                set: entry.sets[i],
                bodyweight: def.tracking == TrackingType.bodyweight,
                onChanged: (s) => _updateSet(i, s),
                onRemove: entry.sets.length > 1 ? () => _removeSet(i) : null,
              ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _addSet,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('세트 추가'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 세트 한 줄: 무게 / 횟수 / 완료 체크.
class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.bodyweight,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final SetEntry set;
  final bool bodyweight;
  final ValueChanged<SetEntry> onChanged;
  final VoidCallback? onRemove;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weightCtrl =
      TextEditingController(text: formatWeight(widget.set.weight));
  late final TextEditingController _repsCtrl =
      TextEditingController(text: widget.set.reps.toString());

  @override
  void didUpdateWidget(_SetRow old) {
    super.didUpdateWidget(old);
    // 외부에서 값이 바뀐 경우에만 컨트롤러를 갱신한다. 타이핑 중 커서가 튀지 않도록
    // 현재 입력값과 숫자로 같으면 건드리지 않는다.
    final typedWeight = double.tryParse(_weightCtrl.text);
    if (typedWeight != widget.set.weight) {
      _weightCtrl.text = formatWeight(widget.set.weight);
    }
    final typedReps = int.tryParse(_repsCtrl.text);
    if (typedReps != widget.set.reps) {
      _repsCtrl.text = widget.set.reps.toString();
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = widget.set.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${widget.index + 1}',
              style: TextStyle(
                color: done ? c.accent : c.textFaint,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: _NumberField(
              controller: _weightCtrl,
              enabled: !widget.bodyweight,
              hint: widget.bodyweight ? '맨몸' : '0',
              onChanged: (text) => widget.onChanged(
                widget.set.copyWith(weight: double.tryParse(text) ?? 0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NumberField(
              controller: _repsCtrl,
              hint: '0',
              integer: true,
              onChanged: (text) => widget.onChanged(
                widget.set.copyWith(reps: int.tryParse(text) ?? 0),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: done ? '완료 해제' : '완료',
            onPressed: () => widget.onChanged(widget.set.copyWith(done: !done)),
            iconSize: 22,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: done ? c.positive : c.textFaint,
            ),
          ),
          SizedBox(
            width: 32,
            child: widget.onRemove == null
                ? null
                : IconButton(
                    onPressed: widget.onRemove,
                    iconSize: 17,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.remove_circle_outline_rounded,
                        color: c.textFaint),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.integer = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool enabled;
  final bool integer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          integer ? RegExp(r'\d*') : RegExp(r'^\d*\.?\d*'),
        ),
      ],
      textAlign: TextAlign.center,
      style: TextStyle(
        color: enabled ? c.textPrimary : c.textFaint,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      ),
    );
  }
}

/// 유산소 입력: 시간과 거리.
class _CardioInputs extends StatelessWidget {
  const _CardioInputs({required this.entry, required this.onChanged});

  final WorkoutExercise entry;
  final ValueChanged<WorkoutExercise> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(
          label: '시간',
          child: _Stepper(
            value: entry.durationMin.toDouble(),
            step: 5,
            min: 0,
            max: 300,
            format: (v) => '${v.round()}분',
            onChanged: (v) => onChanged(entry.copyWith(durationMin: v.round())),
          ),
        ),
        const SizedBox(height: 10),
        _Field(
          label: '거리',
          child: _Stepper(
            value: entry.distanceKm,
            step: 0.5,
            min: 0,
            max: 100,
            format: (v) => '${v.toStringAsFixed(1)}km',
            onChanged: (v) => onChanged(entry.copyWith(distanceKm: v)),
          ),
        ),
      ],
    );
  }
}

/// 라벨 + 우측 컨트롤 한 줄.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        child,
      ],
    );
  }
}

/// -/+ 버튼이 달린 숫자 조절기.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  final double value;
  final double step;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: value <= min
                ? null
                : () => onChanged((value - step).clamp(min, max)),
          ),
          SizedBox(
            width: 66,
            child: Text(
              format(value),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: value >= max
                ? null
                : () => onChanged((value + step).clamp(min, max)),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 36,
        height: 38,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? c.textFaint.withValues(alpha: 0.4) : c.textPrimary,
        ),
      ),
    );
  }
}
