#!/usr/bin/env node
/**
 * Session End Hook
 * 
 * Finalizes the memory session and triggers promotion evaluation.
 * 
 * Requirements: 5.5 - WHEN SessionEnd event fires, THE Memory_System SHALL finalize the session
 *                     and trigger promotion evaluation
 */

const {
  readStdinInput,
  outputResponse,
  getMemorySessionId,
  removeMemorySessionId,
  callCaptureMemory,
  loadSessionState,
  saveSessionState,
} = require('./shared/memory-client.js');

/**
 * Call promote_memory MCP tool to evaluate session for promotion
 * @param {string} sessionId - Memory session ID
 * @returns {Promise<Object>} Promotion result
 */
async function callPromoteMemory(sessionId) {
  const fs = require('fs');
  const path = require('path');
  
  const CONFIG = {
    STATE_DIR: path.join(process.env.HOME || process.env.USERPROFILE || '', '.memorymcp'),
  };
  
  const queueDir = path.join(CONFIG.STATE_DIR, 'queue');
  if (!fs.existsSync(queueDir)) {
    fs.mkdirSync(queueDir, { recursive: true });
  }
  
  const queueFile = path.join(queueDir, `${Date.now()}-${Math.random().toString(36).slice(2)}.json`);
  fs.writeFileSync(queueFile, JSON.stringify({
    tool: 'promote_memory',
    params: {
      sessionId: sessionId,
      reason: 'Session ended - automatic promotion evaluation',
    },
    timestamp: new Date().toISOString(),
  }), 'utf-8');
  
  return { queued: true, file: queueFile };
}

/**
 * Clean up old sessions (older than 24 hours)
 */
function cleanupOldSessions() {
  try {
    const state = loadSessionState();
    const now = Date.now();
    const maxAge = 24 * 60 * 60 * 1000; // 24 hours
    
    let cleaned = 0;
    for (const [kiroSessionId, entry] of Object.entries(state)) {
      // Support both old string format and new object format
      if (typeof entry === 'object' && entry.createdAt) {
        const age = now - new Date(entry.createdAt).getTime();
        if (age > maxAge) {
          delete state[kiroSessionId];
          cleaned++;
        }
      } else if (typeof entry === 'string') {
        // Old format without timestamp - keep for now but mark for future cleanup
        // These will be cleaned up when they're accessed and re-saved
      }
    }
    
    if (cleaned > 0) {
      saveSessionState(state);
      console.error(`[session-end-hook] Cleaned up ${cleaned} old sessions`);
    }
  } catch (error) {
    console.error('[session-end-hook] Failed to cleanup old sessions:', error.message);
  }
}

async function handleSessionEnd(input) {
  try {
    if (!input) {
      console.error('[session-end-hook] No input received');
      outputResponse();
      return;
    }

    const { session_id: kiroSessionId, cwd, reason } = input;

    if (!kiroSessionId) {
      console.error('[session-end-hook] Missing session_id');
      outputResponse();
      return;
    }

    // Get the memory session ID
    const memorySessionId = getMemorySessionId(kiroSessionId);
    if (!memorySessionId) {
      console.error('[session-end-hook] No memory session found for Kiro session:', kiroSessionId);
      // Still cleanup old sessions
      cleanupOldSessions();
      outputResponse();
      return;
    }

    console.error(`[session-end-hook] Finalizing session: ${memorySessionId} (reason: ${reason || 'unknown'})`);

    // End the memory session
    await callCaptureMemory({
      action: 'end',
      sessionId: memorySessionId,
      metadata: {
        kiroSessionId: kiroSessionId,
        cwd: cwd,
        endReason: reason || 'session_end',
        endedAt: new Date().toISOString(),
      },
    });

    // Trigger promotion evaluation
    console.error('[session-end-hook] Triggering promotion evaluation');
    await callPromoteMemory(memorySessionId);

    // Remove the session mapping
    removeMemorySessionId(kiroSessionId);

    // Cleanup old sessions
    cleanupOldSessions();

    console.error('[session-end-hook] Session finalized successfully');
    outputResponse();
  } catch (error) {
    console.error('[session-end-hook] Error:', error.message);
    outputResponse();
  }
}

// Main execution
readStdinInput().then(handleSessionEnd);
