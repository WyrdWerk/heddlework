import { describe, expect, it } from 'bun:test'
import { expandWorkspacePath } from '../src/host/server.ts'

describe('expandWorkspacePath', () => {
  it('expands the home shorthand against the host home', () => {
    expect(expandWorkspacePath('~', '/home/u')).toBe('/home/u')
    expect(expandWorkspacePath('~/projects/x', '/home/u')).toBe('/home/u/projects/x')
  })
  it('keeps absolute paths and tilde-users, trims whitespace', () => {
    expect(expandWorkspacePath('  /srv/x  ', '/home/u')).toBe('/srv/x')
    expect(expandWorkspacePath('~user/x', '/home/u')).toBe('~user/x')
  })
})
