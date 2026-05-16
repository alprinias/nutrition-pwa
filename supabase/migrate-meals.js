#!/usr/bin/env node
/**
 * migrate-meals.js
 * Reads Γεύματα sheet from Διατροφή.xlsx and generates SQL inserts
 * for meal_log rows from April 2026 onwards.
 *
 * Usage:
 *   node supabase/migrate-meals.js <user_id>
 *
 * Get your user_id from: Supabase dashboard → Authentication → Users → copy the UUID
 */

import pkg from 'xlsx'
const { readFile, utils } = pkg
import { writeFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __dirname = dirname(fileURLToPath(import.meta.url))

const userId = process.argv[2]
if (!userId) {
  console.error('❌  Usage: node supabase/migrate-meals.js <your-user-uuid>')
  console.error('   Find your UUID in Supabase → Authentication → Users')
  process.exit(1)
}

const EXCEL_PATH = join(__dirname, 'Διατροφή.xlsx')
const CUTOFF = new Date('2026-04-01T00:00:00')

console.log(`Reading ${EXCEL_PATH}…`)
const wb = readFile(EXCEL_PATH)

// ── Load reference maps: name → id ───────────────────────────────────────────

const ylika = utils.sheet_to_json(wb.Sheets['Υλικά'], { defval: '' })
const ingredientByIndex = new Map()  // Excel Index col → db id
const ingredientById = new Map()     // db id → name (for logging)
ylika.forEach(row => {
  if (row['id']) {
    ingredientByIndex.set(parseInt(row['id']), parseInt(row['id']))
    ingredientById.set(parseInt(row['id']), row['Όνομα'])
  }
})

const syndAthr = utils.sheet_to_json(wb.Sheets['ΣυνδΑθρ'], { defval: '' })
const recipeByName = new Map()
syndAthr.forEach((row, idx) => {
  const name = row['Συνδυασμός']
  if (name && !recipeByName.has(name)) {
    recipeByName.set(name, idx + 1)  // matches migration_003 which uses idx+1
  }
})

// ── Read Γεύματα ──────────────────────────────────────────────────────────────

const gevmata = utils.sheet_to_json(wb.Sheets['Γεύματα'], { defval: '' })

console.log(`Total Γεύματα rows: ${gevmata.length}`)

// ── Helpers ───────────────────────────────────────────────────────────────────

function sql(val) {
  if (val === null || val === undefined || val === '') return 'NULL'
  return `'${String(val).replace(/'/g, "''")}'`
}

function num(val, decimals = 4) {
  const v = parseFloat(val)
  return isNaN(v) ? '0' : v.toFixed(decimals)
}

function excelDateToISO(dateVal, timeVal) {
  // dateVal is a JS Date from openpyxl/xlsx (already parsed)
  // timeVal is a fraction of day (e.g. 0.375 = 09:00) or a time string
  let d
  if (dateVal instanceof Date) {
    d = new Date(dateVal)
  } else if (typeof dateVal === 'number') {
    // Excel serial date
    d = new Date((dateVal - 25569) * 86400 * 1000)
  } else {
    return null
  }

  // Apply time
  if (timeVal && typeof timeVal === 'number') {
    const totalSeconds = Math.round(timeVal * 86400)
    const hh = Math.floor(totalSeconds / 3600)
    const mm = Math.floor((totalSeconds % 3600) / 60)
    d.setUTCHours(hh, mm, 0, 0)
  } else if (timeVal && typeof timeVal === 'string') {
    const [hh, mm] = timeVal.split(':').map(Number)
    d.setUTCHours(hh || 0, mm || 0, 0, 0)
  }

  return d.toISOString()
}

// ── Process rows ──────────────────────────────────────────────────────────────

const insertLines = []
let skipped = 0
let processed = 0

gevmata.forEach((row, i) => {
  const rawDate = row['Ημέρα']
  if (!rawDate) return

  // Parse date
  let rowDate
  if (rawDate instanceof Date) {
    rowDate = rawDate
  } else if (typeof rawDate === 'number') {
    rowDate = new Date((rawDate - 25569) * 86400 * 1000)
  } else {
    return
  }

  // Filter: April 2026 onwards only
  if (rowDate < CUTOFF) return

  const recipeName    = row['Συνδυασμός']
  const ingredientName = row['Υλικό']
  const unit          = row['Μονάδα'] || 'gr'
  const indexVal      = parseInt(row['Index'])
  const quantity      = parseFloat(row['Ποσότητα'])
  const protein       = parseFloat(row['Πρωτεΐνες g'])   || 0
  const carbs         = parseFloat(row['Υδατάνθρακες g']) || 0
  const fat           = parseFloat(row['Λίπη g'])         || 0
  const calories      = parseFloat(row['Θερμίδες'])       || 0
  const note          = row['Σχόλιο'] || ''

  if (!quantity || isNaN(quantity)) { skipped++; return }

  // Resolve recipe_id or ingredient_id
  let recipeId = 'NULL'
  let ingredientId = 'NULL'

  if (recipeName) {
    const rid = recipeByName.get(String(recipeName).trim())
    if (rid) recipeId = rid
    else { skipped++; return }
  } else if (ingredientName) {
    // Index column maps directly to ingredient id
    if (!isNaN(indexVal) && indexVal > 0) {
      ingredientId = indexVal
    } else { skipped++; return }
  } else {
    skipped++; return
  }

  // Build logged_at timestamp
  const loggedAt = excelDateToISO(rowDate, row['Ώρα'])
  if (!loggedAt) { skipped++; return }

  const displayNote = note
    ? sql(note)
    : recipeName
      ? sql(recipeName)
      : ingredientName
        ? sql(ingredientName)
        : 'NULL'

  insertLines.push(
    `(gen_random_uuid(), ${sql(userId)}, ${sql(loggedAt)}, ${recipeId}, ${ingredientId}, ` +
    `${num(quantity, 2)}, ${sql(unit)}, ${displayNote}, ` +
    `${num(calories, 2)}, ${num(protein, 2)}, ${num(carbs, 2)}, ${num(fat, 2)})`
  )
  processed++
})

console.log(`✓ Processed: ${processed} rows`)
console.log(`⚠ Skipped:   ${skipped} rows (missing data or unmatched recipe)`)

if (insertLines.length === 0) {
  console.error('❌ No rows to insert. Check that April 2026+ data exists in the sheet.')
  process.exit(1)
}

// ── Write SQL ─────────────────────────────────────────────────────────────────

const sql_out = `-- ============================================================
-- migration_005_meal_log.sql
-- Historical meal data from April 2026 onwards
-- Generated: ${new Date().toISOString()}
-- User: ${userId}
-- Rows: ${insertLines.length}
-- ============================================================

-- Remove any existing data for this user in this period to avoid duplicates
delete from public.meal_log
where user_id = '${userId}'
  and logged_at >= '2026-04-01T00:00:00Z';

insert into public.meal_log
  (id, user_id, logged_at, recipe_id, ingredient_id,
   quantity, unit, note, calories, protein_g, carbs_g, fat_g)
values
${insertLines.join(',\n')};
`

const outPath = join(__dirname, 'migration_005_meal_log.sql')
writeFileSync(outPath, sql_out, 'utf8')
console.log(`\n✅ Written: ${outPath}`)
console.log('   Run this in Supabase SQL Editor to import your meal history.')
