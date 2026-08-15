import { Fragment, useId, useState } from 'react'
import type { ProgressPoint } from '@/lib/stats'
import { formatDateLabel, formatNumber, parseISODate } from '@/lib/utils'
import {
  ChartTooltip,
  EmptyPlot,
  TooltipHeading,
  TooltipRow,
  niceTicks,
  useMeasure,
  useTooltip,
} from './primitives'

const PLOT_H = 200
const AXIS_H = 22
const PAD_L = 42
const PAD_R = 12
const PAD_T = 18

/**
 * One series, so no legend box — the card title says what is plotted. A crosshair
 * finds the nearest session, so the reader aims at a date, not at a 2px line.
 */
export function ProgressLineChart({
  points,
  color = 'var(--chart-1)',
  unit = 'kg',
}: {
  points: ProgressPoint[]
  color?: string
  unit?: string
}) {
  const [ref, width] = useMeasure<HTMLDivElement>()
  const { tip, show, hide } = useTooltip()
  const [hover, setHover] = useState<number | null>(null)
  const gradientId = useId()

  if (points.length < 2) {
    return <EmptyPlot label="추이를 그리려면 이 운동의 기록이 최소 2회 필요해요." />
  }

  const height = PAD_T + PLOT_H + AXIS_H
  const plotW = Math.max(1, width - PAD_L - PAD_R)
  const times = points.map((p) => parseISODate(p.date).getTime())
  const t0 = times[0]
  const t1 = times[times.length - 1]
  const span = Math.max(1, t1 - t0)

  const values = points.map((p) => p.oneRM)
  const rawMin = Math.min(...values)
  const rawMax = Math.max(...values)
  // A 1RM chart that starts at zero flattens the progress it exists to show,
  // so the band is padded around the data and the axis is labelled accordingly.
  const pad = Math.max(2, (rawMax - rawMin) * 0.25)
  const lo = Math.max(0, Math.floor((rawMin - pad) / 5) * 5)
  const hi = Math.ceil((rawMax + pad) / 5) * 5
  const ticks = niceTicks(hi - lo, 3).map((t) => t + lo).filter((t) => t <= hi)

  const x = (i: number) => PAD_L + ((times[i] - t0) / span) * plotW
  const y = (v: number) => PAD_T + PLOT_H - ((v - lo) / Math.max(1, hi - lo)) * PLOT_H

  const line = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(2)},${y(p.oneRM).toFixed(2)}`).join(' ')
  const area = `${line} L${x(points.length - 1).toFixed(2)},${PAD_T + PLOT_H} L${x(0).toFixed(2)},${PAD_T + PLOT_H} Z`

  const last = points[points.length - 1]
  const bestIndex = values.indexOf(rawMax)

  function locate(clientX: number, svg: SVGSVGElement) {
    const rect = svg.getBoundingClientRect()
    const px = clientX - rect.left
    let nearest = 0
    let dist = Infinity
    for (let i = 0; i < points.length; i++) {
      const d = Math.abs(x(i) - px)
      if (d < dist) {
        dist = d
        nearest = i
      }
    }
    return nearest
  }

  function reveal(i: number) {
    const p = points[i]
    setHover(i)
    show(
      x(i),
      y(p.oneRM),
      <div className="min-w-[10rem]">
        <TooltipHeading>{formatDateLabel(p.date)}</TooltipHeading>
        <TooltipRow color={color} label="추정 1RM" value={`${formatNumber(p.oneRM, 1)} ${unit}`} />
        <TooltipRow label="최고 중량" value={`${formatNumber(p.topWeight, 1)} ${unit}`} />
        <TooltipRow label="세션 볼륨" value={`${formatNumber(Math.round(p.volume))} kg`} />
      </div>,
    )
  }

  function dismiss() {
    setHover(null)
    hide()
  }

  return (
    <div ref={ref} className="relative w-full">
      {width > 0 ? (
        <svg
          width={width}
          height={height}
          role="img"
          aria-label="세션별 추정 1RM 추이"
          onPointerMove={(e) => reveal(locate(e.clientX, e.currentTarget))}
          onPointerLeave={dismiss}
        >
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={color} stopOpacity={0.16} />
              <stop offset="100%" stopColor={color} stopOpacity={0.02} />
            </linearGradient>
          </defs>

          {ticks.map((t) => (
            <Fragment key={t}>
              <line
                x1={PAD_L}
                x2={width - PAD_R}
                y1={y(t)}
                y2={y(t)}
                className="stroke-grid"
                strokeWidth={1}
                shapeRendering="crispEdges"
              />
              <text
                x={PAD_L - 8}
                y={y(t) + 3}
                textAnchor="end"
                className="tnum fill-muted-foreground text-[10px]"
              >
                {formatNumber(t)}
              </text>
            </Fragment>
          ))}

          <path d={area} fill={`url(#${gradientId})`} />
          <path d={line} fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />

          {/* Crosshair snapped to the nearest session */}
          {hover !== null ? (
            <line
              x1={x(hover)}
              x2={x(hover)}
              y1={PAD_T}
              y2={PAD_T + PLOT_H}
              className="stroke-axis"
              strokeWidth={1}
              shapeRendering="crispEdges"
            />
          ) : null}

          {/* The peak and the latest session get a marker; every other point stays quiet. */}
          {[bestIndex, points.length - 1, hover].map((i, n) =>
            i === null || i === undefined ? null : (
              <circle
                key={`${n}-${i}`}
                cx={x(i)}
                cy={y(points[i].oneRM)}
                r={4}
                fill={color}
                className="stroke-card"
                strokeWidth={2}
              />
            ))}

          <text
            x={Math.min(width - 4, x(points.length - 1) + 8)}
            y={y(last.oneRM) - 10}
            textAnchor="end"
            className="tnum fill-foreground text-[11px] font-semibold"
          >
            {formatNumber(last.oneRM, 1)} {unit}
          </text>

          <text x={PAD_L} y={PAD_T + PLOT_H + 14} className="tnum fill-muted-foreground text-[10px]">
            {formatDateLabel(points[0].date)}
          </text>
          <text
            x={width - PAD_R}
            y={PAD_T + PLOT_H + 14}
            textAnchor="end"
            className="tnum fill-muted-foreground text-[10px]"
          >
            {formatDateLabel(last.date)}
          </text>

          {/* Keyboard parity with hover */}
          {points.map((p, i) => (
            <rect
              key={p.date}
              x={x(i) - 12}
              y={PAD_T}
              width={24}
              height={PLOT_H}
              fill="transparent"
              tabIndex={0}
              role="button"
              aria-label={`${formatDateLabel(p.date)} 추정 1RM ${formatNumber(p.oneRM, 1)}${unit}`}
              className="outline-none"
              onFocus={() => reveal(i)}
              onBlur={dismiss}
            />
          ))}
        </svg>
      ) : (
        <div style={{ height }} />
      )}
      <ChartTooltip tip={tip} width={width} />
    </div>
  )
}
