import {
  deleteFromBunny,
  getBunnyConfig,
  isHomeAdStoragePath,
} from '../_shared/bunny_storage.ts'
import { corsHeaders, json, requireDashboardAdmin, sanitizeClientError } from '../_shared/admin_auth.ts'

type DeletePayload = {
  storage_path?: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'طريقة غير مسموحة' }, 405)
  }

  const auth = await requireDashboardAdmin(req)
  if (!auth.ok) return auth.response

  const bunny = getBunnyConfig()
  if (!bunny) {
    console.error('DELETE_HOME_AD_IMAGE bunny misconfigured')
    return json({ error: 'خدمة الصور غير مهيأة' }, 500)
  }

  let payload: DeletePayload
  try {
    payload = await req.json()
  } catch {
    return json({ error: 'صيغة الطلب غير صالحة' }, 400)
  }

  const storagePath = String(payload.storage_path ?? '').trim()
  if (!isHomeAdStoragePath(storagePath)) {
    return json({ error: 'مسار التخزين غير صالح' }, 400)
  }

  try {
    await deleteFromBunny(bunny, storagePath)
  } catch (error) {
    console.error('DELETE_HOME_AD_IMAGE failed', String(error))
    return json({ error: sanitizeClientError(error) }, 502)
  }

  return json({ deleted: true, storage_path: storagePath })
})
