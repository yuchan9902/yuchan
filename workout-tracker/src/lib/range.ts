import type { Entry } from './types'
import { addDays, toISODate } from './utils'

export const RANGE_KEYS = ['7d', '30d', '90d', '180d', 'all'] as const
export type RangeKey = (typeof RANGE_KEYS)[number]

export const RANGE_LABEL: Record<RangeKey, string> = {
  '7d': '최근 7일',
  '30d': '최근 30일',
  '90d': '최근 90일',
  '180d': '최근 6개월',
  all: '전체',
}

const RANGE_DAYS: Record<Exclude<RangeKey, 'all'>, number> = {
  '7d': 7,
  '30d': 30,
  '90d': 90,
  '180d': 180,
}

export interface ResolvedRange {
  from: string
  to: string
  /** The equally long window immediately before, for period-over-period deltas. */
  prevFrom: string
  prevTo: string
  days: number
}

export function resolveRange(key: RangeKey, entries: Entry[], today = new Date()): ResolvedRange {
  const to = toISODate(today)

  if (key === 'all') {
    const earliest = entries.reduce<string | null>(
      (min, e) => (min === null || e.date < min ? e.date : min),
      null,
    )
    const from = earliest ?? toISODate(addDays(today, -29))
    const days = Math.max(
      1,
      Math.round((today.getTime() - new Date(`${from}T00:00:00`).getTime()) / 86_400_000) + 1,
    )
    return {
      from,
      to,
      prevFrom: toISODate(addDays(new Date(`${from}T00:00:00`), -days)),
      prevTo: toISODate(addDays(new Date(`${from}T00:00:00`), -1)),
      days,
    }
  }

  const days = RANGE_DAYS[key]
  const start = addDays(today, -(days - 1))
  return {
    from: toISODate(start),
    to,
    prevFrom: toISODate(addDays(start, -days)),
    prevTo: toISODate(addDays(start, -1)),
    days,
  }
}
