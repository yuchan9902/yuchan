import type { Exercise } from './types'

/** Seed catalogue — the user can add to it, but these always exist. */
export const DEFAULT_EXERCISES: Exercise[] = [
  { id: 'bench-press', name: '벤치프레스', group: '가슴', kind: 'strength' },
  { id: 'incline-db-press', name: '인클라인 덤벨프레스', group: '가슴', kind: 'strength' },
  { id: 'chest-fly', name: '케이블 플라이', group: '가슴', kind: 'strength' },
  { id: 'deadlift', name: '데드리프트', group: '등', kind: 'strength' },
  { id: 'pull-up', name: '풀업', group: '등', kind: 'strength' },
  { id: 'barbell-row', name: '바벨로우', group: '등', kind: 'strength' },
  { id: 'lat-pulldown', name: '랫풀다운', group: '등', kind: 'strength' },
  { id: 'squat', name: '스쿼트', group: '하체', kind: 'strength' },
  { id: 'leg-press', name: '레그프레스', group: '하체', kind: 'strength' },
  { id: 'romanian-deadlift', name: '루마니안 데드리프트', group: '하체', kind: 'strength' },
  { id: 'leg-curl', name: '레그컬', group: '하체', kind: 'strength' },
  { id: 'overhead-press', name: '오버헤드프레스', group: '어깨', kind: 'strength' },
  { id: 'lateral-raise', name: '사이드 레터럴 레이즈', group: '어깨', kind: 'strength' },
  { id: 'face-pull', name: '페이스풀', group: '어깨', kind: 'strength' },
  { id: 'barbell-curl', name: '바벨컬', group: '팔', kind: 'strength' },
  { id: 'triceps-pushdown', name: '트라이셉스 푸시다운', group: '팔', kind: 'strength' },
  { id: 'hammer-curl', name: '해머컬', group: '팔', kind: 'strength' },
  { id: 'plank', name: '플랭크', group: '코어', kind: 'strength' },
  { id: 'hanging-leg-raise', name: '행잉 레그레이즈', group: '코어', kind: 'strength' },
  { id: 'cable-crunch', name: '케이블 크런치', group: '코어', kind: 'strength' },
  { id: 'running', name: '러닝', group: '유산소', kind: 'cardio' },
  { id: 'cycling', name: '사이클', group: '유산소', kind: 'cardio' },
  { id: 'rowing-machine', name: '로잉머신', group: '유산소', kind: 'cardio' },
  { id: 'jump-rope', name: '줄넘기', group: '유산소', kind: 'cardio' },
]
