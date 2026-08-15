import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/workout_store.dart';
import '../theme/app_theme.dart';
import '../utils/date_x.dart';
import '../widgets/calendar_month.dart';
import '../widgets/common.dart';
import '../widgets/session_card.dart';
import 'session_editor_screen.dart';

/// 기록 — 월간 캘린더에서 날짜를 골라 그날의 세션을 본다.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _month = startOfMonth(DateTime.now());
  DateTime _selected = dateOnly(DateTime.now());

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final c = context.colors;
    final volumeByDay = store.stats.volumeByDay();
    final daySessions = store.sessionsOn(_selected);

    final monthEnd = DateTime(_month.year, _month.month,
        daysInMonth(_month.year, _month.month));
    final monthSessions = store.stats.inRange(_month, monthEnd);
    final monthSummary = store.stats.summarize(monthSessions);
    final trainedDays =
        monthSessions.map((s) => dateOnly(s.date)).toSet().length;

    final isCurrentMonth = _month.year == DateTime.now().year &&
        _month.month == DateTime.now().month;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatMonthKo(_month),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              _RoundIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _shiftMonth(-1),
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: isCurrentMonth ? null : () => _shiftMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              children: [
                CalendarMonth(
                  month: _month,
                  volumeByDay: volumeByDay,
                  selectedDay: _selected,
                  onSelect: (d) => setState(() => _selected = d),
                ),
                const SizedBox(height: 14),
                Divider(color: c.border, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MonthMetric(
                      label: '운동한 날',
                      value: '$trainedDays',
                      unit: '일',
                    ),
                    _MonthMetric(
                      label: '총 볼륨',
                      value: compactNumber(monthSummary.totalVolume),
                      unit: 'kg',
                    ),
                    _MonthMetric(
                      label: '총 시간',
                      value: (monthSummary.totalMinutes / 60).toStringAsFixed(1),
                      unit: '시간',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: formatDayKo(_selected),
            subtitle: daySessions.isEmpty
                ? '기록이 없는 날이에요'
                : '${daySessions.length}개의 세션',
          ),
          if (daySessions.isEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: EmptyState(
                icon: Icons.event_available_outlined,
                title: '이 날은 쉬었어요',
                message: '이 날짜로 기록을 추가할 수 있어요.',
                action: FilledButton.icon(
                  onPressed: () async {
                    final draft = store.draftSession(date: _selected);
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SessionEditorScreen(session: draft, isNew: true),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('${formatShort(_selected)} 기록 추가'),
                ),
              ),
            )
          else
            ...daySessions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Dismissible(
                  key: ValueKey(s.id),
                  direction: DismissDirection.endToStart,
                  background: _DeleteBackground(),
                  confirmDismiss: (_) => _confirmDelete(context, s),
                  onDismissed: (_) => store.deleteSession(s.id),
                  child: SessionCard(
                    session: s,
                    catalog: store.catalog,
                    showDate: false,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionEditorScreen(session: s),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WorkoutSession s) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: const Text('기록을 삭제할까요?'),
        content: Text('${formatDayKo(s.date)}의 기록이 사라집니다.'),
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? c.textPrimary : c.textFaint.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _MonthMetric extends StatelessWidget {
  const _MonthMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: c.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: c.textFaint, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        color: c.negative.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(Icons.delete_outline_rounded, color: c.negative),
    );
  }
}
