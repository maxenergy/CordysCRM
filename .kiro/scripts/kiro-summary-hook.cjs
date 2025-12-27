#!/usr/bin/env node
/**
 * Kiro Summary Hook - Session End
 *
 * Adapts claude-mem session summary for Kiro IDE.
 * Generates session summary when session ends.
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
 * Request summary generation from worker service
 */
function requestSummary(port, data) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(data);

    const options = {
      hostname: '127.0.0.1',
      port: port,
      path: '/api/sessions/summarize',
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
 * Stop processing spinner (non-critical)
 */
function stopSpinner(port) {
  return new Promise((resolve) => {
    const postData = JSON.stringify({ isProcessing: false });

    const options = {
      hostname: '127.0.0.1',
      port: port,
      path: '/api/processing',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
      timeout: 2000,
    };

    const req = http.request(options, (res) => {
      res.on('data', () => {}); // Drain response
      res.on('end', () => resolve());
    });

    req.on('error', () => resolve()); // Non-critical, ignore errors
    req.on('timeout', () => {
      req.destroy();
      resolve();
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
    const sessionId = process.env.KIRO_SESSION_ID || 'unknown-session';
    const port = getWorkerPort();

    // Read session data from stdin (if available)
    let lastUserMessage = '';
    let lastAssistantMessage = '';

    if (!process.stdin.isTTY) {
      const chunks = [];
      for await (const chunk of process.stdin) {
        chunks.push(chunk);
      }
      const input = Buffer.concat(chunks).toString('utf-8');

      if (input) {
        try {
          const data = JSON.parse(input);
          lastUserMessage = data.last_user_message || data.lastUserMessage || '';
          lastAssistantMessage = data.last_assistant_message || data.lastAssistantMessage || '';
        } catch (error) {
          // If parsing fails, continue without messages
          console.error('[KIRO-HOOK] Failed to parse session data:', error.message);
        }
      }
    }

    // Prepare summary request
    const summaryData = {
      claudeSessionId: sessionId,
      last_user_message: lastUserMessage,
      last_assistant_message: lastAssistantMessage,
      timestamp: new Date().toISOString(),
    };

    // Request summary generation
    try {
      await requestSummary(port, summaryData);
    } catch (error) {
      console.error('[KIRO-HOOK] Summary generation failed:', error.message);
      throw error;
    } finally {
      // Stop spinner (non-critical)
      await stopSpinner(port);
    }

    process.exit(0);
  } catch (error) {
    console.error('[KIRO-HOOK] Error:', error.message);
    process.exit(1);
  }
}

// Run hook
main();
