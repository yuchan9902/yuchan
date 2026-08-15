import type { GroupTotal } from '@/lib/stats'
import { GROUP_COLOR } from '@/lib/types'
import { formatNumber } from '@/lib/utils'
import { EmptyPlot } from './primitives'

/**
 * Horizontal bars, one colour per muscle group (identity, not rank). Every value
 * is direct-labelled outside the bar end — the relief the light-mode palette
 * requires, and it means no label can ever be clipped by a short bar.
 */
export function GroupVolumeBars({ data }: { data: GroupTotal[] }) {
  if (!data.length) return <EmptyPlot />

  const max = Math.max(...data.map((d) => d.volume), 1)
  const sorted = [...data].sort((a, b) => b.volume - a.volume)

  return (
    <ul className="flex h-full flex-col justify-center gap-4">
      {sorted.map((row) => (
        <li key={row.group} className="grid grid-cols-[3.25rem_1fr_auto] items-center gap-3">
          <span className="text-muted-foreground flex items-center gap-1.5 text-xs">
            <span
              aria-hidden
              className="size-2.5 shrink-0 rounded-[3px]"
              style={{ background: GROUP_COLOR[row.group] }}
            />
            {row.group}
          </span>
          <span className="bg-muted relative block h-2.5 overflow-hidden rounded-full">
            <span
              className="absolute inset-y-0 left-0 rounded-full transition-[width] duration-300"
              style={{
                width: `${Math.max(row.volume > 0 ? 1.5 : 0, (row.volume / max) * 100)}%`,
                background: GROUP_COLOR[row.group],
              }}
            />
          </span>
          <span className="tnum text-foreground text-xs font-medium">
            {formatNumber(Math.round(row.volume))}
            <span className="text-muted-foreground ml-1 font-normal">
              kg · {(row.share * 100).toFixed(0)}%
            </span>
          </span>
        </li>
      ))}
    </ul>
  )
}
