import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/workout_store.dart';
import '../theme/app_theme.dart';
import '../utils/date_x.dart';
import '../utils/stats.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// 통계 — 기간별 요약, 볼륨 추이, 부위 분포, 종목별 성장, 개인 기록.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsRange _range = StatsRange.month;
  String? _trendExerciseId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final c = context.colors;
    final stats = store.stats;

    final sessions = stats.forRange(_range);
    final summary = stats.summarize(sessions);
    final slices = stats.groupDistribution(_range);
    final change = stats.volumeChangePercent(_range);
    final records = stats.personalRecords();

    // 추이 차트에 쓸 종목: 사용자가 고른 것, 없으면 기록이 가장 많은 종목.
    final trendId = _trendExerciseId ?? _defaultTrendExercise(stats);
    final trend = trendId == null ? <ChartPoint>[] : stats.oneRepMaxTrend(trendId);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: [
          Text(
            '통계',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '기록이 쌓일수록 더 정확해져요',
            style: TextStyle(color: c.textFaint, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SegmentedBar<StatsRange>(
            values: StatsRange.values,
            selected: _range,
            labelOf: (r) => r.label,
            onChanged: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: 18),

          // ---------------------------------------------------------- 요약
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '총 볼륨',
                  value: compactNumber(summary.totalVolume),
                  unit: 'kg',
                  icon: Icons.monitor_weight_outlined,
                  delta: change,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: '운동 횟수',
                  value: '${summary.sessionCount}',
                  unit: '회',
                  icon: Icons.event_available_outlined,
                  accent: c.positive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '총 세트',
                  value: '${summary.totalSets}',
                  unit: '세트',
                  icon: Icons.repeat_rounded,
                  accent: MuscleGroup.back.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: '평균 운동 시간',
                  value: '${summary.avgMinutes}',
                  unit: '분',
                  icon: Icons.timer_outlined,
                  accent: c.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StreakCard(stats: stats),

          // ------------------------------------------------------ 볼륨 추이
          const SizedBox(height: 26),
          SectionHeader(
            title: '볼륨 추이',
            subtitle: _range == StatsRange.week || _range == StatsRange.month
                ? '일별 총 볼륨'
                : '주별 총 볼륨',
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
            child: MiniBarChart(
              points: _range == StatsRange.week || _range == StatsRange.month
                  ? stats.dailyVolume(_range)
                  : stats.weeklyVolume(weeks: _range == StatsRange.quarter ? 13 : 26),
              height: 170,
            ),
          ),

          // ------------------------------------------------------ 부위 분포
          const SizedBox(height: 26),
          const SectionHeader(
            title: '부위별 분포',
            subtitle: '어디에 힘을 쏟고 있는지',
          ),
          AppCard(
            child: slices.isEmpty
                ? EmptyState(
                    icon: Icons.donut_large_outlined,
                    title: '표시할 기록이 없어요',
                    message: '이 기간에 기록된 운동이 없습니다.',
                  )
                : Row(
                    children: [
                      DonutChart(
                        slices: slices,
                        size: 148,
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              slices.first.group.label,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${(slices.first.ratio * 100).round()}%',
                              style: TextStyle(
                                color: slices.first.group.color,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: slices
                              .take(6)
                              .map((s) => _LegendRow(slice: s))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
          ),

          // -------------------------------------------------- 종목별 1RM 추이
          const SizedBox(height: 26),
          SectionHeader(
            title: '종목별 성장',
            subtitle: '추정 1RM (Epley 공식)',
            action: trendId == null
                ? null
                : TextButton(
                    onPressed: () => _pickTrendExercise(context, store),
                    child: const Text('종목 변경'),
                  ),
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
            child: trendId == null
                ? EmptyState(
                    icon: Icons.show_chart_rounded,
                    title: '아직 추이를 그릴 수 없어요',
                    message: '웨이트 종목을 기록하면 성장 그래프가 나타납니다.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GroupDot(group: store.catalog.byId(trendId).group),
                          const SizedBox(width: 7),
                          Text(
                            store.catalog.byId(trendId).name,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (trend.length >= 2)
                            _TrendDelta(first: trend.first.value, last: trend.last.value),
                        ],
                      ),
                      const SizedBox(height: 6),
                      MiniLineChart(
                        points: trend,
                        height: 180,
                        color: store.catalog.byId(trendId).group.color,
                        valueFormatter: (v) => '${v.toStringAsFixed(1)}kg',
                      ),
                    ],
                  ),
          ),

          // ---------------------------------------------------- 요일별 패턴
          const SizedBox(height: 26),
          const SectionHeader(
            title: '요일별 운동 패턴',
            subtitle: '어느 요일에 주로 운동하는지',
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
            child: MiniBarChart(
              points: stats.byWeekday(_range),
              height: 130,
              labelEvery: 1,
              color: c.positive,
            ),
          ),

          // ------------------------------------------------------ 개인 기록
          const SizedBox(height: 26),
          SectionHeader(
            title: '개인 최고 기록',
            subtitle: records.isEmpty ? null : '추정 1RM 기준 상위 ${records.take(6).length}종목',
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: records.isEmpty
                ? EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: '아직 기록이 없어요',
                    message: '무게와 횟수를 기록하면 자동으로 계산됩니다.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < records.take(6).length; i++) ...[
                        if (i > 0) Divider(color: c.border, height: 1),
                        _RecordRow(record: records[i], rank: i + 1),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 기록이 가장 많은 웨이트 종목을 기본 추이 대상으로 고른다.
  String? _defaultTrendExercise(StatsEngine stats) {
    final counts = <String, int>{};
    for (final s in stats.sessions) {
      for (final e in s.exercises) {
        if (stats.catalog.byId(e.exerciseId).tracking == TrackingType.cardio) {
          continue;
        }
        if (e.best1rm <= 0) continue;
        counts[e.exerciseId] = (counts[e.exerciseId] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  Future<void> _pickTrendExercise(BuildContext context, WorkoutStore store) async {
    // 기록이 2회 이상 있는 종목만 보여준다 — 추이가 그려지는 것만.
    final counts = <String, int>{};
    for (final s in store.sessions) {
      for (final e in s.exercises) {
        if (e.best1rm <= 0) continue;
        counts[e.exerciseId] = (counts[e.exerciseId] ?? 0) + 1;
      }
    }
    final ids = counts.entries.where((e) => e.value >= 1).map((e) => e.key).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                '추이를 볼 종목',
                style: TextStyle(
                  color: ctx.colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...ids.map((id) {
              final def = store.catalog.byId(id);
              return ListTile(
                leading: GroupDot(group: def.group, size: 10),
                title: Text(
                  def.name,
                  style: TextStyle(color: ctx.colors.textPrimary),
                ),
                trailing: Text(
                  '${counts[id]}회',
                  style: TextStyle(color: ctx.colors.textFaint, fontSize: 12),
                ),
                onTap: () => Navigator.of(ctx).pop(id),
              );
            }),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _trendExerciseId = picked);
    }
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stats});

  final StatsEngine stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = stats.currentStreak();
    final longest = stats.longestStreak();
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.local_fire_department_rounded,
                color: c.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '연속 기록',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  current > 0 ? '$current일 연속 운동 중' : '연속 기록이 끊겼어요',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '최고 $longest일',
                style: TextStyle(
                  color: c.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text('개인 최장', style: TextStyle(color: c.textFaint, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice});

  final GroupSlice slice;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GroupDot(group: slice.group),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.group.label,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${(slice.ratio * 100).round()}%',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendDelta extends StatelessWidget {
  const _TrendDelta({required this.first, required this.last});

  final double first;
  final double last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final diff = last - first;
    final up = diff >= 0;
    final color = up ? c.positive : c.negative;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${up ? '+' : ''}${diff.toStringAsFixed(1)}kg',
        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.rank});

  final PersonalRecord record;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank <= 3 ? c.warning : c.textFaint,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '최고 ${formatWeight(record.topWeight)}kg · ${formatRelativeKo(record.date)}',
                  style: TextStyle(color: c.textFaint, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record.best1rm.toStringAsFixed(1)}kg',
                style: TextStyle(
                  color: record.exercise.group.color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('추정 1RM', style: TextStyle(color: c.textFaint, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}
