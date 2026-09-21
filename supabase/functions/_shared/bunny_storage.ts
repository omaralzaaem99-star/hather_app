export type BunnyConfig = {
  storageZone: string
  apiKey: string
  storageHostname: string
  cdnHostname: string
}

const HOME_ADS_PREFIX = 'home-ads/'

export function getBunnyConfig(): BunnyConfig | null {
  const storageZone = (Deno.env.get('BUNNY_STORAGE_ZONE') ?? '').trim()
  const apiKey = (Deno.env.get('BUNNY_STORAGE_API_KEY') ?? '').trim()
  const storageHostname = (
    Deno.env.get('BUNNY_STORAGE_HOSTNAME') ?? 'storage.bunnycdn.com'
  ).trim()
  const cdnHostname = (Deno.env.get('BUNNY_CDN_HOSTNAME') ?? '').trim()

  if (!storageZone || !apiKey || !cdnHostname) return null

  return { storageZone, apiKey, storageHostname, cdnHostname }
}

export function isHomeAdStoragePath(path: string): boolean {
  const normalized = path.trim()
  if (!normalized.startsWith(HOME_ADS_PREFIX)) return false
  if (normalized.includes('..')) return false
  return /^home-ads\/\d{4}\/\d{2}\/[0-9a-f-]{36}\.(jpg|jpeg|png|webp)$/i.test(
    normalized,
  )
}

export function buildHomeAdStoragePath(extension: string): string {
  const now = new Date()
  const year = String(now.getUTCFullYear())
  const month = String(now.getUTCMonth() + 1).padStart(2, '0')
  const id = crypto.randomUUID()
  const ext = extension.toLowerCase() === 'jpeg' ? 'jpg' : extension.toLowerCase()
  return `${HOME_ADS_PREFIX}${year}/${month}/${id}.${ext}`
}

export function buildCdnUrl(config: BunnyConfig, storagePath: string): string {
  const host = config.cdnHostname.replace(/\/+$/, '')
  const path = storagePath.replace(/^\/+/, '')
  return `https://${host}/${path}`
}

function storageObjectUrl(config: BunnyConfig, storagePath: string): string {
  const host = config.storageHostname.replace(/\/+$/, '')
  const zone = config.storageZone.replace(/\/+$/, '')
  const path = storagePath.replace(/^\/+/, '')
  return `https://${host}/${zone}/${path}`
}

export async function uploadToBunny(
  config: BunnyConfig,
  storagePath: string,
  bytes: Uint8Array,
  contentType: string,
): Promise<void> {
  const res = await fetch(storageObjectUrl(config, storagePath), {
    method: 'PUT',
    headers: {
      AccessKey: config.apiKey,
      'Content-Type': contentType,
    },
    body: bytes,
  })

  if (!res.ok) {
    const text = await res.text()
    console.error(
      `BUNNY_UPLOAD_FAILED status=${res.status} path=${storagePath}`,
    )
    throw new Error(`bunny_upload_failed:${res.status}:${text.slice(0, 120)}`)
  }
}

export async function deleteFromBunny(
  config: BunnyConfig,
  storagePath: string,
): Promise<void> {
  const res = await fetch(storageObjectUrl(config, storagePath), {
    method: 'DELETE',
    headers: {
      AccessKey: config.apiKey,
    },
  })

  if (res.status === 404) return

  if (!res.ok) {
    const text = await res.text()
    console.error(
      `BUNNY_DELETE_FAILED status=${res.status} path=${storagePath}`,
    )
    throw new Error(`bunny_delete_failed:${res.status}:${text.slice(0, 120)}`)
  }
}

export const MAX_HOME_AD_BYTES = 5 * 1024 * 1024

export type ParsedImage = {
  contentType: string
  extension: string
}

export function detectImageType(
  bytes: Uint8Array,
  fileName: string,
): ParsedImage | null {
  const lowerName = fileName.toLowerCase()
  const ext = lowerName.includes('.')
    ? lowerName.split('.').pop() ?? ''
    : ''

  const allowedExt = new Set(['jpg', 'jpeg', 'png', 'webp'])
  if (!allowedExt.has(ext)) return null

  if (bytes.length >= 3 &&
    bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return { contentType: 'image/jpeg', extension: ext === 'jpeg' ? 'jpeg' : 'jpg' }
  }

  if (bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e &&
    bytes[3] === 0x47) {
    return { contentType: 'image/png', extension: 'png' }
  }

  if (bytes.length >= 12 &&
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 &&
    bytes[3] === 0x46 && bytes[8] === 0x57 && bytes[9] === 0x45 &&
    bytes[10] === 0x42 && bytes[11] === 0x50) {
    return { contentType: 'image/webp', extension: 'webp' }
  }

  return null
}
