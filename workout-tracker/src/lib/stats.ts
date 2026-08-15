import type { Entry, Exercise, MuscleGroup } from './types'
import { MUSCLE_GROUPS } from './types'
import { addDays, daysBetween, parseISODate, startOfWeek, toISODate } from './utils'

export type ExerciseMap = Map<string, Exercise>

export function exerciseMap(exercises: Exercise[]): ExerciseMap {
  return new Map(exercises.map((e) => [e.id, e]))
}

/** Tonnage: Σ weight × reps. Bodyweight sets contribute 0 kg but still count as sets. */
export function entryVolume(entry: Entry): number {
  return entry.sets.reduce((sum, s) => sum + s.weight * s.reps, 0)
}

/** Epley estimated one-rep max. Above ~12 reps the formula stops being meaningful. */
export function estimatedOneRM(weight: number, reps: number): number {
  if (weight <= 0 || reps <= 0 || reps > 12) return 0
  return weight * (1 + reps / 30)
}

export function entryBestOneRM(entry: Entry): number {
  return entry.sets.reduce((best, s) => Math.max(best, estimatedOneRM(s.weight, s.reps)), 0)
}

export function filterByRange(entries: Entry[], from: string, to: string): Entry[] {
  return entries.filter((e) => e.date >= from && e.date <= to)
}

export interface Totals {
  volume: number
  sets: number
  reps: number
  sessions: number
  cardioMin: number
  cardioKm: number
}

export function totals(entries: Entry[]): Totals {
  const days = new Set<string>()
  let volume = 0
  let sets = 0
  let reps = 0
  let cardioMin = 0
  let cardioKm = 0

  for (const e of entries) {
    days.add(e.date)
    volume += entryVolume(e)
    sets += e.sets.length
    reps += e.sets.reduce((s, x) => s + x.reps, 0)
    cardioMin += e.durationMin
    cardioKm += e.distanceKm
  }

  return { volume, sets, reps, sessions: days.size, cardioMin, cardioKm }
}

/** Consecutive days with at least one entry, counting back from `today`. */
export function currentStreak(entries: Entry[], today = new Date()): number {
  const days = new Set(entries.map((e) => e.date))
  if (!days.size) return 0
  // A rest day today does not break a streak that is still alive as of yesterday.
  let cursor = days.has(toISODate(today)) ? today : addDays(today, -1)
  let streak = 0
  while (days.has(toISODate(cursor))) {
    streak++
    cursor = addDays(cursor, -1)
  }
  return streak
}

export function longestStreak(entries: Entry[]): number {
  const days = [...new Set(entries.map((e) => e.date))].sort()
  let best = 0
  let run = 0
  let prev: Date | null = null
  for (const iso of days) {
    const d = parseISODate(iso)
    run = prev && daysBetween(prev, d) === 1 ? run + 1 : 1
    best = Math.max(best, run)
    prev = d
  }
  return best
}

export type Granularity = 'day' | 'week'

export interface VolumeBucket {
  /** ISO date the bucket opens on — the day itself, or the Monday of the week */
  key: string
  label: string
  total: number
  byGroup: Record<MuscleGroup, number>
  sessions: number
}

const zeroGroups = (): Record<MuscleGroup, number> =>
  Object.fromEntries(MUSCLE_GROUPS.map((g) => [g, 0])) as Record<MuscleGroup, number>

/**
 * Short ranges bucket by day and long ones by week — a 7-day range charted
 * weekly is one lonely bar, which is not a chart.
 */
export function volumeBuckets(
  entries: Entry[],
  map: ExerciseMap,
  from: string,
  to: string,
  granularity: Granularity,
): VolumeBucket[] {
  const byWeek = granularity === 'week'
  const step = byWeek ? 7 : 1
  const bucketKey = (iso: string) => (byWeek ? toISODate(startOfWeek(parseISODate(iso))) : iso)

  const buckets = new Map<string, VolumeBucket>()
  const first = byWeek ? startOfWeek(parseISODate(from)) : parseISODate(from)
  const last = parseISODate(to)

  for (let d = first; d <= last; d = addDays(d, step)) {
    buckets.set(toISODate(d), {
      key: toISODate(d),
      label: `${d.getMonth() + 1}/${d.getDate()}`,
      total: 0,
      byGroup: zeroGroups(),
      sessions: 0,
    })
  }

  const sessionDays = new Map<string, Set<string>>()

  for (const e of entries) {
    const key = bucketKey(e.date)
    const bucket = buckets.get(key)
    if (!bucket) continue
    const group = map.get(e.exerciseId)?.group
    const vol = entryVolume(e)
    bucket.total += vol
    if (group) bucket.byGroup[group] += vol
    if (!sessionDays.has(key)) sessionDays.set(key, new Set())
    sessionDays.get(key)!.add(e.date)
  }

  for (const [key, days] of sessionDays) {
    const bucket = buckets.get(key)
    if (bucket) bucket.sessions = days.size
  }

  return [...buckets.values()]
}

export interface GroupTotal {
  group: MuscleGroup
  volume: number
  sets: number
  share: number
}

export function volumeByGroup(entries: Entry[], map: ExerciseMap): GroupTotal[] {
  const volume = zeroGroups()
  const sets = zeroGroups()
  for (const e of entries) {
    const group = map.get(e.exerciseId)?.group
    if (!group) continue
    volume[group] += entryVolume(e)
    sets[group] += e.sets.length
  }
  const grand = MUSCLE_GROUPS.reduce((s, g) => s + volume[g], 0)
  return MUSCLE_GROUPS
    .map((group) => ({
      group,
      volume: volume[group],
      sets: sets[group],
      share: grand ? volume[group] / grand : 0,
    }))
    .filter((g) => g.volume > 0 || g.sets > 0)
}

export interface DayCell {
  date: string
  volume: number
  sets: number
  entries: number
}

export function dailyActivity(entries: Entry[]): Map<string, DayCell> {
  const map = new Map<string, DayCell>()
  for (const e of entries) {
    const cell = map.get(e.date) ?? { date: e.date, volume: 0, sets: 0, entries: 0 }
    cell.volume += entryVolume(e)
    cell.sets += e.sets.length
    cell.entries += 1
    map.set(e.date, cell)
  }
  return map
}

export interface ProgressPoint {
  date: string
  oneRM: number
  topWeight: number
  volume: number
}

/** Best estimated 1RM per session for one exercise, oldest first. */
export function oneRMSeries(entries: Entry[], exerciseId: string): ProgressPoint[] {
  const byDate = new Map<string, ProgressPoint>()
  for (const e of entries) {
    if (e.exerciseId !== exerciseId) continue
    const oneRM = entryBestOneRM(e)
    if (!oneRM) continue
    const top = e.sets.reduce((m, s) => Math.max(m, s.weight), 0)
    const prev = byDate.get(e.date)
    byDate.set(e.date, {
      date: e.date,
      oneRM: Math.max(prev?.oneRM ?? 0, oneRM),
      topWeight: Math.max(prev?.topWeight ?? 0, top),
      volume: (prev?.volume ?? 0) + entryVolume(e),
    })
  }
  return [...byDate.values()].sort((a, b) => a.date.localeCompare(b.date))
}

export interface PersonalRecord {
  exercise: Exercise
  oneRM: number
  weight: number
  reps: number
  date: string
  sessions: number
}

export function personalRecords(entries: Entry[], map: ExerciseMap): PersonalRecord[] {
  const best = new Map<string, PersonalRecord>()
  const sessions = new Map<string, Set<string>>()

  for (const e of entries) {
    const exercise = map.get(e.exerciseId)
    if (!exercise || exercise.kind === 'cardio') continue

    if (!sessions.has(e.exerciseId)) sessions.set(e.exerciseId, new Set())
    sessions.get(e.exerciseId)!.add(e.date)

    for (const s of e.sets) {
      const oneRM = estimatedOneRM(s.weight, s.reps)
      if (!oneRM) continue
      const prev = best.get(e.exerciseId)
      if (!prev || oneRM > prev.oneRM) {
        best.set(e.exerciseId, {
          exercise,
          oneRM,
          weight: s.weight,
          reps: s.reps,
          date: e.date,
          sessions: 0,
        })
      }
    }
  }

  return [...best.values()]
    .map((pr) => ({ ...pr, sessions: sessions.get(pr.exercise.id)?.size ?? 0 }))
    .sort((a, b) => b.oneRM - a.oneRM)
}

/** Percentage change, guarding the divide-by-zero case a fresh log always hits. */
export function delta(current: number, previous: number): number | null {
  if (!previous) return null
  return (current - previous) / previous
}
