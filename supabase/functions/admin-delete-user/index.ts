/**
 * admin-delete-user
 *
 * Permanently deletes a user or captain Auth account after server-side checks.
 * SERVICE_ROLE stays in Edge only.
 *
 * Deploy: supabase functions deploy admin-delete-user
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
    console.error('ADMIN_DELETE_USER missing env')
    return json({ error: 'Server misconfigured' }, 500)
  }

  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return json({ error: 'Unauthorized' }, 401)
  }

  let payload: { user_id?: string; reason?: string }
  try {
    payload = await req.json()
  } catch {
    return json({ error: 'Invalid JSON body' }, 400)
  }

  const targetUserId = String(payload.user_id ?? '').trim()
  const reason = typeof payload.reason === 'string' ? payload.reason : null
  if (!targetUserId) {
    return json({ error: 'user_id required' }, 400)
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const {
    data: { user: caller },
    error: userErr,
  } = await userClient.auth.getUser()
  if (userErr || !caller) {
    return json({ error: 'Unauthorized' }, 401)
  }

  const { data: isAdmin, error: adminErr } = await userClient.rpc(
    'is_dashboard_admin',
  )
  if (adminErr) {
    console.error('ADMIN_DELETE_USER admin check', adminErr.message)
    return json({ error: adminErr.message }, 403)
  }
  if (isAdmin !== true) {
    return json({ error: 'Admin access required' }, 403)
  }

  if (caller.id === targetUserId) {
    return json({ error: 'لا يمكن حذف حسابك الإداري من اللوحة' }, 400)
  }

  const { data: prepared, error: prepErr } = await userClient.rpc(
    'admin_prepare_account_deletion',
    {
      p_user_id: targetUserId,
      p_reason: reason,
    },
  )
  if (prepErr) {
    return json({ error: prepErr.message }, 400)
  }

  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { error: delErr } = await adminClient.auth.admin.deleteUser(
    targetUserId,
  )
  if (delErr) {
    console.error('ADMIN_DELETE_USER auth delete failed', delErr.message)
    return json(
      {
        error:
          'تعذّر حذف حساب المصادقة. قد تبقى سجلات مرتبطة — راجع السجلات.',
        detail: delErr.message,
      },
      500,
    )
  }

  return json({
    ok: true,
    deleted_user_id: targetUserId,
    prepared,
  })
})
