import './uuid-shim.ts'
import '../dom/process-shim.ts'

// crypto.randomUUID (and crypto.subtle) exist only in secure contexts
// (HTTPS or localhost). The pairing docs explicitly support plain-HTTP LAN
// access (docs/community-web-port.md), but src/protocol/frames.ts calls
// crypto.randomUUID() for every frame, so on insecure origins the client
// crashes with a black screen before it can render anything. Shim a UUIDv4
// on top of getRandomValues, which IS available in insecure contexts.
if (typeof crypto.randomUUID !== 'function') {
  const randomUUID = (): `${string}-${string}-${string}-${string}-${string}` => {
    const b = crypto.getRandomValues(new Uint8Array(16))
    b[6] = ((b[6] ?? 0) & 0x0f) | 0x40
    b[8] = ((b[8] ?? 0) & 0x3f) | 0x80
    const h = Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('')
    return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`
  }
  Object.defineProperty(crypto, 'randomUUID', { value: randomUUID })
}
import React, { useState } from 'react'
import { createRoot } from 'react-dom/client'
import { installCreateElementBridge } from '../dom/host.tsx'
import { ConnectPage } from './connect-page.tsx'
import { readConnectionSettings, workspaceClient } from './store.ts'
import { WebWorkbench } from './workbench.tsx'

installCreateElementBridge()
const settings = readConnectionSettings(location.search, sessionStorage, location.origin, location.hash)
const hasCredentials = Boolean(settings.host && settings.token)
if (hasCredentials) {
  localStorage.setItem('heddlework.host', settings.host)
  sessionStorage.setItem('heddlework.token', settings.token)
  workspaceClient().connect(settings.host, settings.token)
}
stripPairingParameters()
function Root() { const [connected, setConnected] = useState(hasCredentials); return connected ? <WebWorkbench /> : <ConnectPage onConnected={() => setConnected(true)} /> }
if ('serviceWorker' in navigator && (location.protocol === 'https:' || (location.protocol === 'http:' && ['localhost', '127.0.0.1', '::1'].includes(location.hostname)))) void navigator.serviceWorker.register('/sw.js')
const root = document.getElementById('root')
if (!root) throw new Error('Missing #root')
createRoot(root).render(<Root />)
function stripPairingParameters(): void { const url = new URL(location.href); const fragment = new URLSearchParams(url.hash.replace(/^#/, '')); const paired = url.searchParams.has('token') || url.searchParams.has('host') || fragment.has('token') || fragment.has('host'); if (!paired) return; url.searchParams.delete('token'); url.searchParams.delete('host'); fragment.delete('token'); fragment.delete('host'); url.hash = fragment.toString(); history.replaceState(null, '', `${url.pathname}${url.search}${url.hash}`) }
