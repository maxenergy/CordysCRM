#!/usr/bin/env node
/**
 * Kiro Tool Hook - Tool Execution
 *
 * Adapts claude-mem observation capture for Kiro IDE.
 * Captures tool usage as observations when tools are executed.
 * 
 * Cross-Platform Compatibility:
 * - Uses path.join() for platform-appropriate path separators
 * - Uses os.homedir() for cross-platform home directory
 * - HTTP requests work identically on all platforms
 * - No console window issues (Node.js handles this)
 */

const http = require('http');
const path = require('path');
const fs = require('fs');
const os = require('os');

// Configuration
const DEFAULT_PORT = 37777;
const TIMEOUT_MS = 30000;

/**
 * Get worker port from settings
 */
function getWorkerPort() {
  try {
    const workspacePath = process.env.KIRO_WORKSPACE || process.cwd();
    const workspaceSettingsPath = path.join(workspacePath, '.kiro', 'settings', 'claude-mem.json');
    
    if (fs.existsSync(workspaceSettingsPath)) {
      const settings = JSON.parse(fs.readFileSync(workspaceSettingsPath, 'utf-8'));
      if (settings.CLAUDE_MEM_WORKER_PORT) {
        return parseInt(settings.CLAUDE_MEM_WORKER_PORT, 10);
      }
    }

    const userKiroSettingsPath = path.join(os.homedir(), '.kiro', 'settings', 'claude-mem.json');
    if (fs.existsSync(userKiroSettingsPath)) {
      const settings = JSON.parse(fs.readFileSync(userKiroSettingsPath, 'utf-8'));
      if (settings.CLAUDE_MEM_WORKER_PORT) {
        return parseInt(settings.CLAUDE_MEM_WORKER_PORT, 10);
      }
    }

    const legacySettingsPath = path.join(os.homedir(), '.claude-mem', 'settings.json');
    if (fs.existsSync(legacySettingsPath)) {
      const settings = JSON.parse(fs.readFileSync(legacySettingsPath, 'utf-8'));
      if (settings.CLAUDE_MEM_WORKER_PORT) {
        return parseInt(settings.CLAUDE_MEM_WORKER_PORT, 10);
      }
    }
  } catch (error) {
    console.error('[KIRO-HOOK] Failed to load settings:', error.message);
  }

  return DEFAULT_PORT;
}

/**
 * Send observation to worker service
 */
function sendObservation(port, data) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(data);

    const options = {
      hostname: '127.0.0.1',
      port: port,
      path: '/api/sessions/observations',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
      timeout: TIMEOUT_MS,
    };

    const req = http.request(options, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
      });

      res.on('end', () => {
        if (res.statusCode === 200 || res.statusCode === 201) {
          resolve(responseData);
        } else {
          reject(new Error(`Worker returned status ${res.statusCode}: ${responseData}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(new Error(`Failed to connect to worker: ${error.message}`));
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request to worker timed out'));
    });

    req.write(postData);
    req.end();
  });
}

/**
 * Main hook function
 */
async function main() {
  try {
    // Get event data from Kiro
    const workspacePath = process.env.KIRO_WORKSPACE || process.cwd();
    const sessionId = process.env.KIRO_SESSION_ID || 'unknown-session';
    const port = getWorkerPort();

    // Read tool execution data from stdin
    let input = '';
    if (!process.stdin.isTTY) {
      const chunks = [];
      for await (const chunk of process.stdin) {
        chunks.push(chunk);
      }
      input = Buffer.concat(chunks).toString('utf-8');
    }

    if (!input) {
      console.error('[KIRO-HOOK] No tool execution data provided');
      process.exit(1);
    }

    // Parse tool execution data
    let toolData;
    try {
      toolData = JSON.parse(input);
    } catch (error) {
      console.error('[KIRO-HOOK] Failed to parse tool data:', error.message);
      process.exit(1);
    }

    // Extract tool information
    const toolName = toolData.tool_name || toolData.toolName || 'UnknownTool';
    const toolInput = toolData.tool_input || toolData.toolInput || toolData.input || {};
    const toolResponse = toolData.tool_response || toolData.toolResponse || toolData.response || {};

    // Validate required fields
    if (!workspacePath) {
      console.error('[KIRO-HOOK] Missing workspace path');
      process.exit(1);
    }

    // Prepare observation data
    const observationData = {
      claudeSessionId: sessionId,
      tool_name: toolName,
      tool_input: toolInput,
      tool_response: toolResponse,
      cwd: workspacePath,
      timestamp: new Date().toISOString(),
    };

    // Send observation to worker
    await sendObservation(port, observationData);
    
    process.exit(0);
  } catch (error) {
    console.error('[KIRO-HOOK] Error:', error.message);
    process.exit(1);
  }
}

// Run hook
main();
