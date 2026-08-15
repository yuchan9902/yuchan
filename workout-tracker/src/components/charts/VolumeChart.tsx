import { Fragment } from 'react'
import type { Granularity, VolumeBucket } from '@/lib/stats'
import type { MuscleGroup } from '@/lib/types'
import { GROUP_COLOR } from '@/lib/types'
import { compact, formatDateLabel, formatNumber } from '@/lib/utils'
import {
  ChartTooltip,
  EmptyPlot,
  Legend,
  TooltipHeading,
  TooltipRow,
  barPath,
  niceTicks,
  useMeasure,
  useTooltip,
} from './primitives'

const PLOT_H = 190
const AXIS_H = 22
const PAD_L = 46
const PAD_R = 8
const PAD_T = 16
const GAP = 2 // surface gap between stacked segments
const MAX_BAR = 24

interface Props {
  buckets: VolumeBucket[]
  groups: MuscleGroup[]
  granularity: Granularity
}

export function VolumeChart({ buckets, groups, granularity }: Props) {
  const [ref, width] = useMeasure<HTMLDivElement>()
  const { tip, show, hide } = useTooltip()

  if (!buckets.length) return <EmptyPlot />

  const height = PLOT_H + AXIS_H + PAD_T
  const plotW = Math.max(0, width - PAD_L - PAD_R)
  const max = Math.max(...buckets.map((b) => b.total), 0)
  const ticks = niceTicks(max)
  const top = Math.max(ticks[ticks.length - 1] ?? 0, 1)
  const y = (v: number) => PAD_T + PLOT_H - (v / top) * PLOT_H
  const band = plotW / buckets.length
  const barW = Math.max(2, Math.min(MAX_BAR, band - 6))

  const peak = buckets.reduce((best, b) => (b.total > best.total ? b : best), buckets[0])
  // Thin the x labels until they stop colliding (≈44px each).
  const every = Math.max(1, Math.ceil(buckets.length / Math.max(1, Math.floor(plotW / 44))))

  return (
    <div>
      <div ref={ref} className="relative w-full">
        {width > 0 ? (
          <svg
            width={width}
            height={height}
            role="img"
            aria-label={`${granularity === 'week' ? '주별' : '일별'} 총 볼륨(부위별 누적)`}
          >
            {ticks.map((t) => (
              <Fragment key={t}>
                <line
                  x1={PAD_L}
                  x2={width - PAD_R}
                  y1={y(t)}
                  y2={y(t)}
                  className={t === 0 ? 'stroke-axis' : 'stroke-grid'}
                  strokeWidth={1}
                  shapeRendering="crispEdges"
                />
                <text
                  x={PAD_L - 8}
                  y={y(t) + 3}
                  textAnchor="end"
                  className="tnum fill-muted-foreground text-[10px]"
                >
                  {compact(t)}
                </text>
              </Fragment>
            ))}

            {buckets.map((bucket, i) => {
              const x = PAD_L + band * i + (band - barW) / 2
              let cum = 0
              const stack = groups
                .map((g) => {
                  const v = bucket.byGroup[g]
                  if (v <= 0) return null
                  const yTop = y(cum + v)
                  const yBottom = y(cum) - (cum > 0 ? GAP : 0)
                  cum += v
                  return { group: g, value: v, yTop, h: yBottom - yTop }
                })
                .filter((s): s is NonNullable<typeof s> => !!s && s.h > 0.5)

              const lastIndex = stack.length - 1
              const isPeak = bucket.key === peak.key && bucket.total > 0

              return (
                <g key={bucket.key}>
                  {stack.map((seg, si) => (
                    <path
                      key={seg.group}
                      d={barPath(x, seg.yTop, barW, seg.h, si === lastIndex ? 4 : 0)}
                      fill={GROUP_COLOR[seg.group]}
                    />
                  ))}

                  {isPeak ? (
                    <text
                      x={x + barW / 2}
                      y={y(bucket.total) - 6}
                      textAnchor="middle"
                      className="tnum fill-foreground text-[10px] font-semibold"
                    >
                      {compact(Math.round(bucket.total))}
                    </text>
                  ) : null}

                  {i % every === 0 ? (
                    <text
                      x={x + barW / 2}
                      y={PAD_T + PLOT_H + 14}
                      textAnchor="middle"
                      className="tnum fill-muted-foreground text-[10px]"
                    >
                      {bucket.label}
                    </text>
                  ) : null}

                  {/* Hit target spans the whole band, not just the painted bar. */}
                  <rect
                    x={PAD_L + band * i}
                    y={PAD_T}
                    width={band}
                    height={PLOT_H}
                    fill="transparent"
                    tabIndex={0}
                    role="button"
                    aria-label={`${formatDateLabel(bucket.key)} 총 볼륨 ${formatNumber(Math.round(bucket.total))}kg`}
                    className="hover:fill-foreground/5 focus-visible:fill-foreground/5 outline-none"
                    onPointerMove={(e) => {
                      const rect = e.currentTarget.ownerSVGElement!.getBoundingClientRect()
                      show(
                        PAD_L + band * i + band / 2,
                        Math.max(PAD_T + 8, e.clientY - rect.top),
                        <Readout bucket={bucket} groups={groups} granularity={granularity} />,
                      )
                    }}
                    onPointerLeave={hide}
                    onFocus={() =>
                      show(
                        PAD_L + band * i + band / 2,
                        y(bucket.total),
                        <Readout bucket={bucket} groups={groups} granularity={granularity} />,
                      )}
                    onBlur={hide}
                  />
                </g>
              )
            })}
          </svg>
        ) : (
          <div style={{ height }} />
        )}
        <ChartTooltip tip={tip} width={width} />
      </div>

      <Legend className="mt-3 pl-1" items={groups.map((g) => ({ label: g, color: GROUP_COLOR[g] }))} />
    </div>
  )
}

function Readout({
  bucket,
  groups,
  granularity,
}: {
  bucket: VolumeBucket
  groups: MuscleGroup[]
  granularity: Granularity
}) {
  const active = groups.filter((g) => bucket.byGroup[g] > 0)
  return (
    <div className="min-w-[10rem]">
      <TooltipHeading>
        {formatDateLabel(bucket.key)}
        {granularity === 'week' ? ` 주 · ${bucket.sessions}회 운동` : ''}
      </TooltipHeading>
      <TooltipRow label="총 볼륨" value={`${formatNumber(Math.round(bucket.total))} kg`} />
      {active.length ? <div className="bg-border my-1.5 h-px" /> : null}
      {active.map((g) => (
        <TooltipRow
          key={g}
          color={GROUP_COLOR[g]}
          label={g}
          value={`${formatNumber(Math.round(bucket.byGroup[g]))} kg`}
        />
      ))}
    </div>
  )
}
