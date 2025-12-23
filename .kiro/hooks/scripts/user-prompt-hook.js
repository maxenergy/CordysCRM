#!/usr/bin/env node
/**
 * User Prompt Hook
 * 
 * Captures user prompts submitted during a session.
 * 
 * Requirements: 5.2 - WHEN UserPromptSubmit event fires, THE Memory_System SHALL capture the user prompt
 */

const {
  readStdinInput,
  outputResponse,
  getMemorySessionId,
  callCaptureMemory,
  summarizeText,
} = require('./shared/memory-client.js');

async function handleUserPrompt(input) {
  try {
    if (!input) {
      console.error('[user-prompt-hook] No input received');
      outputResponse();
      return;
    }

    const { session_id: kiroSessionId, cwd, prompt } = input;

    if (!kiroSessionId) {
      console.error('[user-prompt-hook] Missing session_id');
      outputResponse();
      return;
    }

    if (!prompt || !prompt.trim()) {
      console.error('[user-prompt-hook] Empty prompt, skipping');
      outputResponse();
      return;
    }

    // Get the memory session ID
    const memorySessionId = getMemorySessionId(kiroSessionId);
    if (!memorySessionId) {
      console.error('[user-prompt-hook] No memory session found for Kiro session:', kiroSessionId);
      outputResponse();
      return;
    }

    // Check for privacy tags - if entire prompt is private, skip
    const privateTagRegex = /<private>[\s\S]*?<\/private>/gi;
    const strippedPrompt = prompt.replace(privateTagRegex, '[REDACTED]').trim();
    
    if (strippedPrompt === '[REDACTED]' || strippedPrompt === '') {
      console.error('[user-prompt-hook] Prompt is fully private, skipping');
      outputResponse();
      return;
    }

    // Determine importance based on prompt characteristics
    let importance = 0.5;
    if (prompt.length > 500) importance += 0.1;
    if (prompt.includes('?')) importance += 0.1;
    if (prompt.toLowerCase().includes('error') || prompt.toLowerCase().includes('bug')) importance += 0.15;
    if (prompt.toLowerCase().includes('important') || prompt.toLowerCase().includes('critical')) importance += 0.15;
    importance = Math.min(importance, 1.0);

    console.error(`[user-prompt-hook] Capturing prompt (${strippedPrompt.length} chars, importance: ${importance.toFixed(2)})`);

    // Call capture_memory with 'event' action
    await callCaptureMemory({
      action: 'event',
      sessionId: memorySessionId,
      phase: 'UserPromptSubmit',
      type: 'user_prompt',
      content: strippedPrompt,
      importance: importance,
      metadata: {
        kiroSessionId: kiroSessionId,
        cwd: cwd,
        originalLength: prompt.length,
        wasRedacted: prompt !== strippedPrompt,
      },
    });

    outputResponse();
  } catch (error) {
    console.error('[user-prompt-hook] Error:', error.message);
    outputResponse();
  }
}

// Main execution
readStdinInput().then(handleUserPrompt);
