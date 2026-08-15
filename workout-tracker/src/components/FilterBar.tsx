import type { ReactNode } from 'react'
import { CalendarRangeIcon } from 'lucide-react'
import { Tabs } from '@/components/ui/tabs'
import { RANGE_KEYS, RANGE_LABEL, type RangeKey } from '@/lib/range'

/**
 * One filter row, above everything it scopes — every card below re-renders
 * against the same slice, so the numbers always agree.
 */
export function FilterBar({
  range,
  onRangeChange,
  children,
}: {
  range: RangeKey
  onRangeChange: (key: RangeKey) => void
  children?: ReactNode
}) {
  return (
    <div className="flex flex-wrap items-center gap-3">
      <span className="text-muted-foreground inline-flex items-center gap-1.5 text-xs font-medium">
        <CalendarRangeIcon className="size-3.5" aria-hidden />
        기간
      </span>
      <div className="max-w-full overflow-x-auto">
        <Tabs
          aria-label="기간 선택"
          value={range}
          onChange={onRangeChange}
          items={RANGE_KEYS.map((key) => ({ value: key, label: RANGE_LABEL[key] }))}
        />
      </div>
      {children}
    </div>
  )
}
