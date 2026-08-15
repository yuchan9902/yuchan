import { DEFAULT_EXERCISES } from './catalog'
import type { Entry } from './types'
import { addDays, toISODate, uid } from './utils'

function mulberry32(seed: number) {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

interface Slot {
  exerciseId: string
  baseWeight: number
  reps: [number, number]
  sets: number
}

/** A weekday-indexed split (0 = Monday). Missing days are rest days. */
const SPLIT: Record<number, Slot[]> = {
  0: [
    { exerciseId: 'bench-press', baseWeight: 60, reps: [5, 8], sets: 4 },
    { exerciseId: 'incline-db-press', baseWeight: 22, reps: [8, 12], sets: 3 },
    { exerciseId: 'chest-fly', baseWeight: 15, reps: [12, 15], sets: 3 },
    { exerciseId: 'triceps-pushdown', baseWeight: 25, reps: [10, 14], sets: 3 },
  ],
  1: [
    { exerciseId: 'deadlift', baseWeight: 90, reps: [3, 6], sets: 4 },
    { exerciseId: 'barbell-row', baseWeight: 50, reps: [8, 10], sets: 4 },
    { exerciseId: 'lat-pulldown', baseWeight: 45, reps: [10, 12], sets: 3 },
    { exerciseId: 'barbell-curl', baseWeight: 25, reps: [8, 12], sets: 3 },
  ],
  3: [
    { exerciseId: 'squat', baseWeight: 75, reps: [5, 8], sets: 5 },
    { exerciseId: 'romanian-deadlift', baseWeight: 60, reps: [8, 10], sets: 3 },
    { exerciseId: 'leg-press', baseWeight: 130, reps: [10, 14], sets: 3 },
    { exerciseId: 'leg-curl', baseWeight: 35, reps: [12, 15], sets: 3 },
  ],
  4: [
    { exerciseId: 'overhead-press', baseWeight: 35, reps: [6, 9], sets: 4 },
    { exerciseId: 'lateral-raise', baseWeight: 9, reps: [12, 15], sets: 4 },
    { exerciseId: 'face-pull', baseWeight: 20, reps: [12, 15], sets: 3 },
    { exerciseId: 'hanging-leg-raise', baseWeight: 0, reps: [10, 14], sets: 3 },
    { exerciseId: 'cable-crunch', baseWeight: 30, reps: [12, 15], sets: 3 },
  ],
  5: [{ exerciseId: 'running', baseWeight: 0, reps: [0, 0], sets: 0 }],
}

const CARDIO_POOL = ['running', 'cycling', 'rowing-machine', 'jump-rope']

/**
 * ~6 months of a 5-day split with a slow progressive overload and the odd
 * missed session, so every chart in the app has something honest to show.
 */
export function buildSeedEntries(today = new Date(), weeks = 26): Entry[] {
  const rand = mulberry32(20260815)
  const entries: Entry[] = []
  const start = addDays(today, -(weeks * 7 - 1))
  const known = new Set(DEFAULT_EXERCISES.map((e) => e.id))

  for (let day = 0; day < weeks * 7; day++) {
    const date = addDays(start, day)
    const weekday = (date.getDay() + 6) % 7
    const slots = SPLIT[weekday]
    if (!slots) continue
    // Life happens: skip roughly one session in eight.
    if (rand() < 0.12) continue

    const progress = 1 + (day / (weeks * 7)) * 0.22 // ~22% stronger across the span

    for (const slot of slots) {
      if (!known.has(slot.exerciseId)) continue

      if (slot.sets === 0) {
        const id = CARDIO_POOL[Math.floor(rand() * CARDIO_POOL.length)]
        const minutes = Math.round(25 + rand() * 25)
        entries.push({
          id: uid(),
          date: toISODate(date),
          exerciseId: id,
          sets: [],
          durationMin: minutes,
          distanceKm: id === 'running' || id === 'cycling'
            ? Number((minutes * (id === 'cycling' ? 0.33 : 0.16)).toFixed(1))
            : 0,
          note: '',
        })
        continue
      }

      const top = Math.max(0, Math.round((slot.baseWeight * progress) / 2.5) * 2.5)
      const sets = Array.from({ length: slot.sets }, (_, i) => {
        const [lo, hi] = slot.reps
        const reps = Math.round(lo + rand() * (hi - lo)) - (i > 1 ? 1 : 0)
        const drop = i === 0 ? 0 : Math.round(rand()) * 2.5
        return { weight: Math.max(0, top - drop), reps: Math.max(1, reps) }
      })

      entries.push({
        id: uid(),
        date: toISODate(date),
        exerciseId: slot.exerciseId,
        sets,
        durationMin: 0,
        distanceKm: 0,
        note: '',
      })
    }
  }

  return entries
}
