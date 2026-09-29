// Browser stand-in for node:fs. Shared modules (workbench stores, session
// tooling) are bundled wholesale for the web client even though their
// filesystem work belongs to the host process: reads degrade to empty
// results, writes are absorbed silently, and probes report "missing" so
// host-side resolution falls back to PATH-style defaults.

export function existsSync(_path: string): boolean {
  return false
}

export function readFileSync(_path: string, _encoding?: string): string {
  return ''
}

export function readdirSync(_path: string): string[] {
  return []
}

export function mkdirSync(_path: string, _options?: unknown): undefined {
  return undefined
}

export function writeFileSync(_path: string, _data: unknown): void {}

export function renameSync(_from: string, _to: string): void {}

export function rmSync(_path: string, _options?: unknown): void {}

export function realpathSync(path: string): string {
  return path
}

export function statSync(_path: string): { isFile: () => boolean; isDirectory: () => boolean; mtimeMs: number } {
  throw new Error('node:fs is not available in the browser')
}

export function lstatSync(_path: string): { isFile: () => boolean; isDirectory: () => boolean; isSymbolicLink: () => boolean; mtimeMs: number } {
  throw new Error('node:fs is not available in the browser')
}

export function watch(_path: string, _options?: unknown): { close: () => void; on: (event: string, listener: (...args: unknown[]) => void) => void } {
  return { close() {}, on() {} }
}
