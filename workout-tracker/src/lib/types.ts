export const MUSCLE_GROUPS = ['가슴', '등', '하체', '어깨', '팔', '코어', '유산소'] as const

export type MuscleGroup = (typeof MUSCLE_GROUPS)[number]

/**
 * Colour follows the entity, never its rank: a group keeps its slot whatever the
 * filter leaves on screen. Slot order is the CVD-safety mechanism — do not reorder.
 */
export const GROUP_COLOR: Record<MuscleGroup, string> = {
  가슴: 'var(--chart-1)',
  등: 'var(--chart-2)',
  하체: 'var(--chart-3)',
  어깨: 'var(--chart-4)',
  팔: 'var(--chart-5)',
  코어: 'var(--chart-6)',
  유산소: 'var(--chart-7)',
}

export type ExerciseKind = 'strength' | 'cardio'

export interface Exercise {
  id: string
  name: string
  group: MuscleGroup
  kind: ExerciseKind
}

export interface WorkoutSet {
  weight: number // kg — 0 for bodyweight
  reps: number
}

export interface Entry {
  id: string
  date: string // YYYY-MM-DD, local
  exerciseId: string
  /** strength only */
  sets: WorkoutSet[]
  /** cardio only */
  durationMin: number
  distanceKm: number
  note: string
}

export interface Store {
  exercises: Exercise[]
  entries: Entry[]
}
