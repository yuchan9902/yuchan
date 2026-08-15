import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/workout_store.dart';
import '../theme/app_theme.dart';
import '../utils/date_x.dart';
import '../widgets/common.dart';

/// 설정 — 주간 목표, 테마, 데이터 관리.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkoutStore>();
    final c = context.colors;
    final stats = store.stats;
    final all = stats.summarize(store.sessions);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
        children: [
          Text(
            '설정',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: '전체 기록'),
          AppCard(
            child: Row(
              children: [
                _LifetimeMetric(
                  label: '총 운동',
                  value: '${all.sessionCount}',
                  unit: '회',
                ),
                _LifetimeMetric(
                  label: '누적 볼륨',
                  value: compactNumber(all.totalVolume),
                  unit: 'kg',
                ),
                _LifetimeMetric(
                  label: '누적 시간',
                  value: (all.totalMinutes / 60).toStringAsFixed(0),
                  unit: '시간',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeader(
            title: '주간 목표',
            subtitle: '한 주에 몇 번 운동할까요?',
          ),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '주 ${store.weeklyGoal}회',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '이번 주 ${store.thisWeekCount}회 완료',
                      style: TextStyle(color: c.textFaint, fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Slider(
                  value: store.weeklyGoal.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  activeColor: c.accent,
                  inactiveColor: c.surfaceAlt,
                  label: '주 ${store.weeklyGoal}회',
                  onChanged: (v) => store.setWeeklyGoal(v.round()),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: '화면'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: SwitchListTile(
              value: store.darkMode,
              onChanged: store.setDarkMode,
              activeThumbColor: c.accent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              title: Text(
                '다크 모드',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                store.darkMode ? '어두운 화면으로 표시합니다' : '밝은 화면으로 표시합니다',
                style: TextStyle(color: c.textFaint, fontSize: 12),
              ),
              secondary: Icon(
                store.darkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: c.accent,
              ),
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: '데이터'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.auto_awesome_rounded,
                  color: c.accent,
                  title: '예시 데이터 다시 넣기',
                  subtitle: '10주치 샘플 기록으로 통계 화면을 살펴봐요',
                  onTap: () async {
                    final ok = await _confirm(
                      context,
                      title: '예시 데이터를 넣을까요?',
                      message: '지금 저장된 기록은 모두 예시 데이터로 대체됩니다.',
                      confirmLabel: '넣기',
                    );
                    if (!ok) return;
                    await store.restoreSampleData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('예시 데이터를 채웠어요')),
                      );
                    }
                  },
                ),
                Divider(color: c.border, height: 1, indent: 14, endIndent: 14),
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  color: c.negative,
                  title: '모든 기록 삭제',
                  subtitle: '되돌릴 수 없어요',
                  onTap: () async {
                    final ok = await _confirm(
                      context,
                      title: '모든 기록을 삭제할까요?',
                      message: '저장된 운동 기록이 전부 사라집니다.',
                      confirmLabel: '삭제',
                      destructive: true,
                    );
                    if (!ok) return;
                    await store.clearAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('모든 기록을 삭제했어요')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),
          Center(
            child: Column(
              children: [
                Text(
                  '핏로그 1.0.0',
                  style: TextStyle(
                    color: c.textFaint,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '기록은 기기 안에만 저장됩니다',
                  style: TextStyle(color: c.textFaint, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.surface,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor:
                  destructive ? ctx.colors.negative : ctx.colors.accent,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _LifetimeMetric extends StatelessWidget {
  const _LifetimeMetric({
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
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: c.textFaint, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 20),
    );
  }
}
