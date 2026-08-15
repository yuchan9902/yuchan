import { useEffect, useMemo, useState } from 'react'
import {
  BarChart3Icon,
  DownloadIcon,
  DumbbellIcon,
  LayoutDashboardIcon,
  NotebookPenIcon,
  RotateCcwIcon,
  UploadIcon,
} from 'lucide-react'
import { Dashboard } from '@/views/Dashboard'
import { LogView } from '@/views/LogView'
import { StatsView } from '@/views/StatsView'
import { FilterBar } from '@/components/FilterBar'
import { ThemeToggle } from '@/components/ThemeToggle'
import { Button } from '@/components/ui/button'
import { Select } from '@/components/ui/input'
import { Tabs } from '@/components/ui/tabs'
import { resolveRange, type RangeKey } from '@/lib/range'
import { useStore, useStoreActions } from '@/lib/store'
import { MUSCLE_GROUPS } from '@/lib/types'
import { RANGE_LABEL } from '@/lib/range'
import { formatDateLabel } from '@/lib/utils'

type TabKey = 'dashboard' | 'log' | 'stats'

const TABS = [
  { value: 'dashboard' as const, label: '대시보드', icon: <LayoutDashboardIcon aria-hidden /> },
  { value: 'log' as const, label: '기록', icon: <NotebookPenIcon aria-hidden /> },
  { value: 'stats' as const, label: '통계', icon: <BarChart3Icon aria-hidden /> },
]

export default function App() {
  const store = useStore()
  const { resetToDemo, exportJSON, importJSON } = useStoreActions()
  const [tab, setTab] = useState<TabKey>('dashboard')
  const [rangeKey, setRangeKey] = useState<RangeKey>('90d')
  const [exerciseId, setExerciseId] = useState('')

  const range = useMemo(() => resolveRange(rangeKey, store.entries), [rangeKey, store.entries])

  /** Default the stats view to whatever the user actually trains most. */
  const mostLogged = useMemo(() => {
    const counts = new Map<string, number>()
    for (const e of store.entries) {
      if (!e.sets.length) continue
      counts.set(e.exerciseId, (counts.get(e.exerciseId) ?? 0) + 1)
    }
    let best = ''
    let top = 0
    for (const [id, n] of counts) {
      if (n > top) {
        top = n
        best = id
      }
    }
    return best || store.exercises.find((e) => e.kind === 'strength')?.id || ''
  }, [store.entries, store.exercises])

  useEffect(() => {
    if (!exerciseId || !store.exercises.some((e) => e.id === exerciseId)) setExerciseId(mostLogged)
  }, [exerciseId, mostLogged, store.exercises])

  return (
    <div className="min-h-dvh">
      <header className="bg-background/85 sticky top-0 z-30 border-b backdrop-blur">
        <div className="mx-auto flex h-14 max-w-6xl items-center gap-3 px-4">
          <span className="bg-primary text-primary-foreground flex size-7 items-center justify-center rounded-md">
            <DumbbellIcon className="size-4" aria-hidden />
          </span>
          <div className="mr-auto min-w-0">
            <h1 className="text-sm leading-none font-semibold tracking-tight">FitLog</h1>
            <p className="text-muted-foreground mt-1 truncate text-[11px] leading-none">
              운동 기록 &amp; 통계
            </p>
          </div>
          <DataMenu onExport={exportJSON} onImport={importJSON} onReset={resetToDemo} />
          <ThemeToggle />
        </div>
      </header>

      <main className="mx-auto flex max-w-6xl flex-col gap-4 px-4 py-5">
        <Tabs aria-label="화면 전환" items={TABS} value={tab} onChange={setTab} />

        {tab === 'log' ? null : (
          <FilterBar range={rangeKey} onRangeChange={setRangeKey}>
            {tab === 'stats' ? (
              <label className="ml-auto flex items-center gap-2">
                <span className="text-muted-foreground text-xs font-medium">종목</span>
                <Select
                  className="h-9 w-52"
                  aria-label="통계를 볼 종목"
                  value={exerciseId}
                  onChange={(e) => setExerciseId(e.target.value)}
                >
                  {MUSCLE_GROUPS.map((group) => {
                    const list = store.exercises.filter((e) => e.group === group && e.kind === 'strength')
                    if (!list.length) return null
                    return (
                      <optgroup key={group} label={group}>
                        {list.map((ex) => (
                          <option key={ex.id} value={ex.id}>
                            {ex.name}
                          </option>
                        ))}
                      </optgroup>
                    )
                  })}
                </Select>
              </label>
            ) : (
              <span className="text-muted-foreground tnum ml-auto text-xs">
                {formatDateLabel(range.from)} – {formatDateLabel(range.to)} · {RANGE_LABEL[rangeKey]}
              </span>
            )}
          </FilterBar>
        )}

        {tab === 'dashboard' ? <Dashboard store={store} range={range} /> : null}
        {tab === 'log' ? <LogView store={store} /> : null}
        {tab === 'stats' ? <StatsView store={store} range={range} exerciseId={exerciseId} /> : null}

        <footer className="text-muted-foreground border-t pt-4 pb-2 text-[11px] leading-relaxed">
          모든 기록은 이 브라우저에만 저장돼요 (localStorage). 서버로 전송되지 않으니, 기기를 바꾸기 전에
          내보내기로 백업해 주세요.
        </footer>
      </main>
    </div>
  )
}

function DataMenu({
  onExport,
  onImport,
  onReset,
}: {
  onExport: () => string
  onImport: (text: string) => void
  onReset: () => void
}) {
  const [message, setMessage] = useState<string | null>(null)

  useEffect(() => {
    if (!message) return
    const t = setTimeout(() => setMessage(null), 3000)
    return () => clearTimeout(t)
  }, [message])

  async function download() {
    const filename = `fitlog-backup-${new Date().toISOString().slice(0, 10)}.json`
    const json = onExport()

    // Inside the Artifact viewer the page cannot start its own download, so the
    // save goes through the host and the viewer confirms it. Everywhere else
    // `claude` is undefined and the ordinary blob link runs.
    const host = typeof claude === 'undefined' ? null : claude
    if (host) {
      try {
        const downloads = await host.use('downloads')
        if (downloads) {
          await downloads.save({ filename, data: json })
          setMessage('내보냈어요')
          return
        }
      } catch (e) {
        const code = (e as { code?: string } | null)?.code
        setMessage(code === 'declined' ? '내보내기를 취소했어요' : '내보내지 못했어요')
        return
      }
    }

    const url = URL.createObjectURL(new Blob([json], { type: 'application/json' }))
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    a.click()
    URL.revokeObjectURL(url)
  }

  function pickFile() {
    const input = document.createElement('input')
    input.type = 'file'
    input.accept = 'application/json'
    input.onchange = async () => {
      const file = input.files?.[0]
      if (!file) return
      try {
        onImport(await file.text())
        setMessage('불러왔어요')
      } catch (e) {
        setMessage(e instanceof Error ? e.message : '불러오지 못했어요')
      }
    }
    input.click()
  }

  return (
    <div className="flex items-center gap-1">
      {message ? <span className="text-muted-foreground mr-1 text-xs">{message}</span> : null}
      <Button variant="ghost" size="icon" title="JSON으로 내보내기" aria-label="JSON으로 내보내기" onClick={download}>
        <DownloadIcon aria-hidden />
      </Button>
      <Button variant="ghost" size="icon" title="JSON 불러오기" aria-label="JSON 불러오기" onClick={pickFile}>
        <UploadIcon aria-hidden />
      </Button>
      <Button
        variant="ghost"
        size="icon"
        title="예시 데이터로 초기화"
        aria-label="예시 데이터로 초기화"
        onClick={() => {
          if (window.confirm('지금 기록을 모두 지우고 예시 데이터로 되돌릴까요? 되돌릴 수 없어요.')) {
            onReset()
            setMessage('예시 데이터로 초기화했어요')
          }
        }}
      >
        <RotateCcwIcon aria-hidden />
      </Button>
    </div>
  )
}
