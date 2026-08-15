/// 날짜 헬퍼. intl 패키지 없이 한국어 표기를 직접 만든다.
library;

const List<String> kWeekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

/// 시각을 버리고 날짜만 남긴다. 세션 저장/비교의 기준.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 그 주의 월요일.
DateTime startOfWeek(DateTime d) {
  final day = dateOnly(d);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime startOfYear(DateTime d) => DateTime(d.year, 1, 1);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// 두 날짜 사이의 일수 차이(달력 기준).
int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

String weekdayLabel(DateTime d) => kWeekdayShort[d.weekday - 1];

/// "8월 15일 (토)"
String formatDayKo(DateTime d) => '${d.month}월 ${d.day}일 (${weekdayLabel(d)})';

/// "2026년 8월"
String formatMonthKo(DateTime d) => '${d.year}년 ${d.month}월';

/// "8/15"
String formatShort(DateTime d) => '${d.month}/${d.day}';

/// 오늘/어제를 사람이 읽는 말로 바꾼다.
String formatRelativeKo(DateTime d, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = daysBetween(d, today);
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  if (diff == 2) return '그저께';
  if (diff > 0 && diff < 7) return '$diff일 전';
  return formatDayKo(d);
}

/// 분 단위를 "1시간 20분" 형태로.
String formatDuration(int minutes) {
  if (minutes <= 0) return '-';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m분';
  if (m == 0) return '$h시간';
  return '$h시간 $m분';
}

/// 볼륨처럼 큰 수를 짧게. 12,340 -> "12.3k"
String compactNumber(num value) {
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value.abs() >= 10000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return formatThousands(value);
}

String formatThousands(num value) {
  final rounded = value.round();
  final s = rounded.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buf';
}

/// 무게 표기: 60.0 -> "60", 62.5 -> "62.5"
String formatWeight(double w) {
  if (w == w.roundToDouble()) return w.round().toString();
  return w.toStringAsFixed(1);
}
