import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/date_x.dart';

/// 월간 캘린더. 운동한 날은 볼륨에 비례한 농도로 칠한다.
class CalendarMonth extends StatelessWidget {
  const CalendarMonth({
    super.key,
    required this.month,
    required this.volumeByDay,
    required this.selectedDay,
    required this.onSelect,
  });

  /// 표시할 달(일자는 무시된다).
  final DateTime month;
  final Map<DateTime, double> volumeByDay;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = DateTime(month.year, month.month, 1);
    final total = daysInMonth(month.year, month.month);
    // 월요일 시작 기준으로 앞쪽 빈칸 수.
    final leading = first.weekday - DateTime.monday;
    final today = dateOnly(DateTime.now());

    final maxVolume = volumeByDay.values.fold(0.0, (m, v) => v > m ? v : m);

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= total; day++) {
      final date = DateTime(month.year, month.month, day);
      final volume = volumeByDay[date] ?? 0;
      final isSelected = isSameDay(date, selectedDay);
      final isToday = isSameDay(date, today);
      final isFuture = date.isAfter(today);

      // 0.18 ~ 1.0 사이로 농도를 매핑해서 적은 볼륨도 눈에 보이게 한다.
      final intensity = maxVolume <= 0 || volume <= 0
          ? 0.0
          : 0.18 + 0.82 * (volume / maxVolume).clamp(0.0, 1.0);

      cells.add(
        GestureDetector(
          onTap: () => onSelect(date),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: intensity > 0
                    ? c.accent.withValues(alpha: intensity)
                    : c.surfaceAlt.withValues(alpha: isFuture ? 0.4 : 1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? c.textPrimary
                      : isToday
                          ? c.accent
                          : Colors.transparent,
                  width: isSelected ? 2 : 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: intensity > 0 ? FontWeight.w800 : FontWeight.w500,
                  color: intensity > 0.45
                      ? Colors.white
                      : isFuture
                          ? c.textFaint.withValues(alpha: 0.6)
                          : c.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: kWeekdayShort
              .map(
                (w) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: w == '일'
                            ? c.negative.withValues(alpha: 0.75)
                            : c.textFaint,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: cells,
        ),
      ],
    );
  }
}
