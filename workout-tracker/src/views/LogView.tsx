import { useMemo, useState } from 'react'
import { CheckIcon, CopyIcon, PencilIcon, PlusIcon, Trash2Icon, XIcon } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input, Label, Select } from '@/components/ui/input'
import { entryVolume, exerciseMap } from '@/lib/stats'
import { useStoreActions } from '@/lib/store'
import type { Entry, Exercise, MuscleGroup, Store, WorkoutSet } from '@/lib/types'
import { GROUP_COLOR, MUSCLE_GROUPS } from '@/lib/types'
import { compact, formatDateLabel, formatNumber, toISODate, uid } from '@/lib/utils'

const EMPTY_SET: WorkoutSet = { weight: 20, reps: 10 }

interface Draft {
  id: string | null
  date: string
  exerciseId: string
  sets: WorkoutSet[]
  durationMin: string
  distanceKm: string
  note: string
}

function newDraft(exerciseId: string): Draft {
  return {
    id: null,
    date: toISODate(new Date()),
    exerciseId,
    sets: [{ ...EMPTY_SET }],
    durationMin: '30',
    distanceKm: '',
    note: '',
  }
}

export function LogView({ store }: { store: Store }) {
  const { addEntry, updateEntry, removeEntry, addExercise } = useStoreActions()
  const map = useMemo(() => exerciseMap(store.exercises), [store.exercises])
  const [draft, setDraft] = useState<Draft>(() => newDraft(store.exercises[0]?.id ?? ''))
  const [error, setError] = useState<string | null>(null)
  const [showNewExercise, setShowNewExercise] = useState(false)

  const exercise = map.get(draft.exerciseId)
  const isCardio = exercise?.kind === 'cardio'

  const byGroup = useMemo(() => {
    const grouped = new Map<MuscleGroup, Exercise[]>()
    for (const g of MUSCLE_GROUPS) grouped.set(g, [])
    for (const e of store.exercises) grouped.get(e.group)?.push(e)
    return [...grouped.entries()].filter(([, list]) => list.length > 0)
  }, [store.exercises])

  const allDays = useMemo(() => {
    const grouped = new Map<string, Entry[]>()
    for (const entry of store.entries) {
      if (!grouped.has(entry.date)) grouped.set(entry.date, [])
      grouped.get(entry.date)!.push(entry)
    }
    return [...grouped.entries()].sort((a, b) => b[0].localeCompare(a[0]))
  }, [store.entries])

  const [visibleDays, setVisibleDays] = useState(10)
  const days = allDays.slice(0, visibleDays)

  function patchSet(index: number, patch: Partial<WorkoutSet>) {
    setDraft((d) => ({
      ...d,
      sets: d.sets.map((s, i) => (i === index ? { ...s, ...patch } : s)),
    }))
  }

  function submit() {
    if (!exercise) {
      setError('운동을 선택해 주세요.')
      return
    }
    if (!draft.date) {
      setError('날짜를 입력해 주세요.')
      return
    }

    const sets = isCardio
      ? []
      : draft.sets
          .map((s) => ({ weight: Math.max(0, Number(s.weight) || 0), reps: Math.round(Number(s.reps) || 0) }))
          .filter((s) => s.reps > 0)

    const durationMin = isCardio ? Math.max(0, Number(draft.durationMin) || 0) : 0
    if (!isCardio && !sets.length) {
      setError('횟수가 1회 이상인 세트를 최소 하나 입력해 주세요.')
      return
    }
    if (isCardio && durationMin <= 0) {
      setError('유산소는 운동 시간을 1분 이상 입력해 주세요.')
      return
    }

    const entry: Entry = {
      id: draft.id ?? uid(),
      date: draft.date,
      exerciseId: draft.exerciseId,
      sets,
      durationMin,
      distanceKm: isCardio ? Math.max(0, Number(draft.distanceKm) || 0) : 0,
      note: draft.note.trim(),
    }

    if (draft.id) updateEntry(entry)
    else addEntry(entry)

    setError(null)
    setDraft((d) => ({ ...newDraft(d.exerciseId), date: d.date }))
  }

  function edit(entry: Entry) {
    setDraft({
      id: entry.id,
      date: entry.date,
      exerciseId: entry.exerciseId,
      sets: entry.sets.length ? entry.sets.map((s) => ({ ...s })) : [{ ...EMPTY_SET }],
      durationMin: String(entry.durationMin || 30),
      distanceKm: entry.distanceKm ? String(entry.distanceKm) : '',
      note: entry.note,
    })
    setError(null)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  return (
    <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,22rem)_minmax(0,1fr)]">
      <Card className="lg:sticky lg:top-4">
        <CardHeader>
          <div>
            <CardTitle>{draft.id ? '기록 수정' : '운동 기록하기'}</CardTitle>
            <CardDescription>
              세트별 무게와 횟수를 남기면 볼륨과 1RM 추정치가 자동으로 계산돼요.
            </CardDescription>
          </div>
          {draft.id ? (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setDraft((d) => newDraft(d.exerciseId))
                setError(null)
              }}
            >
              <XIcon aria-hidden />
              취소
            </Button>
          ) : null}
        </CardHeader>

        <CardContent className="flex flex-col gap-4">
          <div>
            <Label htmlFor="entry-date">날짜</Label>
            <Input
              id="entry-date"
              type="date"
              value={draft.date}
              max={toISODate(new Date())}
              onChange={(e) => setDraft((d) => ({ ...d, date: e.target.value }))}
            />
          </div>

          <div>
            <div className="mb-1.5 flex items-center justify-between">
              <Label htmlFor="entry-exercise" className="mb-0">운동</Label>
              <button
                type="button"
                className="text-muted-foreground hover:text-foreground text-xs underline underline-offset-2"
                onClick={() => setShowNewExercise((v) => !v)}
              >
                {showNewExercise ? '닫기' : '새 종목 추가'}
              </button>
            </div>
            <Select
              id="entry-exercise"
              value={draft.exerciseId}
              onChange={(e) => setDraft((d) => ({ ...d, exerciseId: e.target.value }))}
            >
              {byGroup.map(([group, list]) => (
                <optgroup key={group} label={group}>
                  {list.map((ex) => (
                    <option key={ex.id} value={ex.id}>
                      {ex.name}
                    </option>
                  ))}
                </optgroup>
              ))}
            </Select>
          </div>

          {showNewExercise ? (
            <NewExerciseForm
              onCreate={(ex) => {
                addExercise(ex)
                setDraft((d) => ({ ...d, exerciseId: ex.id }))
                setShowNewExercise(false)
              }}
            />
          ) : null}

          {isCardio ? (
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label htmlFor="entry-duration">시간 (분)</Label>
                <Input
                  id="entry-duration"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  value={draft.durationMin}
                  onChange={(e) => setDraft((d) => ({ ...d, durationMin: e.target.value }))}
                />
              </div>
              <div>
                <Label htmlFor="entry-distance">거리 (km)</Label>
                <Input
                  id="entry-distance"
                  type="number"
                  inputMode="decimal"
                  min={0}
                  step={0.1}
                  placeholder="선택"
                  value={draft.distanceKm}
                  onChange={(e) => setDraft((d) => ({ ...d, distanceKm: e.target.value }))}
                />
              </div>
            </div>
          ) : (
            <div>
              <Label>세트</Label>
              <div className="flex flex-col gap-2">
                <div className="text-muted-foreground grid grid-cols-[1.5rem_1fr_1fr_2rem] items-center gap-2 text-[11px]">
                  <span />
                  <span>무게 (kg)</span>
                  <span>횟수</span>
                  <span />
                </div>
                {draft.sets.map((set, i) => (
                  <div key={i} className="grid grid-cols-[1.5rem_1fr_1fr_2rem] items-center gap-2">
                    <span className="text-muted-foreground tnum text-xs">{i + 1}</span>
                    <Input
                      type="number"
                      inputMode="decimal"
                      min={0}
                      step={2.5}
                      aria-label={`${i + 1}세트 무게 (kg)`}
                      value={set.weight}
                      onChange={(e) => patchSet(i, { weight: Number(e.target.value) })}
                    />
                    <Input
                      type="number"
                      inputMode="numeric"
                      min={0}
                      aria-label={`${i + 1}세트 횟수`}
                      value={set.reps}
                      onChange={(e) => patchSet(i, { reps: Number(e.target.value) })}
                    />
                    <Button
                      variant="ghost"
                      size="icon"
                      className="size-8"
                      aria-label={`${i + 1}세트 삭제`}
                      disabled={draft.sets.length === 1}
                      onClick={() =>
                        setDraft((d) => ({ ...d, sets: d.sets.filter((_, idx) => idx !== i) }))}
                    >
                      <XIcon aria-hidden />
                    </Button>
                  </div>
                ))}
              </div>
              <div className="mt-2 flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() =>
                    setDraft((d) => ({ ...d, sets: [...d.sets, { ...d.sets[d.sets.length - 1] }] }))}
                >
                  <CopyIcon aria-hidden />
                  같은 세트 추가
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setDraft((d) => ({ ...d, sets: [...d.sets, { ...EMPTY_SET }] }))}
                >
                  <PlusIcon aria-hidden />
                  빈 세트
                </Button>
              </div>
            </div>
          )}

          <div>
            <Label htmlFor="entry-note">메모</Label>
            <Input
              id="entry-note"
              placeholder="예: 마지막 세트 실패"
              value={draft.note}
              onChange={(e) => setDraft((d) => ({ ...d, note: e.target.value }))}
            />
          </div>

          {error ? (
            <p role="alert" className="text-destructive text-xs">
              {error}
            </p>
          ) : null}

          <Button onClick={submit}>
            <CheckIcon aria-hidden />
            {draft.id ? '수정 저장' : '기록 저장'}
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <div>
            <CardTitle>기록 목록</CardTitle>
            <CardDescription>운동한 날을 최신순으로 묶어서 보여줘요.</CardDescription>
          </div>
          <Badge variant="secondary" className="tnum">전체 {store.entries.length}건</Badge>
        </CardHeader>
        <CardContent className="flex flex-col gap-5">
          {days.length ? (
            days.map(([date, entries]) => {
              const dayVolume = entries.reduce((sum, e) => sum + entryVolume(e), 0)
              return (
                <section key={date}>
                  <div className="mb-2 flex items-center gap-2">
                    <h4 className="text-sm font-semibold">{formatDateLabel(date)}</h4>
                    <span className="text-muted-foreground tnum text-xs">
                      {entries.length}종목{dayVolume > 0 ? ` · ${compact(Math.round(dayVolume))}kg` : ''}
                    </span>
                  </div>
                  <ul className="rounded-lg border">
                    {entries.map((entry, i) => {
                      const ex = map.get(entry.exerciseId)
                      if (!ex) return null
                      return (
                        <li
                          key={entry.id}
                          className={`flex flex-wrap items-center gap-x-3 gap-y-1 px-3 py-2.5 ${i > 0 ? 'border-t' : ''}`}
                        >
                          <span
                            aria-hidden
                            className="size-2.5 shrink-0 rounded-[3px]"
                            style={{ background: GROUP_COLOR[ex.group] }}
                          />
                          <span className="text-sm font-medium">{ex.name}</span>
                          <span className="text-muted-foreground tnum min-w-0 flex-1 truncate text-xs">
                            {ex.kind === 'cardio'
                              ? `${entry.durationMin}분${entry.distanceKm ? ` · ${entry.distanceKm}km` : ''}`
                              : entry.sets
                                  .map((s) => `${formatNumber(s.weight, 1)}×${s.reps}`)
                                  .join('  ')}
                            {entry.note ? ` · ${entry.note}` : ''}
                          </span>
                          <div className="flex items-center gap-1">
                            <Button
                              variant="ghost"
                              size="icon"
                              className="size-8"
                              aria-label={`${ex.name} 기록 수정`}
                              onClick={() => edit(entry)}
                            >
                              <PencilIcon aria-hidden />
                            </Button>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="hover:text-destructive size-8"
                              aria-label={`${ex.name} 기록 삭제`}
                              onClick={() => {
                                if (draft.id === entry.id) setDraft((d) => newDraft(d.exerciseId))
                                removeEntry(entry.id)
                              }}
                            >
                              <Trash2Icon aria-hidden />
                            </Button>
                          </div>
                        </li>
                      )
                    })}
                  </ul>
                </section>
              )
            })
          ) : (
            <p className="text-muted-foreground py-10 text-center text-xs">
              아직 기록이 없어요. 왼쪽에서 첫 운동을 남겨보세요.
            </p>
          )}

          {allDays.length > visibleDays ? (
            <Button variant="outline" onClick={() => setVisibleDays((n) => n + 20)}>
              이전 기록 더 보기 ({allDays.length - visibleDays}일 남음)
            </Button>
          ) : null}
        </CardContent>
      </Card>
    </div>
  )
}

function NewExerciseForm({ onCreate }: { onCreate: (exercise: Exercise) => void }) {
  const [name, setName] = useState('')
  const [group, setGroup] = useState<MuscleGroup>('가슴')

  return (
    <div className="bg-muted/50 flex flex-col gap-3 rounded-lg border p-3">
      <div>
        <Label htmlFor="new-exercise-name">종목 이름</Label>
        <Input
          id="new-exercise-name"
          value={name}
          placeholder="예: 딥스"
          onChange={(e) => setName(e.target.value)}
        />
      </div>
      <div>
        <Label htmlFor="new-exercise-group">부위</Label>
        <Select
          id="new-exercise-group"
          value={group}
          onChange={(e) => setGroup(e.target.value as MuscleGroup)}
        >
          {MUSCLE_GROUPS.map((g) => (
            <option key={g} value={g}>
              {g}
            </option>
          ))}
        </Select>
      </div>
      <Button
        size="sm"
        disabled={!name.trim()}
        onClick={() =>
          onCreate({
            id: `custom-${uid()}`,
            name: name.trim(),
            group,
            kind: group === '유산소' ? 'cardio' : 'strength',
          })}
      >
        <PlusIcon aria-hidden />
        종목 추가
      </Button>
    </div>
  )
}
