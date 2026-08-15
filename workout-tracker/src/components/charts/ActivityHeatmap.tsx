import { useMemo } from 'react'
import type { DayCell } from '@/lib/stats'
import { addDays, formatDateLabel, formatNumber, parseISODate, startOfWeek, toISODate, WEEKDAY_KO } from '@/lib/utils'
import { ChartTooltip, TooltipHeading, TooltipRow, useMeasure, useTooltip } from './primitives'

const LEVELS = ['var(--heat-1)', 'var(--heat-2)', 'var(--heat-3)', 'var(--heat-4)', 'var(--heat-5)']
const EMPTY = 'hsl(var(--heat-0))'
const CELL = 13
const GAP = 3

/**
 * Sequential encoding: one hue, light → dark (flipped for the dark surface).
 * Every cell is also reachable as a value through the tooltip and the log table.
 */
export function ActivityHeatmap({
  activity,
  from,
  to,
}: {
  activity: Map<string, DayCell>
  from: string
  to: string
}) {
  const [ref, width] = useMeasure<HTMLDivElement>()
  const { tip, show, hide } = useTooltip()

  const { weeks, thresholds } = useMemo(() => {
    const start = startOfWeek(parseISODate(from))
    const end = parseISODate(to)
    const cols: string[][] = []
    for (let d = start; d <= end; d = addDays(d, 7)) {
      cols.push(Array.from({ length: 7 }, (_, i) => toISODate(addDays(d, i))))
    }

    const volumes = [...activity.values()].map((c) => c.volume).filter((v) => v > 0).sort((a, b) => a - b)
    const q = (p: number) => volumes[Math.min(volumes.length - 1, Math.floor(volumes.length * p))] ?? 0
    return { weeks: cols, thresholds: [q(0.2), q(0.4), q(0.6), q(0.8)] }
  }, [activity, from, to])

  function level(volume: number, entries: number): number {
    if (!entries) return -1
    if (volume <= 0) return 0 // bodyweight / cardio-only day: still a training day
    return thresholds.findIndex((t) => volume <= t) === -1 ? 4 : thresholds.findIndex((t) => volume <= t)
  }

  const monthMarks: { index: number; label: string }[] = []
  let lastMonth = -1
  weeks.forEach((week, i) => {
    const d = parseISODate(week[0])
    if (d.getMonth() !== lastMonth) {
      lastMonth = d.getMonth()
      monthMarks.push({ index: i, label: `${d.getMonth() + 1}월` })
    }
  })

  const gridW = weeks.length * (CELL + GAP)

  return (
    <div>
      <div ref={ref} className="relative w-full overflow-x-auto pb-1">
        <div style={{ width: Math.max(gridW + 26, width ? width - 1 : 0) }}>
          <div className="flex" style={{ paddingLeft: 26 }}>
            {monthMarks.map((m, i) => (
              <span
                key={`${m.label}-${m.index}`}
                className="text-muted-foreground text-[10px]"
                style={{
                  position: 'absolute',
                  left: 26 + m.index * (CELL + GAP),
                  visibility: i > 0 && m.index - monthMarks[i - 1].index < 2 ? 'hidden' : 'visible',
                }}
              >
                {m.label}
              </span>
            ))}
            <span className="h-4" />
          </div>

          <div className="mt-3.5 flex gap-1">
            <div className="flex flex-col justify-between" style={{ width: 22, height: 7 * CELL + 6 * GAP }}>
              {WEEKDAY_KO.map((d, i) => (
                <span key={d} className="text-muted-foreground text-[10px] leading-none" style={{ height: CELL }}>
                  {i % 2 === 0 ? d : ''}
                </span>
              ))}
            </div>

            <div className="flex" style={{ gap: GAP }}>
              {weeks.map((week) => (
                <div key={week[0]} className="flex flex-col" style={{ gap: GAP }}>
                  {week.map((date) => {
                    const cell = activity.get(date)
                    const inRange = date >= from && date <= to
                    const lv = cell ? level(cell.volume, cell.entries) : -1
                    return (
                      <button
                        key={date}
                        type="button"
                        aria-label={
                          cell
                            ? `${formatDateLabel(date)} 볼륨 ${formatNumber(Math.round(cell.volume))}kg, ${cell.sets}세트`
                            : `${formatDateLabel(date)} 기록 없음`
                        }
                        className="rounded-[3px] outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50"
                        style={{
                          width: CELL,
                          height: CELL,
                          background: lv < 0 ? EMPTY : LEVELS[lv],
                          opacity: inRange ? 1 : 0.25,
                          cursor: cell ? 'pointer' : 'default',
                        }}
                        onPointerEnter={(e) => {
                          const box = ref.current?.getBoundingClientRect()
                          if (!box) return
                          const r = e.currentTarget.getBoundingClientRect()
                          show(
                            r.left - box.left + CELL / 2,
                            r.top - box.top + (ref.current?.scrollTop ?? 0),
                            <div className="min-w-[9rem]">
                              <TooltipHeading>{formatDateLabel(date)}</TooltipHeading>
                              {cell ? (
                                <>
                                  <TooltipRow
                                    color="var(--chart-1)"
                                    label="볼륨"
                                    value={`${formatNumber(Math.round(cell.volume))} kg`}
                                  />
                                  <TooltipRow label="세트" value={`${cell.sets}세트`} />
                                  <TooltipRow label="운동" value={`${cell.entries}종목`} />
                                </>
                              ) : (
                                <div className="text-muted-foreground">휴식일</div>
                              )}
                            </div>,
                          )
                        }}
                        onPointerLeave={hide}
                      />
                    )
                  })}
                </div>
              ))}
            </div>
          </div>
        </div>
        <ChartTooltip tip={tip} width={width} />
      </div>

      <div className="text-muted-foreground mt-3 flex items-center gap-1.5 text-[11px]">
        <span className="mr-0.5">적음</span>
        <span className="size-3 rounded-[3px]" style={{ background: EMPTY }} />
        {LEVELS.map((c) => (
          <span key={c} className="size-3 rounded-[3px]" style={{ background: c }} />
        ))}
        <span className="ml-0.5">많음</span>
        <span className="ml-2">세션당 총 볼륨 기준</span>
      </div>
    </div>
  )
}
