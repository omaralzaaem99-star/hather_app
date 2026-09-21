import {
  buildCdnUrl,
  buildHomeAdStoragePath,
  detectImageType,
  getBunnyConfig,
  MAX_HOME_AD_BYTES,
  uploadToBunny,
} from '../_shared/bunny_storage.ts'
import { corsHeaders, json, requireDashboardAdmin, sanitizeClientError } from '../_shared/admin_auth.ts'

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
    console.error('UPLOAD_HOME_AD_IMAGE bunny misconfigured')
    return json({ error: 'خدمة الصور غير مهيأة' }, 500)
  }

  let form: FormData
  try {
    form = await req.formData()
  } catch {
    return json({ error: 'صيغة الطلب غير صالحة' }, 400)
  }

  const file = form.get('file')
  if (!(file instanceof File)) {
    return json({ error: 'الصورة مطلوبة' }, 400)
  }

  if (file.size <= 0) {
    return json({ error: 'الصورة فارغة' }, 400)
  }

  if (file.size > MAX_HOME_AD_BYTES) {
    return json({ error: 'حجم الصورة كبير جداً، الحد الأقصى 5 MB.' }, 400)
  }

  const bytes = new Uint8Array(await file.arrayBuffer())
  const parsed = detectImageType(bytes, file.name)
  if (!parsed) {
    return json({ error: 'نوع الصورة غير مدعوم. استخدم JPG أو PNG أو WEBP.' }, 400)
  }

  const storagePath = buildHomeAdStoragePath(parsed.extension)

  try {
    await uploadToBunny(bunny, storagePath, bytes, parsed.contentType)
  } catch (error) {
    console.error('UPLOAD_HOME_AD_IMAGE failed', String(error))
    return json({ error: sanitizeClientError(error) }, 502)
  }

  const imageUrl = buildCdnUrl(bunny, storagePath)

  return json({
    image_url: imageUrl,
    storage_path: storagePath,
  })
})
