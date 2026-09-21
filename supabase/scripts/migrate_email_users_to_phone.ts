/**
 * Admin migration helper: attach phone identity to existing @hather.local users
 * WITHOUT changing auth.users.id (preserves profiles / orders FKs).
 *
 * Run with Deno + SERVICE ROLE locally (never ship in Flutter):
 *
 *   deno run --allow-net --allow-env supabase/scripts/migrate_email_users_to_phone.ts
 *
 * Required env:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *
 * Behavior:
 * - Lists users with email *@hather.local
 * - For each, reads profiles.phone
 * - Calls auth.admin.updateUserById({ phone, phone_confirm: true })
 * - Does NOT create a new auth user / does NOT change UUID / does NOT reset password
 *
 * STOP conditions (script aborts row, continues others):
 * - missing profile phone
 * - phone already used by another auth user
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const url = Deno.env.get('SUPABASE_URL') ?? ''
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

if (!url || !serviceKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY')
  Deno.exit(1)
}

const admin = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
})

function normalizeE164(raw: string): string | null {
  let digits = raw.trim().replace(/[\s\-()]/g, '')
  digits = digits.replace(/[٠-٩]/g, (d) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d)))
  if (digits.startsWith('00')) digits = digits.slice(2)
  if (digits.startsWith('+')) digits = digits.slice(1)
  digits = digits.replace(/\D/g, '')
  if (digits.startsWith('964')) {
    const national = digits.slice(3)
    if (/^7\d{9}$/.test(national)) return `+964${national}`
    return null
  }
  if (digits.startsWith('0') && /^07\d{9}$/.test(digits)) {
    return `+964${digits.slice(1)}`
  }
  if (/^7\d{9}$/.test(digits)) return `+964${digits}`
  return null
}

const { data: profiles, error: profilesError } = await admin
  .from('profiles')
  .select('id, phone')

if (profilesError) {
  console.error('Failed to load profiles', profilesError.message)
  Deno.exit(1)
}

const profileById = new Map<string, string>()
for (const row of profiles ?? []) {
  if (row?.id && row?.phone) profileById.set(String(row.id), String(row.phone))
}

let page = 1
let migrated = 0
let skipped = 0
let failed = 0

for (;;) {
  const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 })
  if (error) {
    console.error('listUsers failed', error.message)
    Deno.exit(1)
  }
  const users = data.users ?? []
  if (users.length === 0) break

  for (const user of users) {
    const email = (user.email ?? '').toLowerCase()
    if (!email.endsWith('@hather.local')) continue

    const rawPhone = profileById.get(user.id)
    if (!rawPhone) {
      console.warn(`SKIP ${user.id}: no profile phone`)
      skipped++
      continue
    }

    const phone = normalizeE164(rawPhone)
    if (!phone) {
      console.warn(`SKIP ${user.id}: invalid profile phone`)
      skipped++
      continue
    }

    if (user.phone === phone.replace('+', '') || user.phone === phone) {
      console.log(`OK already has phone ${user.id}`)
      migrated++
      continue
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(user.id, {
      phone,
      phone_confirm: true,
    })

    if (updateError) {
      console.error(`FAIL ${user.id}: ${updateError.message}`)
      failed++
      continue
    }

    console.log(`MIGRATED ${user.id} → phone set (uuid preserved)`)
    migrated++
  }

  page++
}

console.log(JSON.stringify({ migrated, skipped, failed }, null, 2))
