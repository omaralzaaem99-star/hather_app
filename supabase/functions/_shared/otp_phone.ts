/** OTPIQ phone + OTP helpers. Never log OTP or API tokens. */

export const OTPIQ_PROVIDER = 'whatsapp-telegram-sms'

export function normalizePhoneDisplay(value: unknown): string | null {
  if (typeof value !== 'string') return null

  let digits = value.trim().replace(/[\s\-()]/g, '')
  digits = digits.replace(/[٠-٩]/g, (d) =>
    String('٠١٢٣٤٥٦٧٨٩'.indexOf(d)),
  )
  digits = digits.replace(/[^\d+]/g, '')
  if (digits.startsWith('+')) digits = digits.slice(1)
  digits = digits.replace(/\D/g, '')

  if (digits.length < 9) return null

  if (digits.startsWith('964')) {
    return `+${digits}`
  }
  if (digits.startsWith('0')) {
    return `+964${digits.slice(1)}`
  }
  if (digits.startsWith('7') && digits.length === 10) {
    return `+964${digits}`
  }
  return `+964${digits}`
}

/** OTPIQ expects international digits without +, e.g. 9647806560098 */
export function normalizePhoneOtpiq(value: unknown): string | null {
  const display = normalizePhoneDisplay(value)
  if (!display) return null
  const digits = display.replace(/^\+/, '')
  if (!/^9647\d{9}$/.test(digits)) return null
  return digits
}

export function generateOtp(): string {
  const array = new Uint32Array(1)
  crypto.getRandomValues(array)
  return String(array[0] % 1_000_000).padStart(6, '0')
}

export function parseJson(value: string): Record<string, unknown> | null {
  try {
    const parsed = JSON.parse(value)
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>
    }
  } catch (_) {
    // ignore
  }
  return null
}

export function sanitizeOtpiqPayload(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeOtpiqPayload(item))
  }

  if (value && typeof value === 'object') {
    const output: Record<string, unknown> = {}
    for (const [key, entry] of Object.entries(
      value as Record<string, unknown>,
    )) {
      const lower = key.toLowerCase()
      if (
        lower.includes('verificationcode') ||
        lower.includes('otp') ||
        lower === 'code' ||
        lower.includes('apikey') ||
        lower.includes('api_key') ||
        lower.includes('token') ||
        lower.includes('authorization') ||
        lower.includes('bearer')
      ) {
        output[key] = '[redacted]'
        continue
      }
      output[key] = sanitizeOtpiqPayload(entry)
    }
    return output
  }

  if (typeof value === 'string') {
    return value.replace(/\b\d{6}\b/g, '[redacted]')
  }

  return value
}

export function extractOtpiqErrorMessage(
  data: Record<string, unknown> | null,
  fallbackText: string,
): string {
  if (!data) {
    const trimmed = fallbackText.trim()
    return trimmed || 'تعذر إرسال رمز التحقق من مزود الرسائل'
  }

  const candidates = [
    data.error,
    data.message,
    data.msg,
    data.statusMessage,
    data.status,
  ]

  for (const candidate of candidates) {
    if (typeof candidate === 'string' && candidate.trim()) {
      const lower = candidate.trim().toLowerCase()
      if (lower.includes('credit') || lower.includes('balance')) {
        return 'تعذر إرسال رمز التحقق بسبب مشكلة في رصيد الرسائل'
      }
      if (/[A-Za-z]{6,}/.test(candidate) && !/[\u0600-\u06FF]/.test(candidate)) {
        return 'تعذر إرسال رمز التحقق، حاول مرة أخرى'
      }
      return candidate.trim()
    }
  }

  return 'تعذر إرسال رمز التحقق من مزود الرسائل'
}

/**
 * OTPIQ may return HTTP 200 with a soft failure body.
 * Only treat as accepted when there is an smsId/messageId and no error.
 */
export function isOtpiqAccepted(
  httpOk: boolean,
  data: Record<string, unknown> | null,
): { accepted: boolean; messageId: string | null } {
  if (!httpOk) {
    return { accepted: false, messageId: null }
  }

  if (!data) {
    return { accepted: false, messageId: null }
  }

  if (typeof data.error === 'string' && data.error.trim()) {
    return { accepted: false, messageId: null }
  }

  const statusRaw = data.status ?? data.deliveryStatus ?? data.state
  const status = typeof statusRaw === 'string'
    ? statusRaw.trim().toLowerCase()
    : ''
  if (
    status === 'rejected' ||
    status === 'failed' ||
    status === 'fail' ||
    status === 'error'
  ) {
    return { accepted: false, messageId: null }
  }

  const messageIdCandidates = [
    data.smsId,
    data.messageId,
    data.requestId,
    data.id,
  ]

  let messageId: string | null = null
  for (const candidate of messageIdCandidates) {
    if (typeof candidate === 'string' && candidate.trim()) {
      messageId = candidate.trim()
      break
    }
  }

  if (!messageId) {
    return { accepted: false, messageId: null }
  }

  return { accepted: true, messageId }
}
