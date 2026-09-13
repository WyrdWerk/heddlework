// Browser stand-in for node:fs/promises — see node-fs.ts. Persistence-style
// calls (last-workspace, queue stores) resolve as absorbed no-ops; reads that
// would need real file data reject with a clear error.

export async function mkdir(_path: string, _options?: unknown): Promise<undefined> {
  return undefined
}

export async function writeFile(_path: string, _data: unknown): Promise<void> {}

export async function readdir(_path: string): Promise<string[]> {
  return []
}

export async function stat(_path: string): Promise<never> {
  throw new Error('node:fs/promises is not available in the browser')
}

export async function open(_path: string, _flags?: string): Promise<never> {
  throw new Error('node:fs/promises is not available in the browser')
}
