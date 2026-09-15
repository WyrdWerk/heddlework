import { describe, expect, it } from 'bun:test'
import { reconcileLiveTranscript } from '../src/workbench/controller.ts'
import type { LiveAssistant, WorkbenchState } from '../src/workbench/state.ts'

function streamingState(liveAssistant: LiveAssistant): WorkbenchState {
  return { session: { isStreaming: true }, liveAssistant, liveTools: [] } as unknown as WorkbenchState
}

const live = (id: string, text: string): LiveAssistant => ({ id, blocks: [{ index: 0, kind: 'text', text }] })

describe('reconcileLiveTranscript', () => {
  it('retires the live assistant whose id matches the persisted timestamp', () => {
    const messages = [
      { role: 'assistant', content: [{ type: 'text', text: 'готово' }], timestamp: 1789482005000 },
    ] as WorkbenchState['messages']
    const result = reconcileLiveTranscript(streamingState(live('live-1789482005000', 'готово')), messages)
    expect(result.liveAssistant).toBeUndefined()
  })

  it('retires the live assistant by content when the id was minted from Date.now()', () => {
    // beginMessage falls back to Date.now() when the RPC event has no timestamp yet;
    // the persisted message then carries a different timestamp and the id never matches.
    const messages = [
      { role: 'user', content: [{ type: 'text', text: 'ping' }], timestamp: 1789481990000 },
      { role: 'assistant', content: [{ type: 'text', text: 'Привет, мир' }], timestamp: 1789482005000 },
    ] as WorkbenchState['messages']
    const result = reconcileLiveTranscript(streamingState(live('live-1789482000000', 'Привет, мир')), messages)
    expect(result.liveAssistant).toBeUndefined()
  })

  it('keeps the live assistant while its text is absent from history', () => {
    const messages = [
      { role: 'assistant', content: [{ type: 'text', text: 'другой текст' }], timestamp: 1 },
    ] as WorkbenchState['messages']
    const result = reconcileLiveTranscript(streamingState(live('live-999999', 'стрим идёт')), messages)
    expect(result.liveAssistant).toBeDefined()
  })
})
