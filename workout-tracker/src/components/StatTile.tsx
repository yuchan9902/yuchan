import type { ReactNode } from 'react'
import { ArrowDownRightIcon, ArrowUpRightIcon, MinusIcon } from 'lucide-react'
import { Card } from '@/components/ui/card'
import { cn } from '@/lib/utils'

interface StatTileProps {
  label: string
  value: string
  unit?: string
  /** Signed fraction vs the comparison period; null when there is nothing to compare to. */
  delta?: number | null
  deltaLabel?: string
  hero?: boolean
  icon?: ReactNode
  hint?: string
}

export function StatTile({
  label,
  value,
  unit,
  delta,
  deltaLabel = '이전 기간 대비',
  hero = false,
  icon,
  hint,
}: StatTileProps) {
  return (
    <Card className={cn('gap-0 p-5', hero && 'col-span-2')}>
      <div className="text-muted-foreground flex items-center gap-2 text-xs font-medium">
        {icon}
        {label}
      </div>

      <div className="mt-2 flex items-baseline gap-1.5">
        {/* Proportional figures — tabular-nums makes a large number look loose. */}
        <span className={cn('font-semibold tracking-tight', hero ? 'text-4xl sm:text-5xl' : 'text-2xl')}>
          {value}
        </span>
        {unit ? <span className="text-muted-foreground text-sm font-medium">{unit}</span> : null}
      </div>

      {delta !== undefined || hint ? (
        <div className="mt-2.5 flex flex-wrap items-center gap-x-2 gap-y-1">
          {delta !== undefined ? <DeltaChip delta={delta} /> : null}
          <span className="text-muted-foreground text-[11px]">{hint ?? deltaLabel}</span>
        </div>
      ) : null}
    </Card>
  )
}

function DeltaChip({ delta }: { delta: number | null }) {
  if (delta === null) {
    return (
      <span className="text-muted-foreground inline-flex items-center gap-1 text-xs font-medium">
        <MinusIcon className="size-3.5" aria-hidden />
        비교 불가
      </span>
    )
  }

  const up = delta >= 0
  const Icon = up ? ArrowUpRightIcon : ArrowDownRightIcon
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 text-xs font-medium',
        // Icon + sign carry the direction; colour only reinforces it.
        up ? 'text-success' : 'text-destructive',
      )}
    >
      <Icon className="size-3.5" aria-hidden />
      {up ? '+' : ''}
      {(delta * 100).toFixed(1)}%
    </span>
  )
}
