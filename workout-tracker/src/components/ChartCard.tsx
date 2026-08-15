import { useState, type ReactNode } from 'react'
import { BarChart3Icon, TableIcon } from 'lucide-react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { cn } from '@/lib/utils'

interface ChartCardProps {
  title: string
  description?: string
  chart: ReactNode
  /** The WCAG-clean twin. Tooltips enhance; the table is what guarantees access. */
  table?: ReactNode
  action?: ReactNode
  className?: string
}

export function ChartCard({ title, description, chart, table, action, className }: ChartCardProps) {
  const [view, setView] = useState<'chart' | 'table'>('chart')

  return (
    <Card className={className}>
      <CardHeader>
        <div className="min-w-0">
          <CardTitle>{title}</CardTitle>
          {description ? <CardDescription>{description}</CardDescription> : null}
        </div>
        <div className="flex items-center gap-2">
          {action}
          {table ? (
            <div className="bg-muted inline-flex h-8 items-center rounded-lg p-0.5">
              <ViewToggle
                active={view === 'chart'}
                label="차트로 보기"
                onClick={() => setView('chart')}
              >
                <BarChart3Icon aria-hidden />
              </ViewToggle>
              <ViewToggle
                active={view === 'table'}
                label="표로 보기"
                onClick={() => setView('table')}
              >
                <TableIcon aria-hidden />
              </ViewToggle>
            </div>
          ) : null}
        </div>
      </CardHeader>
      <CardContent className="flex-1">{view === 'chart' || !table ? chart : table}</CardContent>
    </Card>
  )
}

function ViewToggle({
  active,
  label,
  onClick,
  children,
}: {
  active: boolean
  label: string
  onClick: () => void
  children: ReactNode
}) {
  return (
    <button
      type="button"
      aria-label={label}
      aria-pressed={active}
      title={label}
      onClick={onClick}
      className={cn(
        'inline-flex size-7 items-center justify-center rounded-md transition-colors',
        'focus-visible:ring-ring/50 focus-visible:ring-[3px] focus-visible:outline-none',
        '[&_svg]:size-3.5',
        active ? 'bg-background text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground',
      )}
    >
      {children}
    </button>
  )
}
