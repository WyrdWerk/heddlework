// process.platform for the web bundle follows the visitor's OS so shortcut hints and chrome insets match the machine.

declare global { var __hwPlatform: string }

const ua = typeof navigator === 'undefined' ? '' : `${navigator.platform} ${navigator.userAgent}`
globalThis.__hwPlatform = /Mac|iPhone|iPad|iPod/i.test(ua) ? 'darwin' : /Win/i.test(ua) ? 'win32' : 'linux'


// Build-time defines replace `process.platform` and one env flag, but any
// other process.* access in shared code survives into the bundle and throws
// ReferenceError at runtime. Opening Settings, for example, reaches
// workbench/last-workspace.ts's `process.env` default parameter and takes the
// whole app down with a black screen. Install a minimal stand-in so those
// paths degrade gracefully instead of crashing.
const carrier = globalThis as { process?: unknown }
if (!carrier.process) {
  carrier.process = { env: {}, platform: __hwPlatform, version: 'heddlework-web', argv: [], cwd: () => '/' }
}

export {}
