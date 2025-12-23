#!/usr/bin/env node
/**
 * Stop Hook
 * 
 * Captures the assistant's response when execution stops.
 * 
 * Requirements: 5.4 - WHEN Stop event fires, THE Memory_System SHALL capture the assistant's response
 */

const {
  readStdinInput,
  outputResponse,
  getMemorySessionId,
  callCaptureMemory,
  summarizeText,
} = require('./shared/memory-client.js');

/**
 * Extract key decisions from assistant response
 * @param {string} response - Assistant response text
 * @returns {string[]} List of key decisions
 */
function extractDecisions(response) {
  const decisions = [];
  
  // Look for decision patterns
  const patterns = [
    /(?:I(?:'ll| will)|Let me|Going to)\s+([^.!?\n]+[.!?])/gi,
    /(?:decided to|choosing to|opted for)\s+([^.!?\n]+[.!?])/gi,
    /(?:The solution is|The fix is|The approach is)\s+([^.!?\n]+[.!?])/gi,
  ];
  
  for (const pattern of patterns) {
    let match;
    while ((match = pattern.exec(response)) !== null) {
      const decision = match[1].trim();
      if (decision.length > 10 && decision.length < 200) {
        decisions.push(decision);
      }
    }
  }
  
  return decisions.slice(0, 5); // Limit to 5 decisions
}

/**
 * Extract code changes mentioned in response
 * @param {string} response - Assistant response text
 * @returns {string[]} List of file paths mentioned
 */
function extractCodeChanges(response) {
  const files = new Set();
  
  // Match file paths
  const filePatterns = [
    /(?:created?|modified?|updated?|edited?|changed?)\s+[`']?([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)[`']?/gi,
    /(?:in|to|from)\s+[`']([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)[`']/gi,
  ];
  
  for (const pattern of filePatterns) {
    let match;
    while ((match = pattern.exec(response)) !== null) {
      const file = match[1];
      if (file && !file.includes('http') && file.includes('.')) {
        files.add(file);
      }
    }
  }
  
  return Array.from(files).slice(0, 10); // Limit to 10 files
}

/**
 * Determine response type
 * @param {string} response - Assistant response text
 * @returns {string} Response type
 */
function determineResponseType(response) {
  const lowerResponse = response.toLowerCase();
  
  if (lowerResponse.includes('error') || lowerResponse.includes('failed') || lowerResponse.includes('issue')) {
    return 'error_resolution';
  }
  if (lowerResponse.includes('created') || lowerResponse.includes('implemented') || lowerResponse.includes('added')) {
    return 'implementation';
  }
  if (lowerResponse.includes('refactored') || lowerResponse.includes('improved') || lowerResponse.includes('optimized')) {
    return 'refactoring';
  }
  if (lowerResponse.includes('explained') || lowerResponse.includes('here\'s how') || lowerResponse.includes('the reason')) {
    return 'explanation';
  }
  if (lowerResponse.includes('found') || lowerResponse.includes('discovered') || lowerResponse.includes('identified')) {
    return 'discovery';
  }
  
  return 'general';
}

/**
 * Calculate importance based on response content
 * @param {string} response - Assistant response text
 * @param {string[]} decisions - Extracted decisions
 * @param {string[]} codeChanges - Extracted code changes
 * @returns {number} Importance score (0-1)
 */
function calculateImportance(response, decisions, codeChanges) {
  let importance = 0.5;
  
  // More decisions = more important
  importance += Math.min(decisions.length * 0.05, 0.15);
  
  // More code changes = more important
  importance += Math.min(codeChanges.length * 0.03, 0.15);
  
  // Longer responses tend to be more substantial
  if (response.length > 2000) importance += 0.1;
  if (response.length > 5000) importance += 0.1;
  
  return Math.min(importance, 1.0);
}

async function handleStop(input) {
  try {
    if (!input) {
      console.error('[stop-hook] No input received');
      outputResponse();
      return;
    }

    const { session_id: kiroSessionId, cwd, transcript_path: transcriptPath } = input;

    if (!kiroSessionId) {
      console.error('[stop-hook] Missing session_id');
      outputResponse();
      return;
    }

    // Get the memory session ID
    const memorySessionId = getMemorySessionId(kiroSessionId);
    if (!memorySessionId) {
      console.error('[stop-hook] No memory session found for Kiro session:', kiroSessionId);
      outputResponse();
      return;
    }

    // Try to read the last assistant message from transcript
    let assistantResponse = '';
    if (transcriptPath) {
      try {
        const fs = require('fs');
        if (fs.existsSync(transcriptPath)) {
          const content = fs.readFileSync(transcriptPath, 'utf-8').trim();
          const lines = content.split('\n');
          
          // Find the last assistant message
          for (let i = lines.length - 1; i >= 0; i--) {
            try {
              const entry = JSON.parse(lines[i]);
              if (entry.type === 'assistant' && entry.message?.content) {
                const msgContent = entry.message.content;
                if (typeof msgContent === 'string') {
                  assistantResponse = msgContent;
                } else if (Array.isArray(msgContent)) {
                  assistantResponse = msgContent
                    .filter(c => c.type === 'text')
                    .map(c => c.text)
                    .join('\n');
                }
                break;
              }
            } catch {
              continue;
            }
          }
        }
      } catch (error) {
        console.error('[stop-hook] Failed to read transcript:', error.message);
      }
    }

    if (!assistantResponse) {
      console.error('[stop-hook] No assistant response found');
      outputResponse();
      return;
    }

    // Extract insights from response
    const decisions = extractDecisions(assistantResponse);
    const codeChanges = extractCodeChanges(assistantResponse);
    const responseType = determineResponseType(assistantResponse);
    const importance = calculateImportance(assistantResponse, decisions, codeChanges);

    // Create summary
    const summary = summarizeText(assistantResponse, 500);

    console.error(`[stop-hook] Capturing response: ${responseType} (importance: ${importance.toFixed(2)})`);

    // Call capture_memory with 'event' action
    await callCaptureMemory({
      action: 'event',
      sessionId: memorySessionId,
      phase: 'Stop',
      type: 'assistant_response',
      content: summary,
      importance: importance,
      tags: [responseType, ...codeChanges.slice(0, 3)],
      metadata: {
        kiroSessionId: kiroSessionId,
        cwd: cwd,
        responseType: responseType,
        decisionsCount: decisions.length,
        codeChangesCount: codeChanges.length,
        decisions: decisions,
        codeChanges: codeChanges,
      },
    });

    outputResponse();
  } catch (error) {
    console.error('[stop-hook] Error:', error.message);
    outputResponse();
  }
}

// Main execution
readStdinInput().then(handleStop);
