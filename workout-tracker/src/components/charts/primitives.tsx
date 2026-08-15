import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
  type ReactNode,
  type RefObject,
} from 'react'
import { cn } from '@/lib/utils'

/** Charts render at real pixel width so text never scales with a viewBox. */
export function useMeasure<T extends HTMLElement>(): [RefObject<T | null>, number] {
  const ref = useRef<T>(null)
  const [width, setWidth] = useState(0)

  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const ro = new ResizeObserver(([entry]) => {
      setWidth(Math.round(entry.contentRect.width))
    })
    ro.observe(el)
    setWidth(Math.round(el.getBoundingClientRect().width))
    return () => ro.disconnect()
  }, [])

  return [ref, width]
}

export interface TooltipState {
  x: number
  y: number
  content: ReactNode
}

export function useTooltip() {
  const [tip, setTip] = useState<TooltipState | null>(null)
  const show = useCallback((x: number, y: number, content: ReactNode) => setTip({ x, y, content }), [])
  const hide = useCallback(() => setTip(null), [])
  return { tip, show, hide }
}

/**
 * Floating readout. Values lead, labels follow — the reader already knows the
 * series and wants the number.
 */
export function ChartTooltip({ tip, width }: { tip: TooltipState | null; width: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const [size, setSize] = useState({ w: 0, h: 0 })

  useEffect(() => {
    if (!ref.current) return
    const rect = ref.current.getBoundingClientRect()
    setSize({ w: rect.width, h: rect.height })
  }, [tip])

  if (!tip) return null

  const left = Math.max(4, Math.min(tip.x - size.w / 2, Math.max(4, width - size.w - 4)))
  const top = Math.max(4, tip.y - size.h - 12)

  return (
    <div
      ref={ref}
      role="status"
      aria-live="polite"
      style={{ left, top }}
      className="bg-popover text-popover-foreground pointer-events-none absolute z-20 min-w-[8rem] rounded-lg border p-2.5 text-xs shadow-md"
    >
      {tip.content}
    </div>
  )
}

export function TooltipHeading({ children }: { children: ReactNode }) {
  return <div className="text-muted-foreground mb-1.5 text-[11px] font-medium">{children}</div>
}

/** One tooltip row: a short stroke of the series colour, the name, then the value. */
export function TooltipRow({
  color,
  label,
  value,
}: {
  color?: string
  label: string
  value: string
}) {
  return (
    <div className="flex items-center gap-2 py-px">
      {color ? (
        <span
          aria-hidden
          className="h-0.5 w-3 shrink-0 rounded-full"
          style={{ background: color }}
        />
      ) : null}
      <span className="text-muted-foreground mr-auto">{label}</span>
      <span className="tnum text-foreground font-semibold">{value}</span>
    </div>
  )
}

export interface LegendItem {
  label: string
  color: string
}

/** Always present for two or more series — identity is never colour-alone. */
export function Legend({
  items,
  shape = 'rect',
  className,
}: {
  items: LegendItem[]
  shape?: 'rect' | 'line'
  className?: string
}) {
  return (
    <ul className={cn('flex flex-wrap items-center gap-x-4 gap-y-1.5', className)}>
      {items.map((item) => (
        <li key={item.label} className="text-muted-foreground flex items-center gap-1.5 text-xs">
          <span
            aria-hidden
            className={cn('shrink-0', shape === 'rect' ? 'size-2.5 rounded-[3px]' : 'h-0.5 w-3.5 rounded-full')}
            style={{ background: item.color }}
          />
          {item.label}
        </li>
      ))}
    </ul>
  )
}

/** Rounded data-end, square at the baseline. */
export function barPath(x: number, y: number, w: number, h: number, r = 4): string {
  if (h <= 0) return ''
  const rr = Math.max(0, Math.min(r, w / 2, h))
  return [
    `M${x},${y + h}`,
    `L${x},${y + rr}`,
    `Q${x},${y} ${x + rr},${y}`,
    `L${x + w - rr},${y}`,
    `Q${x + w},${y} ${x + w},${y + rr}`,
    `L${x + w},${y + h}`,
    'Z',
  ].join(' ')
}

/** Same shape rotated for horizontal bars: rounded right end, square at the axis. */
export function barPathH(x: number, y: number, w: number, h: number, r = 4): string {
  if (w <= 0) return ''
  const rr = Math.max(0, Math.min(r, h / 2, w))
  return [
    `M${x},${y}`,
    `L${x + w - rr},${y}`,
    `Q${x + w},${y} ${x + w},${y + rr}`,
    `L${x + w},${y + h - rr}`,
    `Q${x + w},${y + h} ${x + w - rr},${y + h}`,
    `L${x},${y + h}`,
    'Z',
  ].join(' ')
}

/** Clean axis ticks: 0 / 2,000 / 4,000 rather than 0 / 1,873 / 3,746. */
export function niceTicks(max: number, count = 4): number[] {
  if (max <= 0) return [0]
  const raw = max / count
  const mag = 10 ** Math.floor(Math.log10(raw))
  const norm = raw / mag
  const step = (norm >= 5 ? 10 : norm >= 2 ? 5 : norm >= 1 ? 2 : 1) * mag
  const ticks: number[] = []
  // Run past `max` so the top gridline always sits above the tallest mark —
  // otherwise the peak bar overflows the plot and its direct label lands off-canvas.
  for (let v = 0; v < max + step; v += step) ticks.push(Number(v.toFixed(6)))
  return ticks
}

export function EmptyPlot({ label = '이 기간에는 기록이 없어요.' }: { label?: string }) {
  return (
    <div className="text-muted-foreground flex h-40 items-center justify-center rounded-lg border border-dashed text-xs">
      {label}
    </div>
  )
}
