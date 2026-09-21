/**
 * delete-my-account
 *
 * Self-service permanent account deletion.
 * - JWT identity only (never accepts target user_id from client)
 * - Re-verifies password (phone + secret code)
 * - Calls prepare_my_account_deletion RPC (active-order guards + anonymize)
 * - Deletes Auth user via Admin API (service_role stays in Edge)
 *
 * Deploy:
 *   supabase functions deploy delete-my-account --project-ref gonlutyrhccmdpdwqdhk
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const supabaseUrl = (Deno.env.get('SUPABASE_URL') ?? '').trim()
  const anonKey = (Deno.env.get('SUPABASE_ANON_KEY') ?? '').trim()
  const serviceKey = (Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '').trim()

  if (!supabaseUrl || !anonKey || !serviceKey) {
    console.error('DELETE_MY_ACCOUNT missing env')
    return json({ error: 'Server misconfigured' }, 500)
  }

  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return json({ error: 'Unauthorized' }, 401)
  }

  let payload: { password?: string; user_id?: string }
  try {
    payload = await req.json()
  } catch {
    return json({ error: 'Invalid JSON body' }, 400)
  }

  // Hard reject any attempt to delete another user via body.
  if (payload.user_id != null && String(payload.user_id).trim() !== '') {
    return json({ error: 'Unauthorized' }, 403)
  }

  const password = String(payload.password ?? '').trim()
  if (!password) {
    return json({ error: 'كلمة المرور مطلوبة لتأكيد الحذف' }, 400)
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const {
    data: { user },
    error: userErr,
  } = await userClient.auth.getUser()
  if (userErr || !user) {
    return json({ error: 'Unauthorized' }, 401)
  }

  const { data: profile, error: profileErr } = await userClient
    .from('profiles')
    .select('id, phone, account_type')
    .eq('id', user.id)
    .maybeSingle()

  if (profileErr) {
    console.error('DELETE_MY_ACCOUNT profile', profileErr.message)
    return json({ error: 'تعذر حذف الحساب حالياً. يرجى المحاولة مرة أخرى.' }, 500)
  }

  const phone = (profile?.phone as string | undefined)?.trim()
  if (!phone) {
    return json({ error: 'تعذر التحقق من الحساب' }, 400)
  }

  // Re-auth with current password (same login method: phone + password).
  const verifyClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { error: verifyErr } = await verifyClient.auth.signInWithPassword({
    phone,
    password,
  })
  if (verifyErr) {
    return json({ error: 'كلمة المرور غير صحيحة' }, 401)
  }
  try {
    await verifyClient.auth.signOut()
  } catch {
    // ignore
  }

  const { data: prepared, error: prepErr } = await userClient.rpc(
    'prepare_my_account_deletion',
  )
  if (prepErr) {
    const message = (prepErr.message ?? '').trim()
    if (
      message.includes('طلب نشط') ||
      message.includes('طلبات نشطة') ||
      message.includes('لوحة الإدارة')
    ) {
      return json({ error: message }, 409)
    }
    console.error('DELETE_MY_ACCOUNT prepare', message)
    return json(
      { error: message || 'تعذر حذف الحساب حالياً. يرجى المحاولة مرة أخرى.' },
      400,
    )
  }

  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { error: delErr } = await adminClient.auth.admin.deleteUser(user.id)
  if (delErr) {
    // Idempotent: already gone
    const msg = delErr.message.toLowerCase()
    if (msg.includes('not found') || msg.includes('user not found')) {
      return json({ ok: true, deleted_user_id: user.id, prepared, already_deleted: true })
    }
    console.error('DELETE_MY_ACCOUNT auth delete failed', delErr.message)
    return json(
      { error: 'تعذر حذف الحساب حالياً. يرجى المحاولة مرة أخرى.' },
      500,
    )
  }

  return json({
    ok: true,
    deleted_user_id: user.id,
    prepared,
  })
})
