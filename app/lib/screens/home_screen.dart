import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/workout_store.dart';
import '../theme/app_theme.dart';
import '../utils/date_x.dart';
import '../utils/stats.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/session_card.dart';
import 'session_editor_screen.dart';

/// 홈 — 오늘 상태, 이번 주 목표, 최근 기록 요약.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final c = context.colors;
    final stats = store.stats;
    final week = stats.summarize(stats.forRange(StatsRange.week));
    final streak = stats.currentStreak();
    final recent = store.sessions.take(3).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: [
          _Greeting(streak: streak),
          const SizedBox(height: 18),
          _WeeklyGoalCard(store: store),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '이번 주 볼륨',
                  value: compactNumber(week.totalVolume),
                  unit: 'kg',
                  icon: Icons.monitor_weight_outlined,
                  delta: stats.volumeChangePercent(StatsRange.week),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: '이번 주 세트',
                  value: '${week.totalSets}',
                  unit: '세트',
                  icon: Icons.repeat_rounded,
                  accent: c.positive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            title: '최근 14일 볼륨',
            subtitle: '하루 총 들어올린 무게',
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
            child: MiniBarChart(
              points: stats.dailyVolume(StatsRange.week).isEmpty
                  ? const []
                  : _last14(stats),
              height: 150,
            ),
          ),
          const SizedBox(height: 22),
          _TodayCard(store: store),
          const SizedBox(height: 22),
          SectionHeader(
            title: '최근 기록',
            subtitle: recent.isEmpty ? null : '${store.sessions.length}개의 운동 기록',
          ),
          if (recent.isEmpty)
            AppCard(
              child: EmptyState(
                icon: Icons.fitness_center_rounded,
                title: '아직 기록이 없어요',
                message: '아래 «운동 기록» 버튼으로 첫 운동을 남겨보세요.',
              ),
            )
          else
            ...recent.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SessionCard(
                  session: s,
                  catalog: store.catalog,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionEditorScreen(session: s),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 홈에서는 2주치만 보여준다.
  List<ChartPoint> _last14(StatsEngine stats) {
    final month = stats.dailyVolume(StatsRange.month);
    return month.sublist(month.length - 14);
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 6
        ? '새벽 운동이네요'
        : hour < 12
            ? '좋은 아침이에요'
            : hour < 18
                ? '오늘도 화이팅'
                : '오늘 하루 마무리해요';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDayKo(now),
                style: TextStyle(
                  color: c.textFaint,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                greeting,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        if (streak > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department_rounded,
                    size: 17, color: c.warning),
                const SizedBox(width: 5),
                Text(
                  '$streak일 연속',
                  style: TextStyle(
                    color: c.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({required this.store});

  final WorkoutStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = store.thisWeekCount;
    final goal = store.weeklyGoal;
    final remaining = (goal - done).clamp(0, goal);

    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            progress: store.weeklyGoalProgress,
            size: 88,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$done',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  '/ $goal',
                  style: TextStyle(color: c.textFaint, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이번 주 목표',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  remaining == 0
                      ? '목표를 모두 채웠어요! 👏'
                      : '$remaining번 더 하면 목표 달성이에요',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(7, (i) {
                    final day = startOfWeek(DateTime.now()).add(Duration(days: i));
                    final trained = store.sessionsOn(day).isNotEmpty;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(
                          children: [
                            Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: trained ? c.accent : c.surfaceAlt,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              kWeekdayShort[i],
                              style: TextStyle(
                                color: trained ? c.accent : c.textFaint,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 오늘 기록이 있으면 요약을, 없으면 지난 운동 반복 제안을 보여준다.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.store});

  final WorkoutStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = store.sessionsOn(DateTime.now());

    if (today.isNotEmpty) {
      final session = today.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '오늘의 운동'),
          SessionCard(
            session: session,
            catalog: store.catalog,
            showDate: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionEditorScreen(session: session),
              ),
            ),
          ),
        ],
      );
    }

    final last = store.latestSession;
    if (last == null) return const SizedBox.shrink();

    final groups = <MuscleGroup>{
      for (final e in last.exercises) store.catalog.byId(e.exerciseId).group,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '이어서 하기'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.replay_rounded, size: 20, color: c.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          last.title.isEmpty
                              ? groups.map((g) => g.label).join(' · ')
                              : last.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${formatRelativeKo(last.date)}에 한 운동 · ${last.exercises.length}종목',
                          style: TextStyle(color: c.textFaint, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final copy = await store.repeatSession(last);
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionEditorScreen(session: copy),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('같은 루틴으로 오늘 기록 만들기'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
