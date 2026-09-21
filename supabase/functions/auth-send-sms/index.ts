import { Webhook } from 'https://esm.sh/standardwebhooks@1.0.0'
import {
  extractOtpiqErrorMessage,
  normalizePhoneOtpiq,
  OTPIQ_PROVIDER,
  parseJson,
  sanitizeOtpiqPayload,
} from '../_shared/otp_phone.ts'

/**
 * Supabase Auth Send SMS Hook → OTPIQ delivery only.
 *
 * Secrets (Dashboard / CLI):
 *   OTPIQ_API_KEY          (preferred; falls back to legacy OTPIQ_API_TOKEN)
 *   SEND_SMS_HOOK_SECRET   (v1,whsec_... from Auth Hook settings)
 *
 * Deploy with verify_jwt = false (Auth calls before user JWT exists).
 * Requests WITHOUT a valid Standard Webhooks signature are rejected.
 */

const otpiqApiKey = (
  Deno.env.get('OTPIQ_API_KEY') ??
  Deno.env.get('OTPIQ_API_TOKEN') ??
  ''
).trim()
const hookSecretRaw = (Deno.env.get('SEND_SMS_HOOK_SECRET') ?? '').trim()

function maskPhone(phone: string): string {
  const digits = phone.replace(/\D/g, '')
  if (digits.length < 6) return '***'
  return `${digits.slice(0, 5)}*****${digits.slice(-3)}`
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    console.error('[auth-send-sms] status=rejected reason=method_not_allowed')
    return json({ error: { http_code: 405, message: 'Method not allowed' } }, 405)
  }

  console.log('[auth-send-sms] request received')

  if (!hookSecretRaw) {
    console.error('[auth-send-sms] status=misconfigured reason=missing_hook_secret')
    return json(
      { error: { http_code: 500, message: 'Hook secret not configured' } },
      500,
    )
  }

  if (!otpiqApiKey) {
    console.error('[auth-send-sms] status=misconfigured reason=missing_otpiq_api_key')
    return json(
      { error: { http_code: 500, message: 'SMS provider not configured' } },
      500,
    )
  }

  const payload = await req.text()
  const headers = Object.fromEntries(req.headers)
  const base64Secret = hookSecretRaw.replace(/^v1,whsec_/, '')

  let user: { phone?: string } | null = null
  let sms: { otp?: string } | null = null

  try {
    const wh = new Webhook(base64Secret)
    const verified = wh.verify(payload, headers) as {
      user?: { phone?: string }
      sms?: { otp?: string }
    }
    user = verified.user ?? null
    sms = verified.sms ?? null
  } catch (_) {
    console.error('[auth-send-sms] status=rejected reason=invalid_signature_or_json')
    return json(
      { error: { http_code: 401, message: 'Invalid webhook signature' } },
      401,
    )
  }

  const phoneRaw = typeof user?.phone === 'string' ? user.phone : ''
  const otp = typeof sms?.otp === 'string' ? sms.otp.trim() : ''

  if (!phoneRaw) {
    console.error('[auth-send-sms] status=rejected reason=missing_phone')
    return json(
      { error: { http_code: 400, message: 'Phone is required' } },
      400,
    )
  }

  if (!otp) {
    console.error('[auth-send-sms] status=rejected reason=missing_otp')
    return json(
      { error: { http_code: 400, message: 'OTP is required' } },
      400,
    )
  }

  const phoneOtpiq = normalizePhoneOtpiq(phoneRaw)
  if (!phoneOtpiq) {
    console.error(
      `[auth-send-sms] status=rejected reason=invalid_phone phone=${maskPhone(phoneRaw)}`,
    )
    return json(
      { error: { http_code: 400, message: 'Unsupported phone number' } },
      400,
    )
  }

  console.log(
    `[auth-send-sms] phone normalized phone=${maskPhone(phoneOtpiq)} provider=OTPIQ`,
  )

  try {
    const otpiqResponse = await fetch('https://api.otpiq.com/api/sms', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${otpiqApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        phoneNumber: phoneOtpiq,
        smsType: 'verification',
        provider: OTPIQ_PROVIDER,
        verificationCode: otp,
      }),
    })

    const otpiqText = await otpiqResponse.text()
    const otpiqData = parseJson(otpiqText)

    if (!otpiqResponse.ok) {
      console.error(
        `[auth-send-sms] OTPIQ status=${otpiqResponse.status} phone=${maskPhone(phoneRaw)}`,
      )
      void sanitizeOtpiqPayload(otpiqData ?? otpiqText)
      return json(
        {
          error: {
            http_code: 502,
            message: extractOtpiqErrorMessage(
              otpiqData,
              'Failed to send SMS',
            ),
          },
        },
        502,
      )
    }

    console.log(
      `[auth-send-sms] OTPIQ status=${otpiqResponse.status} sent successfully phone=${maskPhone(phoneRaw)}`,
    )
    return Response.json({}, { status: 200 })
  } catch (error) {
    console.error('[auth-send-sms] status=error reason=unexpected')
    void error
    return json(
      { error: { http_code: 500, message: 'Unexpected SMS send failure' } },
      500,
    )
  }
})
