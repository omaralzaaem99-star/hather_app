import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

export function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

export type AdminAuthResult =
  | { ok: true; userClient: SupabaseClient }
  | { ok: false; response: Response }

export async function requireDashboardAdmin(
  req: Request,
): Promise<AdminAuthResult> {
  const supabaseUrl = (Deno.env.get('SUPABASE_URL') ?? '').trim()
  const anonKey = (Deno.env.get('SUPABASE_ANON_KEY') ?? '').trim()

  if (!supabaseUrl || !anonKey) {
    console.error('HOME_AD_MEDIA missing supabase env')
    return { ok: false, response: json({ error: 'تعذّر الاتصال بالخادم' }, 500) }
  }

  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return { ok: false, response: json({ error: 'غير مصرّح' }, 401) }
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
    return { ok: false, response: json({ error: 'غير مصرّح' }, 401) }
  }

  const { data: isAdmin, error: adminErr } = await userClient.rpc(
    'is_dashboard_admin',
  )

  if (adminErr) {
    console.error('HOME_AD_MEDIA admin check failed', adminErr.message)
    return { ok: false, response: json({ error: 'غير مصرّح' }, 403) }
  }

  if (isAdmin !== true) {
    return { ok: false, response: json({ error: 'صلاحيات الأدمن مطلوبة' }, 403) }
  }

  return { ok: true, userClient }
}

export function sanitizeClientError(error: unknown): string {
  const raw = String(error ?? '')
  if (raw.includes('bunny_upload_failed:401') || raw.includes('bunny_delete_failed:401')) {
    return 'مفتاح Bunny Storage غير صالح. راجع BUNNY_STORAGE_API_KEY في Supabase Secrets.'
  }
  if (raw.includes('bunny_upload_failed:404') || raw.includes('bunny_delete_failed:404')) {
    return 'منطقة تخزين Bunny غير موجودة. راجع BUNNY_STORAGE_ZONE و BUNNY_STORAGE_HOSTNAME.'
  }
  if (raw.includes('bunny_upload_failed') || raw.includes('bunny_delete_failed')) {
    return 'تعذّر الاتصال بخدمة الصور Bunny. راجع إعدادات التخزين في Supabase Secrets.'
  }
  return 'تعذّر إكمال العملية. حاول لاحقاً.'
}
