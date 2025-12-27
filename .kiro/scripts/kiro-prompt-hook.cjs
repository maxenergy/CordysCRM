#!/usr/bin/env node
/**
 * Kiro Prompt Hook - User Prompt Submit
 *
 * Adapts claude-mem session management for Kiro IDE.
 * Creates or updates session record when user submits a prompt.
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
 * Get worker port from settings (same as context hook)
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
 * Get project name from workspace path
 */
function getProjectName(workspacePath) {
  if (!workspacePath || workspacePath.trim() === '') {
    return 'unknown-project';
  }

  const basename = path.basename(workspacePath);
  if (basename === '') {
    if (process.platform === 'win32') {
      const match = workspacePath.match(/^([A-Z]):\\/i);
      if (match) {
        return `drive-${match[1].toUpperCase()}`;
      }
    }
    return 'unknown-project';
  }

  return basename;
}

/**
 * Send prompt to worker service
 */
function sendPrompt(port, project, sessionId, prompt) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      project,
      claudeSessionId: sessionId,
      prompt,
      timestamp: new Date().toISOString(),
    });

    const options = {
      hostname: '127.0.0.1',
      port: port,
      path: '/api/sessions/init',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
      timeout: TIMEOUT_MS,
    };

    const req = http.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode === 200 || res.statusCode === 201) {
          resolve(data);
        } else {
          reject(new Error(`Worker returned status ${res.statusCode}: ${data}`));
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
    const project = getProjectName(workspacePath);
    const port = getWorkerPort();

    // Get prompt from stdin or environment
    let prompt = '';
    if (process.stdin.isTTY) {
      prompt = process.argv[2] || '';
    } else {
      // Read from stdin
      const chunks = [];
      for await (const chunk of process.stdin) {
        chunks.push(chunk);
      }
      const input = Buffer.concat(chunks).toString('utf-8');
      
      try {
        const parsed = JSON.parse(input);
        prompt = parsed.prompt || parsed.message || '';
      } catch {
        prompt = input;
      }
    }

    if (!prompt) {
      console.error('[KIRO-HOOK] No prompt provided');
      process.exit(1);
    }

    // Send prompt to worker
    await sendPrompt(port, project, sessionId, prompt);
    
    process.exit(0);
  } catch (error) {
    console.error('[KIRO-HOOK] Error:', error.message);
    process.exit(1);
  }
}

// Run hook
main();
