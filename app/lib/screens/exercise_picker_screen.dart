import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/workout_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 종목 선택 화면. 검색 + 부위 필터 + 직접 추가.
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final _searchCtrl = TextEditingController();
  MuscleGroup? _filter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final c = context.colors;
    final catalog = store.catalog;

    var items = catalog.search(_searchCtrl.text);
    if (_filter != null) {
      items = items.where((e) => e.group == _filter).toList();
    }

    // 부위 순서대로 묶어서 보여준다.
    final grouped = <MuscleGroup, List<ExerciseDef>>{};
    for (final e in items) {
      grouped.putIfAbsent(e.group, () => []).add(e);
    }

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        title: const Text('종목 선택'),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddDialog(context, store),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('직접 추가'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: '종목 검색',
                prefixIcon: Icon(Icons.search_rounded, color: c.textFaint, size: 20),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: c.textFaint, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _FilterChip(
                  label: '전체',
                  color: c.accent,
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                ...MuscleGroup.values.map(
                  (g) => _FilterChip(
                    label: g.label,
                    color: g.color,
                    selected: _filter == g,
                    onTap: () => setState(() => _filter = _filter == g ? null : g),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: '찾는 종목이 없어요',
                    message: '«직접 추가»로 새 종목을 만들 수 있어요.',
                    action: FilledButton.icon(
                      onPressed: () => _showAddDialog(context, store),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('종목 직접 추가'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                    children: [
                      for (final group in MuscleGroup.values)
                        if (grouped[group] != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 14, 0, 8),
                            child: Row(
                              children: [
                                GroupDot(group: group),
                                const SizedBox(width: 8),
                                Text(
                                  group.label,
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                for (var i = 0; i < grouped[group]!.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      color: c.border,
                                      height: 1,
                                      indent: 14,
                                      endIndent: 14,
                                    ),
                                  _ExerciseTile(
                                    def: grouped[group]![i],
                                    onTap: () =>
                                        Navigator.of(context).pop(grouped[group]![i]),
                                    onDelete: grouped[group]![i].custom
                                        ? () => store.deleteCustomExercise(
                                              grouped[group]![i].id,
                                            )
                                        : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WorkoutStore store) async {
    final nameCtrl = TextEditingController();
    var group = MuscleGroup.chest;
    var tracking = TrackingType.weightReps;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: ctx.colors.surface,
          title: const Text('종목 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: TextStyle(color: ctx.colors.textPrimary),
                  decoration: const InputDecoration(labelText: '종목 이름'),
                ),
                const SizedBox(height: 16),
                Text(
                  '부위',
                  style: TextStyle(color: ctx.colors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: MuscleGroup.values
                      .map(
                        (g) => _FilterChip(
                          label: g.label,
                          color: g.color,
                          selected: group == g,
                          margin: EdgeInsets.zero,
                          onTap: () => setInner(() => group = g),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  '기록 방식',
                  style: TextStyle(color: ctx.colors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                SegmentedBar<TrackingType>(
                  values: TrackingType.values,
                  selected: tracking,
                  labelOf: (t) => switch (t) {
                    TrackingType.weightReps => '무게·횟수',
                    TrackingType.bodyweight => '맨몸',
                    TrackingType.cardio => '유산소',
                  },
                  onChanged: (t) => setInner(() => tracking = t),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await store.addCustomExercise(
                  name: nameCtrl.text,
                  group: group,
                  tracking: tracking,
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    if (created == true && mounted) setState(() {});
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.def, required this.onTap, this.onDelete});

  final ExerciseDef def;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final trackingLabel = switch (def.tracking) {
      TrackingType.weightReps => '무게 · 횟수',
      TrackingType.bodyweight => '맨몸',
      TrackingType.cardio => '시간 · 거리',
    };
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        def.name,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        trackingLabel,
        style: TextStyle(color: c.textFaint, fontSize: 11.5),
      ),
      trailing: onDelete == null
          ? Icon(Icons.add_rounded, size: 20, color: c.textFaint)
          : IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 19, color: c.textFaint),
              onPressed: onDelete,
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.margin = const EdgeInsets.only(right: 8),
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: margin,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : c.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? color : c.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : c.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
