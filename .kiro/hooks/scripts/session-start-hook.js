#!/usr/bin/env node
/**
 * Session Start Hook
 * 
 * Initializes a new memory session when a Kiro session starts.
 * 
 * Requirements: 5.1 - WHEN SessionStart event fires, THE Memory_System SHALL initialize a new memory session
 */

const {
  readStdinInput,
  outputResponse,
  extractProjectName,
  setMemorySessionId,
  getMemorySessionId,
  generateMemorySessionId,
  callCaptureMemory,
} = require('./shared/memory-client.js');

async function handleSessionStart(input) {
  try {
    if (!input) {
      console.error('[session-start-hook] No input received');
      outputResponse();
      return;
    }

    const { session_id: kiroSessionId, cwd, prompt } = input;

    if (!kiroSessionId) {
      console.error('[session-start-hook] Missing session_id');
      outputResponse();
      return;
    }

    // Check if session already exists (avoid duplicate initialization)
    const existingSessionId = getMemorySessionId(kiroSessionId);
    if (existingSessionId) {
      console.error(`[session-start-hook] Session already exists: ${existingSessionId}`);
      outputResponse();
      return;
    }

    const projectId = extractProjectName(cwd);
    console.error(`[session-start-hook] Starting session for project: ${projectId}`);

    // Generate a deterministic session ID upfront
    const memorySessionId = generateMemorySessionId(kiroSessionId, projectId);
    
    // Store the memory session ID mapping immediately
    setMemorySessionId(kiroSessionId, memorySessionId);
    console.error(`[session-start-hook] Memory session created: ${memorySessionId}`);

    // Call capture_memory with 'start' action using the generated session ID
    await callCaptureMemory({
      action: 'start',
      sessionId: memorySessionId,
      projectId: projectId,
      metadata: {
        kiroSessionId: kiroSessionId,
        cwd: cwd,
        startedAt: new Date().toISOString(),
      },
    });

    // If there's an initial prompt, capture it with the same session ID
    if (prompt && prompt.trim()) {
      await callCaptureMemory({
        action: 'event',
        sessionId: memorySessionId,
        phase: 'SessionStart',
        type: 'user_prompt',
        content: prompt,
        importance: 0.6,
        metadata: {
          kiroSessionId: kiroSessionId,
          isInitialPrompt: true,
        },
      });
    }

    outputResponse();
  } catch (error) {
    console.error('[session-start-hook] Error:', error.message);
    outputResponse();
  }
}

// Main execution
readStdinInput().then(handleSessionStart);
