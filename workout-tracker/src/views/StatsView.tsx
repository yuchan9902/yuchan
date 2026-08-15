import { useMemo } from 'react'
import { ChartCard } from '@/components/ChartCard'
import { ProgressLineChart } from '@/components/charts/ProgressLineChart'
import { ActivityHeatmap } from '@/components/charts/ActivityHeatmap'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Table, TBody, TD, TH, THead, TR } from '@/components/ui/table'
import {
  dailyActivity,
  exerciseMap,
  filterByRange,
  oneRMSeries,
  personalRecords,
} from '@/lib/stats'
import type { ResolvedRange } from '@/lib/range'
import type { Store } from '@/lib/types'
import { GROUP_COLOR } from '@/lib/types'
import { formatDateLabel, formatNumber } from '@/lib/utils'

export function StatsView({
  store,
  range,
  exerciseId,
}: {
  store: Store
  range: ResolvedRange
  exerciseId: string
}) {
  const map = useMemo(() => exerciseMap(store.exercises), [store.exercises])
  const exercise = map.get(exerciseId)

  const { series, activity, records, activeDays } = useMemo(() => {
    const inRange = filterByRange(store.entries, range.from, range.to)
    return {
      series: oneRMSeries(inRange, exerciseId),
      activity: dailyActivity(inRange),
      records: personalRecords(inRange, map),
      activeDays: new Set(inRange.map((e) => e.date)).size,
    }
  }, [store.entries, map, range, exerciseId])

  const first = series[0]
  const last = series[series.length - 1]
  const gain = first && last && first.oneRM > 0 ? (last.oneRM - first.oneRM) / first.oneRM : null

  return (
    <div className="flex flex-col gap-4">
      <ChartCard
        title={`${exercise?.name ?? '운동'} — 추정 1RM 추이`}
        description="세트마다 Epley 공식(무게 × (1 + 횟수/30))으로 계산한 1회 최대 중량 중 그 날의 최고값이에요. 12회를 넘는 세트는 추정이 부정확해 제외합니다."
        action={
          gain !== null ? (
            <Badge variant="secondary" className="tnum">
              기간 내 {gain >= 0 ? '+' : ''}
              {(gain * 100).toFixed(1)}%
            </Badge>
          ) : null
        }
        chart={
          <ProgressLineChart
            points={series}
            color={exercise ? GROUP_COLOR[exercise.group] : 'var(--chart-1)'}
          />
        }
        table={
          <Table>
            <THead>
              <TR>
                <TH>날짜</TH>
                <TH className="text-right">추정 1RM (kg)</TH>
                <TH className="text-right">최고 중량 (kg)</TH>
                <TH className="text-right">세션 볼륨 (kg)</TH>
              </TR>
            </THead>
            <TBody>
              {[...series].reverse().map((p) => (
                <TR key={p.date}>
                  <TD className="tnum">{formatDateLabel(p.date)}</TD>
                  <TD className="tnum text-right font-medium">{formatNumber(p.oneRM, 1)}</TD>
                  <TD className="tnum text-muted-foreground text-right">{formatNumber(p.topWeight, 1)}</TD>
                  <TD className="tnum text-muted-foreground text-right">
                    {formatNumber(Math.round(p.volume))}
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
        }
      />

      <ChartCard
        title="운동 달력"
        description={`선택한 기간 중 ${activeDays}일 운동했어요. 색이 진할수록 그 날의 볼륨이 큽니다.`}
        chart={<ActivityHeatmap activity={activity} from={range.from} to={range.to} />}
        table={
          <Table>
            <THead>
              <TR>
                <TH>날짜</TH>
                <TH className="text-right">볼륨 (kg)</TH>
                <TH className="text-right">세트</TH>
                <TH className="text-right">종목 수</TH>
              </TR>
            </THead>
            <TBody>
              {[...activity.values()]
                .sort((a, b) => b.date.localeCompare(a.date))
                .map((cell) => (
                  <TR key={cell.date}>
                    <TD className="tnum">{formatDateLabel(cell.date)}</TD>
                    <TD className="tnum text-right font-medium">{formatNumber(Math.round(cell.volume))}</TD>
                    <TD className="tnum text-muted-foreground text-right">{cell.sets}</TD>
                    <TD className="tnum text-muted-foreground text-right">{cell.entries}</TD>
                  </TR>
                ))}
            </TBody>
          </Table>
        }
      />

      <Card>
        <CardHeader>
          <div>
            <CardTitle>개인 기록 (PR)</CardTitle>
            <CardDescription>
              선택한 기간 안에서 종목별 최고 추정 1RM이에요. 추정치가 높은 순서로 정렬됩니다.
            </CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          {records.length ? (
            <Table>
              <THead>
                <TR>
                  <TH>종목</TH>
                  <TH className="text-right">추정 1RM (kg)</TH>
                  <TH className="text-right">최고 세트</TH>
                  <TH className="text-right">달성일</TH>
                  <TH className="text-right">세션</TH>
                </TR>
              </THead>
              <TBody>
                {records.map((pr) => (
                  <TR key={pr.exercise.id} className={pr.exercise.id === exerciseId ? 'bg-muted/40' : ''}>
                    <TD>
                      <span className="flex items-center gap-2">
                        <span
                          aria-hidden
                          className="size-2.5 rounded-[3px]"
                          style={{ background: GROUP_COLOR[pr.exercise.group] }}
                        />
                        {pr.exercise.name}
                        <span className="text-muted-foreground text-xs">{pr.exercise.group}</span>
                      </span>
                    </TD>
                    <TD className="tnum text-right font-medium">{formatNumber(pr.oneRM, 1)}</TD>
                    <TD className="tnum text-muted-foreground text-right">
                      {formatNumber(pr.weight, 1)}kg × {pr.reps}
                    </TD>
                    <TD className="tnum text-muted-foreground text-right">{formatDateLabel(pr.date)}</TD>
                    <TD className="tnum text-muted-foreground text-right">{pr.sessions}</TD>
                  </TR>
                ))}
              </TBody>
            </Table>
          ) : (
            <p className="text-muted-foreground py-8 text-center text-xs">
              이 기간에는 1RM을 계산할 수 있는 근력 기록이 없어요.
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
