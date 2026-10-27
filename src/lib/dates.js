// YYYY-MM-DD in the user's local time zone.
// Don't use toISOString().slice(0, 10) for this — it gives the UTC date,
// which is the previous day between local midnight and the UTC offset.
export function localDateKey(d = new Date()) {
  const date = d instanceof Date ? d : new Date(d)
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}
