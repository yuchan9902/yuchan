import { useMemo } from 'react'
import { ActivityIcon, DumbbellIcon, FlameIcon, LayersIcon, TimerIcon } from 'lucide-react'
import { ChartCard } from '@/components/ChartCard'
import { StatTile } from '@/components/StatTile'
import { VolumeChart } from '@/components/charts/VolumeChart'
import { GroupVolumeBars } from '@/components/charts/GroupVolumeBars'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Table, TBody, TD, TH, THead, TR } from '@/components/ui/table'
import {
  currentStreak,
  delta,
  entryVolume,
  exerciseMap,
  filterByRange,
  longestStreak,
  totals,
  volumeBuckets,
  volumeByGroup,
  type Granularity,
} from '@/lib/stats'
import type { ResolvedRange } from '@/lib/range'
import type { Store } from '@/lib/types'
import { GROUP_COLOR, MUSCLE_GROUPS } from '@/lib/types'
import { compact, formatDateLabel, formatNumber } from '@/lib/utils'

export function Dashboard({ store, range }: { store: Store; range: ResolvedRange }) {
  const map = useMemo(() => exerciseMap(store.exercises), [store.exercises])

  // Under five weeks a weekly chart is one or two lonely bars, so bucket by day.
  const granularity: Granularity = range.days <= 35 ? 'day' : 'week'

  const view = useMemo(() => {
    const inRange = filterByRange(store.entries, range.from, range.to)
    const prev = filterByRange(store.entries, range.prevFrom, range.prevTo)
    const now = totals(inRange)
    const before = totals(prev)
    const buckets = volumeBuckets(inRange, map, range.from, range.to, granularity)
    const groups = volumeByGroup(inRange, map)
    const activeGroups = MUSCLE_GROUPS.filter((g) => groups.some((x) => x.group === g && x.volume > 0))

    const recent = [...inRange]
      .sort((a, b) => (a.date === b.date ? 0 : a.date < b.date ? 1 : -1))
      .slice(0, 8)

    return { inRange, now, before, buckets, groups, activeGroups, recent }
  }, [store.entries, map, range, granularity])

  const { now, before, buckets, groups, activeGroups, recent } = view
  const streak = currentStreak(store.entries)
  const best = longestStreak(store.entries)

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-6">
        <StatTile
          hero
          icon={<DumbbellIcon className="size-3.5" aria-hidden />}
          label="총 볼륨"
          value={compact(Math.round(now.volume))}
          unit="kg"
          delta={delta(now.volume, before.volume)}
        />
        <StatTile
          icon={<ActivityIcon className="size-3.5" aria-hidden />}
          label="운동한 날"
          value={formatNumber(now.sessions)}
          unit="일"
          delta={delta(now.sessions, before.sessions)}
        />
        <StatTile
          icon={<LayersIcon className="size-3.5" aria-hidden />}
          label="총 세트"
          value={formatNumber(now.sets)}
          unit="세트"
          delta={delta(now.sets, before.sets)}
        />
        <StatTile
          icon={<TimerIcon className="size-3.5" aria-hidden />}
          label="유산소"
          value={formatNumber(now.cardioMin)}
          unit="분"
          hint={now.cardioKm > 0 ? `누적 ${formatNumber(now.cardioKm, 1)}km` : '기록된 거리 없음'}
        />
        <StatTile
          icon={<FlameIcon className="size-3.5" aria-hidden />}
          label="연속 기록"
          value={formatNumber(streak)}
          unit="일"
          hint={`최장 ${best}일`}
        />
      </div>

      <ChartCard
        title={granularity === 'week' ? '주별 볼륨' : '일별 볼륨'}
        description={`${
          granularity === 'week' ? '한 주' : '하루'
        }에 들어올린 총 무게를 부위별로 쌓아서 보여줘요. 막대에 마우스를 올리면 부위별 수치가 나옵니다.`}
        chart={<VolumeChart buckets={buckets} groups={activeGroups} granularity={granularity} />}
        table={
          <Table>
            <THead>
              <TR>
                <TH>{granularity === 'week' ? '주 시작' : '날짜'}</TH>
                {granularity === 'week' ? <TH className="text-right">운동 횟수</TH> : null}
                {activeGroups.map((g) => (
                  <TH key={g} className="text-right">{g}</TH>
                ))}
                <TH className="text-right">합계 (kg)</TH>
              </TR>
            </THead>
            <TBody>
              {[...buckets]
                .reverse()
                .filter((b) => granularity === 'week' || b.total > 0 || b.sessions > 0)
                .map((b) => (
                  <TR key={b.key}>
                    <TD className="tnum">{formatDateLabel(b.key)}</TD>
                    {granularity === 'week' ? <TD className="tnum text-right">{b.sessions}</TD> : null}
                    {activeGroups.map((g) => (
                      <TD key={g} className="tnum text-muted-foreground text-right">
                        {b.byGroup[g] ? formatNumber(Math.round(b.byGroup[g])) : '—'}
                      </TD>
                    ))}
                    <TD className="tnum text-right font-medium">{formatNumber(Math.round(b.total))}</TD>
                  </TR>
                ))}
            </TBody>
          </Table>
        }
      />

      <div className="grid items-start gap-4 lg:grid-cols-2">
        <ChartCard
          title="부위별 분포"
          description="선택한 기간 동안 부위별로 나눈 볼륨 비중이에요."
          chart={<GroupVolumeBars data={groups} />}
          table={
            <Table>
              <THead>
                <TR>
                  <TH>부위</TH>
                  <TH className="text-right">볼륨 (kg)</TH>
                  <TH className="text-right">세트</TH>
                  <TH className="text-right">비중</TH>
                </TR>
              </THead>
              <TBody>
                {[...groups]
                  .sort((a, b) => b.volume - a.volume)
                  .map((g) => (
                    <TR key={g.group}>
                      <TD>
                        <span className="flex items-center gap-2">
                          <span
                            aria-hidden
                            className="size-2.5 rounded-[3px]"
                            style={{ background: GROUP_COLOR[g.group] }}
                          />
                          {g.group}
                        </span>
                      </TD>
                      <TD className="tnum text-right">{formatNumber(Math.round(g.volume))}</TD>
                      <TD className="tnum text-muted-foreground text-right">{g.sets}</TD>
                      <TD className="tnum text-right">{(g.share * 100).toFixed(1)}%</TD>
                    </TR>
                  ))}
              </TBody>
            </Table>
          }
        />

        <Card>
          <CardHeader>
            <div>
              <CardTitle>최근 기록</CardTitle>
              <CardDescription>가장 최근에 남긴 운동 8개예요.</CardDescription>
            </div>
          </CardHeader>
          <CardContent>
            {recent.length ? (
              <ul className="flex flex-col">
                {recent.map((entry, i) => {
                  const exercise = map.get(entry.exerciseId)
                  if (!exercise) return null
                  const volume = entryVolume(entry)
                  return (
                    <li
                      key={entry.id}
                      className={`flex items-center gap-3 py-2.5 ${i > 0 ? 'border-t' : ''}`}
                    >
                      <span
                        aria-hidden
                        className="size-2.5 shrink-0 rounded-[3px]"
                        style={{ background: GROUP_COLOR[exercise.group] }}
                      />
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-sm font-medium">{exercise.name}</div>
                        <div className="text-muted-foreground tnum text-xs">
                          {formatDateLabel(entry.date)} ·{' '}
                          {exercise.kind === 'cardio'
                            ? `${entry.durationMin}분${entry.distanceKm ? ` · ${entry.distanceKm}km` : ''}`
                            : `${entry.sets.length}세트`}
                        </div>
                      </div>
                      <Badge variant="secondary" className="tnum">
                        {volume > 0 ? `${compact(Math.round(volume))} kg` : exercise.group}
                      </Badge>
                    </li>
                  )
                })}
              </ul>
            ) : (
              <p className="text-muted-foreground py-8 text-center text-xs">
                이 기간에는 기록이 없어요. ‘기록’ 탭에서 첫 운동을 남겨보세요.
              </p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
