// crypto.randomUUID exists only in secure contexts (HTTPS or localhost). The
// pairing docs explicitly support plain-HTTP LAN access (docs/community-web-port.md),
// but src/protocol/frames.ts calls crypto.randomUUID() for every frame, so on
// insecure origins the client crashes with a black screen before it can render.
// This module MUST be the first import of the web entrypoint: ESM evaluates
// imported modules before the importer's body, so an inline shim in main.tsx
// runs after every dependency has already initialized.
if (typeof crypto.randomUUID !== 'function') {
  const randomUUID = (): `${string}-${string}-${string}-${string}-${string}` => {
    const b = crypto.getRandomValues(new Uint8Array(16))
    b[6] = ((b[6] ?? 0) & 0x0f) | 0x40
    b[8] = ((b[8] ?? 0) & 0x3f) | 0x80
    const h = Array.from(b, (x) => x.toString(16).padStart(2, '0'))
    return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`
  }
  Object.defineProperty(crypto, 'randomUUID', { value: randomUUID })
}
