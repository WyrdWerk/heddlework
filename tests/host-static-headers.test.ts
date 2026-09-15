import { afterEach, describe, expect, it } from 'bun:test'
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createWorkspaceHost } from '../src/host/server.ts'

const roots: string[] = []
afterEach(() => { for (const path of roots.splice(0)) rmSync(path, { recursive: true, force: true }) })

describe('workspace host static cache policy', () => {
  it('serves every static asset with no-cache so deploys are picked up immediately', async () => {
    const root = mkdtempSync(join(tmpdir(), 'heddlework-static-'))
    roots.push(root)
    writeFileSync(join(root, 'index.html'), '<html></html>')
    writeFileSync(join(root, 'main.js'), '// bundle')
    writeFileSync(join(root, 'sw.js'), '// worker')
    const host = createWorkspaceHost({
      controller: { getSnapshot: () => ({ state: undefined }), subscribe: () => () => undefined } as never,
      flows: { getSnapshot: () => ({}), subscribe: () => () => undefined } as never,
      workspacePath: '/tmp',
      token: 't'.repeat(40),
      staticRoot: root,
      port: 0,
      hostname: '127.0.0.1',
    })
    try {
      for (const asset of ['/main.js', '/sw.js', '/index.html']) {
        const response = await fetch(new URL(asset, host.url))
        expect(response.headers.get('cache-control')).toBe('no-cache')
      }
    } finally {
      await host.close()
    }
  })
})
