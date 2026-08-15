import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/** `2026-08-15` in local time (never UTC — `toISOString` shifts the day). */
export function toISODate(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

export function parseISODate(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, m - 1, d)
}

export function addDays(d: Date, n: number): Date {
  const next = new Date(d)
  next.setDate(next.getDate() + n)
  return next
}

/** Monday-anchored week start. */
export function startOfWeek(d: Date): Date {
  const day = (d.getDay() + 6) % 7
  return addDays(new Date(d.getFullYear(), d.getMonth(), d.getDate()), -day)
}

export function daysBetween(a: Date, b: Date): number {
  const ms = new Date(b.getFullYear(), b.getMonth(), b.getDate()).getTime() -
    new Date(a.getFullYear(), a.getMonth(), a.getDate()).getTime()
  return Math.round(ms / 86_400_000)
}

/** 1,284 → "1,284" · 12,900 → "1.3만" · 4,200,000 → "420만" */
export function compact(n: number): string {
  if (Math.abs(n) >= 10_000) {
    const man = n / 10_000
    return `${man >= 100 ? Math.round(man) : Number(man.toFixed(1))}만`
  }
  return n.toLocaleString('ko-KR')
}

export function formatNumber(n: number, digits = 0): string {
  return n.toLocaleString('ko-KR', { maximumFractionDigits: digits, minimumFractionDigits: 0 })
}

export function formatDateLabel(iso: string): string {
  const d = parseISODate(iso)
  return `${d.getMonth() + 1}월 ${d.getDate()}일`
}

export const WEEKDAY_KO = ['월', '화', '수', '목', '금', '토', '일'] as const

export function uid(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`
}
