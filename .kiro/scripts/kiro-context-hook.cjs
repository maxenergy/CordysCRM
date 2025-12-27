#!/usr/bin/env node
/**
 * Kiro Context Hook - Session Start
 *
 * Adapts claude-mem context injection for Kiro IDE.
 * Calls worker service to generate context from past observations.
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
    // Try workspace settings first
    const workspacePath = process.env.KIRO_WORKSPACE || process.cwd();
    const workspaceSettingsPath = path.join(workspacePath, '.kiro', 'settings', 'claude-mem.json');
    
    if (fs.existsSync(workspaceSettingsPath)) {
      const settings = JSON.parse(fs.readFileSync(workspaceSettingsPath, 'utf-8'));
      if (settings.CLAUDE_MEM_WORKER_PORT) {
        return parseInt(settings.CLAUDE_MEM_WORKER_PORT, 10);
      }
    }

    // Try user Kiro settings
    const userKiroSettingsPath = path.join(os.homedir(), '.kiro', 'settings', 'claude-mem.json');
    if (fs.existsSync(userKiroSettingsPath)) {
      const settings = JSON.parse(fs.readFileSync(userKiroSettingsPath, 'utf-8'));
      if (settings.CLAUDE_MEM_WORKER_PORT) {
        return parseInt(settings.CLAUDE_MEM_WORKER_PORT, 10);
      }
    }

    // Try legacy settings
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
    // Handle root directory
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
 * Check if worker is running
 */
function checkWorkerHealth(port) {
  return new Promise((resolve) => {
    const req = http.get(
      {
        hostname: '127.0.0.1',
        port: port,
        path: '/api/readiness',
        timeout: 2000,
      },
      (res) => {
        resolve(res.statusCode === 200);
      }
    );

    req.on('error', () => resolve(false));
    req.on('timeout', () => {
      req.destroy();
      resolve(false);
    });
  });
}

/**
 * Fetch context from worker service
 */
function fetchContext(port, project) {
  return new Promise((resolve, reject) => {
    const url = `/api/context/inject?project=${encodeURIComponent(project)}`;
    
    const req = http.get(
      {
        hostname: '127.0.0.1',
        port: port,
        path: url,
        timeout: TIMEOUT_MS,
      },
      (res) => {
        let data = '';

        res.on('data', (chunk) => {
          data += chunk;
        });

        res.on('end', () => {
          if (res.statusCode === 200) {
            resolve(data.trim());
          } else {
            reject(new Error(`Worker returned status ${res.statusCode}: ${data}`));
          }
        });
      }
    );

    req.on('error', (error) => {
      reject(new Error(`Failed to connect to worker: ${error.message}`));
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request to worker timed out'));
    });
  });
}

/**
 * Main hook function
 */
async function main() {
  try {
    // Get workspace path from Kiro environment
    const workspacePath = process.env.KIRO_WORKSPACE || process.cwd();
    const project = getProjectName(workspacePath);
    const port = getWorkerPort();

    // Check if worker is running
    const isHealthy = await checkWorkerHealth(port);
    if (!isHealthy) {
      console.error(`[KIRO-HOOK] Worker service is not running on port ${port}`);
      console.error('[KIRO-HOOK] Please start the worker service: claude-mem restart');
      process.exit(1);
    }

    // Fetch context
    const context = await fetchContext(port, project);

    // Output context for Kiro
    console.log(context);
    process.exit(0);
  } catch (error) {
    console.error('[KIRO-HOOK] Error:', error.message);
    process.exit(1);
  }
}

// Run hook
main();
