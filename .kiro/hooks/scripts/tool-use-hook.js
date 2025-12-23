#!/usr/bin/env node
/**
 * Tool Use Hook
 * 
 * Captures tool observations after tool execution.
 * 
 * Requirements: 5.3 - WHEN PostToolUse event fires, THE Memory_System SHALL capture the tool observation
 * Requirements: 8.2 - THE Memory_System SHALL NOT store raw tool inputs/outputs, only summaries
 */

const {
  readStdinInput,
  outputResponse,
  getMemorySessionId,
  callCaptureMemory,
  summarizeText,
} = require('./shared/memory-client.js');

// Tools to skip (low-value for memory)
const SKIP_TOOLS = new Set([
  'ListMcpResourcesTool',
  'SlashCommand',
  'Skill',
  'TodoWrite',
  'AskUserQuestion',
]);

/**
 * Format tool input for summary
 */
function formatToolInput(toolName, toolInput) {
  if (!toolInput) return 'No input';
  
  try {
    const input = typeof toolInput === 'string' ? JSON.parse(toolInput) : toolInput;
    
    // Format based on tool type
    if (toolName === 'Bash' && input.command) {
      return `Command: ${summarizeText(input.command, 200)}`;
    }
    if (input.file_path) {
      return `File: ${input.file_path}`;
    }
    if (input.pattern) {
      return `Pattern: ${input.pattern}`;
    }
    if (input.query) {
      return `Query: ${summarizeText(input.query, 200)}`;
    }
    if (input.url) {
      return `URL: ${input.url}`;
    }
    
    // Generic summary
    const keys = Object.keys(input);
    if (keys.length === 0) return 'Empty input';
    if (keys.length <= 3) {
      return keys.map(k => `${k}: ${summarizeText(String(input[k]), 100)}`).join(', ');
    }
    return `${keys.length} parameters: ${keys.slice(0, 3).join(', ')}...`;
  } catch (e) {
    return summarizeText(String(toolInput), 200);
  }
}

/**
 * Format tool response for summary
 */
function formatToolResponse(toolName, toolResponse) {
  if (!toolResponse) return 'No response';
  
  try {
    const response = typeof toolResponse === 'string' ? toolResponse : JSON.stringify(toolResponse);
    
    // Check for error indicators
    if (response.toLowerCase().includes('error') || response.toLowerCase().includes('failed')) {
      return `Error: ${summarizeText(response, 300)}`;
    }
    
    // Summarize response
    return summarizeText(response, 300);
  } catch (e) {
    return summarizeText(String(toolResponse), 300);
  }
}

/**
 * Determine if tool execution was successful
 */
function determineStatus(toolResponse) {
  if (!toolResponse) return 'success';
  
  const responseStr = typeof toolResponse === 'string' ? toolResponse : JSON.stringify(toolResponse);
  const lowerResponse = responseStr.toLowerCase();
  
  if (lowerResponse.includes('error') || 
      lowerResponse.includes('failed') || 
      lowerResponse.includes('exception') ||
      lowerResponse.includes('traceback')) {
    return 'error';
  }
  
  return 'success';
}

async function handleToolUse(input) {
  try {
    if (!input) {
      console.error('[tool-use-hook] No input received');
      outputResponse();
      return;
    }

    const { 
      session_id: kiroSessionId, 
      cwd, 
      tool_name: toolName, 
      tool_input: toolInput, 
      tool_response: toolResponse 
    } = input;

    if (!kiroSessionId) {
      console.error('[tool-use-hook] Missing session_id');
      outputResponse();
      return;
    }

    if (!toolName) {
      console.error('[tool-use-hook] Missing tool_name');
      outputResponse();
      return;
    }

    // Skip low-value tools
    if (SKIP_TOOLS.has(toolName)) {
      console.error(`[tool-use-hook] Skipping low-value tool: ${toolName}`);
      outputResponse();
      return;
    }

    // Get the memory session ID
    const memorySessionId = getMemorySessionId(kiroSessionId);
    if (!memorySessionId) {
      console.error('[tool-use-hook] No memory session found for Kiro session:', kiroSessionId);
      outputResponse();
      return;
    }

    // Create summaries (Requirements 8.2: only store summaries)
    const inputSummary = formatToolInput(toolName, toolInput);
    const outputSummary = formatToolResponse(toolName, toolResponse);
    const status = determineStatus(toolResponse);

    // Determine importance
    let importance = 0.5;
    if (status === 'error') importance += 0.25; // Errors are learning opportunities
    if (toolName === 'Bash') importance += 0.1;
    if (toolName.includes('Write') || toolName.includes('Edit')) importance += 0.1;
    importance = Math.min(importance, 1.0);

    console.error(`[tool-use-hook] Capturing tool: ${toolName} (${status}, importance: ${importance.toFixed(2)})`);

    // Call capture_memory with 'event' action
    await callCaptureMemory({
      action: 'event',
      sessionId: memorySessionId,
      phase: 'PostToolUse',
      type: 'tool_observation',
      toolObservation: {
        toolName: toolName,
        inputSummary: inputSummary,
        outputSummary: outputSummary,
        status: status,
        errorMessage: status === 'error' ? outputSummary : undefined,
      },
      importance: importance,
      tags: [toolName, status],
      metadata: {
        kiroSessionId: kiroSessionId,
        cwd: cwd,
      },
    });

    outputResponse();
  } catch (error) {
    console.error('[tool-use-hook] Error:', error.message);
    outputResponse();
  }
}

// Main execution
readStdinInput().then(handleToolUse);
