import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'
import { importPKCS8, SignJWT } from 'https://esm.sh/jose@5.9.6'

type ServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
}

type UserNotificationRow = {
  id: string
  user_id: string
  type: string
  title: string
  body: string
  order_id: string | null
  support_request_id: string | null
  tap_destination: string | null
}

type DeviceTokenRow = {
  fcm_token: string
}

type WebhookPayload = {
  type?: string
  table?: string
  record?: { id?: string }
  notification_id?: string
}

const webhookSecret = (Deno.env.get('HATHER_PUSH_WEBHOOK_SECRET') ?? '').trim()
const serviceAccountRaw = (
  Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? ''
).trim()
const supabaseUrl = (Deno.env.get('SUPABASE_URL') ?? '').trim()
const serviceRoleKey = (Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '').trim()

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function parseServiceAccount(): ServiceAccount | null {
  if (!serviceAccountRaw) return null
  try {
    const sa = JSON.parse(serviceAccountRaw) as ServiceAccount
    if (!sa.project_id || !sa.client_email || !sa.private_key) return null
    return sa
  } catch {
    return null
  }
}

function verifyWebhook(req: Request): boolean {
  if (!webhookSecret) return false
  const header = req.headers.get('x-hather-push-webhook-secret') ?? ''
  return header === webhookSecret
}

async function verifyDbPushToken(req: Request): Promise<boolean> {
  const token = (req.headers.get('x-hather-db-push-token') ?? '').trim()
  if (!token || !supabaseUrl || !serviceRoleKey) return false

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data, error } = await admin.rpc('verify_internal_push_dispatch_token', {
    p_token: token,
  })

  return !error && data === true
}

async function isAuthorized(req: Request): Promise<boolean> {
  if (verifyWebhook(req)) return true
  return await verifyDbPushToken(req)
}

function extractNotificationId(payload: WebhookPayload): string | null {
  const fromRecord = payload.record?.id?.trim()
  if (fromRecord) return fromRecord
  const direct = payload.notification_id?.trim()
  return direct || null
}

function stringData(
  values: Record<string, string | null | undefined>,
): Record<string, string> {
  const out: Record<string, string> = {}
  for (const [key, value] of Object.entries(values)) {
    if (value != null && String(value).trim() !== '') {
      out[key] = String(value)
    }
  }
  return out
}

async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const privateKey = sa.private_key.replace(/\\n/g, '\n')
  const key = await importPKCS8(privateKey, 'RS256')

  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key)

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })

  if (!tokenRes.ok) {
    const text = await tokenRes.text()
    throw new Error(`oauth_token_failed status=${tokenRes.status} body=${text}`)
  }

  const tokenJson = await tokenRes.json()
  const accessToken = tokenJson.access_token as string | undefined
  if (!accessToken) {
    throw new Error('oauth_token_missing')
  }
  return accessToken
}

function isUnregisteredTokenError(status: number, bodyText: string): boolean {
  if (status === 404) return true
  const lower = bodyText.toLowerCase()
  return (
    lower.includes('unregistered') ||
    lower.includes('registration token is not a valid') ||
    lower.includes('not_found')
  )
}

function isAuthConfigError(status: number): boolean {
  return status === 401 || status === 403
}

async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  deviceToken: string,
  notification: UserNotificationRow,
): Promise<{ ok: boolean; status: number; body: string; unregistered: boolean }> {
  const data = stringData({
    type: notification.type,
    notification_id: notification.id,
    order_id: notification.order_id,
    support_request_id: notification.support_request_id,
    tap_destination: notification.tap_destination,
  })

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data,
          android: {
            priority: 'HIGH',
            notification: {
              channel_id: 'hather_default',
              sound: 'default',
            },
          },
        },
      }),
    },
  )

  const body = await res.text()
  return {
    ok: res.ok,
    status: res.status,
    body,
    unregistered: !res.ok && isUnregisteredTokenError(res.status, body),
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { status: 200 })
  }

  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405)
  }

  if (!(await isAuthorized(req))) {
    return json({ error: 'unauthorized' }, 401)
  }

  const sa = parseServiceAccount()
  if (!sa || !supabaseUrl || !serviceRoleKey) {
    console.error('PUSH_DISPATCH status=misconfigured')
    return json({ error: 'misconfigured' }, 500)
  }

  let payload: WebhookPayload
  try {
    payload = await req.json()
  } catch {
    return json({ error: 'invalid_json' }, 400)
  }

  const notificationId = extractNotificationId(payload)
  if (!notificationId) {
    return json({ error: 'notification_id_required' }, 400)
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data: notification, error: notificationError } = await admin
    .from('user_notifications')
    .select('id, user_id, type, title, body, order_id, support_request_id, tap_destination')
    .eq('id', notificationId)
    .maybeSingle()

  if (notificationError) {
    console.error(
      `PUSH_DISPATCH notification_load_failed id=${notificationId} err=${notificationError.message}`,
    )
    return json({ error: 'notification_load_failed' }, 500)
  }

  if (!notification) {
    return json({ sent: 0, reason: 'notification_not_found' })
  }

  const row = notification as UserNotificationRow

  const { data: tokens, error: tokensError } = await admin
    .from('push_device_tokens')
    .select('fcm_token')
    .eq('user_id', row.user_id)
    .eq('is_active', true)

  if (tokensError) {
    console.error(
      `PUSH_DISPATCH tokens_load_failed user=${row.user_id} err=${tokensError.message}`,
    )
    return json({ error: 'tokens_load_failed' }, 500)
  }

  const deviceTokens = (tokens ?? []) as DeviceTokenRow[]
  if (!deviceTokens.length) {
    return json({ sent: 0, reason: 'no_active_devices' })
  }

  let accessToken: string
  try {
    accessToken = await getGoogleAccessToken(sa)
  } catch (error) {
    console.error(`PUSH_DISPATCH oauth_failed err=${String(error)}`)
    return json({ error: 'firebase_oauth_failed' }, 500)
  }

  let sent = 0
  let failed = 0
  let deactivated = 0

  for (const device of deviceTokens) {
    const token = device.fcm_token?.trim()
    if (!token) continue

    try {
      const result = await sendFcmMessage(
        accessToken,
        sa.project_id,
        token,
        row,
      )

      if (result.ok) {
        sent += 1
        continue
      }

      failed += 1

      if (isAuthConfigError(result.status)) {
        console.error(
          `PUSH_DISPATCH firebase_auth_error status=${result.status}`,
        )
        return json({ error: 'firebase_auth_error', sent, failed }, 500)
      }

      if (result.unregistered) {
        const { error: deactivateError } = await admin.rpc(
          'deactivate_push_device_token',
          { p_fcm_token: token },
        )
        if (deactivateError) {
          console.error(
            `PUSH_DISPATCH deactivate_failed token_len=${token.length} err=${deactivateError.message}`,
          )
        } else {
          deactivated += 1
        }
      } else if (result.status >= 500 || result.status === 429) {
        console.error(
          `PUSH_DISPATCH transient_failure status=${result.status}`,
        )
      } else {
        console.error(
          `PUSH_DISPATCH send_failed status=${result.status}`,
        )
      }
    } catch (error) {
      failed += 1
      console.error(`PUSH_DISPATCH network_error err=${String(error)}`)
    }
  }

  return json({
    sent,
    failed,
    deactivated,
    notification_id: row.id,
    devices: deviceTokens.length,
  })
})
