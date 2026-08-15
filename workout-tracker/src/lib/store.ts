import { useCallback, useSyncExternalStore } from 'react'
import { DEFAULT_EXERCISES } from './catalog'
import { buildSeedEntries } from './seed'
import type { Entry, Exercise, Store } from './types'
import { MUSCLE_GROUPS } from './types'

const KEY = 'fitlog.store.v1'

const listeners = new Set<() => void>()
let state: Store = load()

function emptyStore(): Store {
  return { exercises: DEFAULT_EXERCISES, entries: [] }
}

function isMuscleGroup(v: unknown): v is Exercise['group'] {
  return typeof v === 'string' && (MUSCLE_GROUPS as readonly string[]).includes(v)
}

/** Persisted JSON is user-editable, so validate rather than trust the shape. */
function sanitize(raw: unknown): Store | null {
  if (!raw || typeof raw !== 'object') return null
  const obj = raw as Partial<Store>
  if (!Array.isArray(obj.exercises) || !Array.isArray(obj.entries)) return null

  const exercises: Exercise[] = obj.exercises
    .filter((e): e is Exercise =>
      !!e && typeof e.id === 'string' && typeof e.name === 'string' && isMuscleGroup(e.group))
    .map((e) => ({
      id: e.id,
      name: e.name,
      group: e.group,
      kind: e.kind === 'cardio' ? 'cardio' : 'strength',
    }))

  const ids = new Set(exercises.map((e) => e.id))
  const entries: Entry[] = obj.entries
    .filter((e): e is Entry =>
      !!e && typeof e.id === 'string' && typeof e.date === 'string' && ids.has(e.exerciseId))
    .map((e) => ({
      id: e.id,
      date: e.date,
      exerciseId: e.exerciseId,
      sets: Array.isArray(e.sets)
        ? e.sets
            .filter((s) => s && Number.isFinite(s.weight) && Number.isFinite(s.reps))
            .map((s) => ({ weight: Math.max(0, s.weight), reps: Math.max(0, Math.round(s.reps)) }))
        : [],
      durationMin: Number.isFinite(e.durationMin) ? Math.max(0, e.durationMin) : 0,
      distanceKm: Number.isFinite(e.distanceKm) ? Math.max(0, e.distanceKm) : 0,
      note: typeof e.note === 'string' ? e.note : '',
    }))

  return exercises.length ? { exercises, entries } : null
}

function load(): Store {
  if (typeof window === 'undefined') return emptyStore()
  try {
    const raw = window.localStorage.getItem(KEY)
    if (raw) {
      const parsed = sanitize(JSON.parse(raw))
      if (parsed) return parsed
    }
  } catch {
    // Corrupt payload — fall through to a fresh seeded store.
  }
  const fresh: Store = { exercises: DEFAULT_EXERCISES, entries: buildSeedEntries() }
  persist(fresh)
  return fresh
}

function persist(next: Store) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(next))
  } catch {
    // Quota or private mode — the session still works, it just will not survive a reload.
  }
}

function set(updater: (prev: Store) => Store) {
  state = updater(state)
  persist(state)
  listeners.forEach((l) => l())
}

function subscribe(l: () => void) {
  listeners.add(l)
  return () => listeners.delete(l)
}

export function useStore(): Store {
  return useSyncExternalStore(subscribe, () => state, () => state)
}

export function useStoreActions() {
  const addEntry = useCallback((entry: Entry) => {
    set((prev) => ({ ...prev, entries: [...prev.entries, entry] }))
  }, [])

  const updateEntry = useCallback((entry: Entry) => {
    set((prev) => ({
      ...prev,
      entries: prev.entries.map((e) => (e.id === entry.id ? entry : e)),
    }))
  }, [])

  const removeEntry = useCallback((id: string) => {
    set((prev) => ({ ...prev, entries: prev.entries.filter((e) => e.id !== id) }))
  }, [])

  const addExercise = useCallback((exercise: Exercise) => {
    set((prev) =>
      prev.exercises.some((e) => e.id === exercise.id)
        ? prev
        : { ...prev, exercises: [...prev.exercises, exercise] })
  }, [])

  const resetToDemo = useCallback(() => {
    set(() => ({ exercises: DEFAULT_EXERCISES, entries: buildSeedEntries() }))
  }, [])

  const clearAll = useCallback(() => {
    set(() => emptyStore())
  }, [])

  const exportJSON = useCallback(() => JSON.stringify(state, null, 2), [])

  const importJSON = useCallback((text: string) => {
    const parsed = sanitize(JSON.parse(text))
    if (!parsed) throw new Error('알아볼 수 없는 백업 파일이에요.')
    set(() => parsed)
  }, [])

  return { addEntry, updateEntry, removeEntry, addExercise, resetToDemo, clearAll, exportJSON, importJSON }
}
