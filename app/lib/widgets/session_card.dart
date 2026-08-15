import 'package:flutter/material.dart';

import '../data/exercise_catalog.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/date_x.dart';
import 'common.dart';

/// 목록에 쓰이는 세션 요약 카드.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.catalog,
    this.onTap,
    this.showDate = true,
  });

  final WorkoutSession session;
  final ExerciseCatalog catalog;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = <MuscleGroup>{
      for (final e in session.exercises) catalog.byId(e.exerciseId).group,
    }.toList();
    final title = session.title.isNotEmpty
        ? session.title
        : groups.map((g) => g.label).join(' · ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? '운동 기록' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showDate) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${formatRelativeKo(session.date)} · ${formatDuration(session.durationMin)}',
                        style: TextStyle(color: c.textFaint, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                value: compactNumber(session.totalVolume),
                unit: 'kg',
                label: '볼륨',
              ),
              _Divider(),
              _Metric(value: '${session.totalSets}', unit: '세트', label: '세트'),
              _Divider(),
              _Metric(
                value: '${session.exercises.length}',
                unit: '종목',
                label: '종목',
              ),
            ],
          ),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: groups.map((g) => GroupChip(group: g, dense: true)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.unit, required this.label});

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: c.textFaint,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: context.colors.border,
    );
  }
}
