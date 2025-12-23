/**
 * Memory Client - Shared utilities for memory hooks
 * 
 * Provides functions to interact with the memorymcp MCP server
 * via HTTP API calls.
 */

const fs = require('fs');
const path = require('path');
const http = require('http');

// Configuration
const CONFIG = {
  MCP_HOST: process.env.MEMORYMCP_HOST || '127.0.0.1',
  MCP_PORT: parseInt(process.env.MEMORYMCP_PORT || '3000', 10),
  STATE_DIR: path.join(process.env.HOME || process.env.USERPROFILE || '', '.memorymcp'),
  STATE_FILE: 'memory-sessions.json',
  TIMEOUT: 10000,
};

/**
 * Get the state file path
 */
function getStateFilePath() {
  return path.join(CONFIG.STATE_DIR, CONFIG.STATE_FILE);
}

/**
 * Ensure state directory exists
 */
function ensureStateDir() {
  if (!fs.existsSync(CONFIG.STATE_DIR)) {
    fs.mkdirSync(CONFIG.STATE_DIR, { recursive: true });
  }
}

/**
 * Load session state from file
 * @returns {Object} Session state mapping { kiroSessionId: memorySessionId }
 */
function loadSessionState() {
  try {
    const statePath = getStateFilePath();
    if (fs.existsSync(statePath)) {
      const data = fs.readFileSync(statePath, 'utf-8');
      return JSON.parse(data);
    }
  } catch (error) {
    console.error('[memory-client] Failed to load session state:', error.message);
  }
  return {};
}

/**
 * Save session state to file
 * @param {Object} state - Session state mapping
 */
function saveSessionState(state) {
  try {
    ensureStateDir();
    const statePath = getStateFilePath();
    fs.writeFileSync(statePath, JSON.stringify(state, null, 2), 'utf-8');
  } catch (error) {
    console.error('[memory-client] Failed to save session state:', error.message);
  }
}

/**
 * Get memory session ID for a Kiro session
 * @param {string} kiroSessionId - Kiro session ID
 * @returns {string|null} Memory session ID or null
 */
function getMemorySessionId(kiroSessionId) {
  const state = loadSessionState();
  const entry = state[kiroSessionId];
  if (!entry) return null;
  // Support both old string format and new object format
  if (typeof entry === 'string') return entry;
  return entry.sessionId || null;
}

/**
 * Set memory session ID for a Kiro session
 * @param {string} kiroSessionId - Kiro session ID
 * @param {string} memorySessionId - Memory session ID
 */
function setMemorySessionId(kiroSessionId, memorySessionId) {
  const state = loadSessionState();
  state[kiroSessionId] = {
    sessionId: memorySessionId,
    createdAt: new Date().toISOString(),
  };
  saveSessionState(state);
}

/**
 * Generate a deterministic session ID based on Kiro session
 * @param {string} kiroSessionId - Kiro session ID
 * @param {string} projectName - Project name
 * @returns {string} Generated memory session ID
 */
function generateMemorySessionId(kiroSessionId, projectName) {
  const crypto = require('crypto');
  const timestamp = Date.now();
  const hash = crypto.createHash('sha256')
    .update(`${kiroSessionId}-${projectName}-${timestamp}`)
    .digest('hex')
    .slice(0, 12);
  return `mem-${hash}`;
}

/**
 * Remove memory session ID for a Kiro session
 * @param {string} kiroSessionId - Kiro session ID
 */
function removeMemorySessionId(kiroSessionId) {
  const state = loadSessionState();
  delete state[kiroSessionId];
  saveSessionState(state);
}

/**
 * Extract project name from cwd
 * @param {string} cwd - Current working directory
 * @returns {string} Project name
 */
function extractProjectName(cwd) {
  if (!cwd || cwd.trim() === '') {
    return 'unknown-project';
  }
  const basename = path.basename(cwd);
  if (basename === '') {
    // Root directory
    if (process.platform === 'win32') {
      const match = cwd.match(/^([A-Z]):\\/i);
      if (match) {
        return `drive-${match[1].toUpperCase()}`;
      }
    }
    return 'unknown-project';
  }
  return basename;
}

/**
 * Make HTTP request to MCP server
 * @param {string} method - HTTP method
 * @param {string} path - Request path
 * @param {Object} body - Request body
 * @returns {Promise<Object>} Response data
 */
function makeRequest(method, requestPath, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: CONFIG.MCP_HOST,
      port: CONFIG.MCP_PORT,
      path: requestPath,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: CONFIG.TIMEOUT,
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${parsed.error || data}`));
          }
        } catch (e) {
          reject(new Error(`Failed to parse response: ${data}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

/**
 * Call capture_memory MCP tool
 * @param {Object} params - Tool parameters
 * @returns {Promise<Object>} Tool result
 */
async function callCaptureMemory(params) {
  // For now, we'll use direct service calls since MCP tools
  // are typically called through the MCP protocol.
  // In a real implementation, this would use the MCP client SDK.
  
  // Fallback: Write to a queue file for the MCP server to process
  const queueDir = path.join(CONFIG.STATE_DIR, 'queue');
  ensureStateDir();
  if (!fs.existsSync(queueDir)) {
    fs.mkdirSync(queueDir, { recursive: true });
  }
  
  const queueFile = path.join(queueDir, `${Date.now()}-${Math.random().toString(36).slice(2)}.json`);
  fs.writeFileSync(queueFile, JSON.stringify({
    tool: 'capture_memory',
    params: params,
    timestamp: new Date().toISOString(),
  }), 'utf-8');
  
  return { queued: true, file: queueFile };
}

/**
 * Read input from stdin
 * @returns {Promise<Object|null>} Parsed JSON input or null
 */
function readStdinInput() {
  return new Promise((resolve) => {
    if (process.stdin.isTTY) {
      resolve(null);
      return;
    }

    let data = '';
    process.stdin.setEncoding('utf-8');
    process.stdin.on('data', (chunk) => {
      data += chunk;
    });
    process.stdin.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : null);
      } catch (e) {
        console.error('[memory-client] Failed to parse stdin:', e.message);
        resolve(null);
      }
    });
  });
}

/**
 * Output hook response
 * @param {boolean} continueExecution - Whether to continue execution
 * @param {boolean} suppressOutput - Whether to suppress output
 */
function outputResponse(continueExecution = true, suppressOutput = true) {
  console.log(JSON.stringify({
    continue: continueExecution,
    suppressOutput: suppressOutput,
  }));
}

/**
 * Summarize text to a maximum length
 * @param {string} text - Text to summarize
 * @param {number} maxLength - Maximum length
 * @returns {string} Summarized text
 */
function summarizeText(text, maxLength = 500) {
  if (!text) return '';
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength - 3) + '...';
}

module.exports = {
  CONFIG,
  loadSessionState,
  saveSessionState,
  getMemorySessionId,
  setMemorySessionId,
  removeMemorySessionId,
  generateMemorySessionId,
  extractProjectName,
  makeRequest,
  callCaptureMemory,
  readStdinInput,
  outputResponse,
  summarizeText,
};
