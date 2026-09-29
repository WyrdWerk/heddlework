import { describe, expect, it } from 'bun:test'
import type { HostIdentity } from '../src/protocol/host-identity.ts'
import { WebHostSwitcher, type WebHostClient } from '../src/web/host-switcher.ts'

const studio: HostIdentity = { id: 'studio-id', name: 'Studio', os: 'darwin', arch: 'arm64', machine: 'mac-studio', version: '1', protocol: 1 }

function memoryStorage(initial: Record<string, string> = {}): Pick<Storage, 'getItem' | 'setItem'> {
  const data = new Map(Object.entries(initial))
  return {
    getItem: (key) => data.get(key) ?? null,
    setItem: (key, value) => { data.set(key, String(value)) },
  }
}

class FakeClient implements WebHostClient {
  candidates: readonly string[] = []
  #listeners = new Set<() => void>()
  #view: ReturnType<WebHostClient['getSnapshot']> = { status: 'closed', workspacePath: '' }

  subscribe(listener: () => void): () => void {
    this.#listeners.add(listener)
    return () => { this.#listeners.delete(listener) }
  }

  getSnapshot(): ReturnType<WebHostClient['getSnapshot']> {
    return this.#view
  }

  open(patch: { host?: HostIdentity; url?: string; workspacePath?: string }): void {
    this.#view = {
      status: 'open',
      url: patch.url ?? this.#view.url,
      workspacePath: patch.workspacePath ?? '/repo',
      ...(patch.host ? { host: patch.host } : this.#view.host ? { host: this.#view.host } : {}),
    }
    this.#emit()
  }

  connect(): void {}

  #emit(): void {
    for (const listener of this.#listeners) listener()
  }
}

describe('WebHostSwitcher snapshot identity (useSyncExternalStore contract)', () => {
  it('returns the same object between emits and a fresh object after an emit', () => {
    const client = new FakeClient()
    const switcher = new WebHostSwitcher(client, memoryStorage())
    const first = switcher.getSnapshot()
    expect(switcher.getSnapshot()).toBe(first)
    client.open({ host: studio })
    const after = switcher.getSnapshot()
    expect(after).not.toBe(first)
    expect(switcher.getSnapshot()).toBe(after)
  })
})
