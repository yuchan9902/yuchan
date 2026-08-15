import { useEffect, useState } from 'react'
import { MoonIcon, SunIcon } from 'lucide-react'
import { Button } from '@/components/ui/button'

const KEY = 'fitlog.theme'

/** Dark mode is a selected palette, not an inverted one — see index.css. */
export function ThemeToggle() {
  const [dark, setDark] = useState(() =>
    typeof document === 'undefined' ? true : document.documentElement.classList.contains('dark'))

  useEffect(() => {
    document.documentElement.classList.toggle('dark', dark)
    try {
      localStorage.setItem(KEY, dark ? 'dark' : 'light')
    } catch {
      // Storage blocked — the toggle still works for this session.
    }
  }, [dark])

  return (
    <Button
      variant="ghost"
      size="icon"
      aria-label={dark ? '라이트 모드로 전환' : '다크 모드로 전환'}
      title={dark ? '라이트 모드로 전환' : '다크 모드로 전환'}
      onClick={() => setDark((v) => !v)}
    >
      {dark ? <SunIcon aria-hidden /> : <MoonIcon aria-hidden />}
    </Button>
  )
}
