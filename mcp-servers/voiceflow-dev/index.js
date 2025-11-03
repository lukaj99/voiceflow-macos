#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const execAsync = promisify(exec);

// Project root - VoiceFlow repository location
const PROJECT_ROOT = '/Users/lukaj/voiceflow';

// Logging helper
function log(message, level = 'INFO') {
  const timestamp = new Date().toISOString();
  console.error(`[${timestamp}] [${level}] ${message}`);
}

// Execute shell command with proper error handling
async function executeCommand(command, options = {}) {
  log(`Executing: ${command}`);
  try {
    const { stdout, stderr } = await execAsync(command, {
      cwd: PROJECT_ROOT,
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer
      ...options
    });

    if (stderr && !options.ignoreStderr) {
      log(`STDERR: ${stderr}`, 'WARN');
    }

    return {
      success: true,
      stdout: stdout.trim(),
      stderr: stderr.trim()
    };
  } catch (error) {
    log(`Command failed: ${error.message}`, 'ERROR');
    return {
      success: false,
      error: error.message,
      stdout: error.stdout || '',
      stderr: error.stderr || ''
    };
  }
}

// Tool implementations
async function runPerformanceAnalysis() {
  log('Running performance analysis...');
  const result = await executeCommand(
    'swift Scripts/PerformanceAnalyzer.swift',
    { ignoreStderr: true }
  );

  return {
    tool: 'performance_analysis',
    ...result,
    description: 'Swift-based performance analysis of VoiceFlow codebase'
  };
}

async function runMemoryLeakDetection() {
  log('Running memory leak detection...');
  const result = await executeCommand(
    'swift Scripts/MemoryLeakDetector.swift',
    { ignoreStderr: true }
  );

  return {
    tool: 'memory_leak_detection',
    ...result,
    description: 'Memory leak detection and retain cycle analysis'
  };
}

async function runSecurityAnalysis() {
  log('Running security analysis...');
  const result = await executeCommand(
    'python3 Scripts/security_analyzer.py'
  );

  return {
    tool: 'security_analysis',
    ...result,
    description: 'Security vulnerability scanning and best practice checks'
  };
}

async function runFullAnalysis() {
  log('Running full analysis suite...');

  const results = await Promise.allSettled([
    runPerformanceAnalysis(),
    runMemoryLeakDetection(),
    runSecurityAnalysis()
  ]);

  const output = {
    tool: 'full_analysis',
    success: results.every(r => r.status === 'fulfilled' && r.value.success),
    results: results.map((r, idx) => {
      if (r.status === 'fulfilled') {
        return r.value;
      } else {
        return {
          tool: ['performance', 'memory', 'security'][idx],
          success: false,
          error: r.reason.message
        };
      }
    }),
    description: 'Complete analysis suite: performance, memory, and security'
  };

  return output;
}

async function runBenchmarks() {
  log('Running benchmark suite...');
  const result = await executeCommand(
    'swift test --filter VoiceFlowPerformanceTests',
    { ignoreStderr: true }
  );

  return {
    tool: 'benchmarks',
    ...result,
    description: 'Performance benchmark tests execution'
  };
}

async function getCoverageReport() {
  log('Generating coverage report...');

  // Run tests with coverage
  const testResult = await executeCommand(
    'swift test --enable-code-coverage',
    { ignoreStderr: true }
  );

  if (!testResult.success) {
    return {
      tool: 'coverage_report',
      success: false,
      error: 'Test execution failed',
      ...testResult
    };
  }

  // Generate coverage report
  const coverageResult = await executeCommand(
    'xcrun llvm-cov report .build/debug/VoiceFlowPackageTests.xctest/Contents/MacOS/VoiceFlowPackageTests -instr-profile=.build/debug/codecov/default.profdata',
    { ignoreStderr: true }
  );

  return {
    tool: 'coverage_report',
    ...coverageResult,
    description: 'Code coverage analysis report'
  };
}

async function checkActorIsolation() {
  log('Checking actor isolation compliance...');

  // Build with strict concurrency checking
  const result = await executeCommand(
    'swift build -Xswiftc -strict-concurrency=complete',
    { ignoreStderr: true }
  );

  const warnings = result.stderr.match(/warning:.*actor-isolated/gi) || [];
  const errors = result.stderr.match(/error:.*actor-isolated/gi) || [];

  return {
    tool: 'actor_isolation',
    success: errors.length === 0,
    warnings_count: warnings.length,
    errors_count: errors.length,
    warnings: warnings.slice(0, 10), // First 10 warnings
    errors: errors.slice(0, 10), // First 10 errors
    stdout: result.stdout,
    stderr: result.stderr,
    description: 'Swift 6 actor isolation and concurrency compliance check'
  };
}

// Create and configure the MCP server
const server = new Server(
  {
    name: 'voiceflow-dev',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'run_performance_analysis',
        description: 'Run Swift-based performance analysis on VoiceFlow codebase. Analyzes code complexity, performance patterns, and optimization opportunities.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'run_memory_leak_detection',
        description: 'Run memory leak detection to identify retain cycles and memory management issues in VoiceFlow codebase.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'run_security_analysis',
        description: 'Run security vulnerability scanning and best practice checks on VoiceFlow codebase.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'run_full_analysis',
        description: 'Run complete analysis suite (performance + memory + security) on VoiceFlow codebase. Provides comprehensive code quality report.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'run_benchmarks',
        description: 'Execute VoiceFlow performance benchmark tests to measure and track performance metrics.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'coverage_report',
        description: 'Generate code coverage report from test execution. Shows which parts of the codebase are tested.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'check_actor_isolation',
        description: 'Check Swift 6 actor isolation compliance and concurrency safety. Identifies concurrency warnings and errors.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name } = request.params;

  log(`Tool called: ${name}`);

  try {
    let result;

    switch (name) {
      case 'run_performance_analysis':
        result = await runPerformanceAnalysis();
        break;
      case 'run_memory_leak_detection':
        result = await runMemoryLeakDetection();
        break;
      case 'run_security_analysis':
        result = await runSecurityAnalysis();
        break;
      case 'run_full_analysis':
        result = await runFullAnalysis();
        break;
      case 'run_benchmarks':
        result = await runBenchmarks();
        break;
      case 'coverage_report':
        result = await getCoverageReport();
        break;
      case 'check_actor_isolation':
        result = await checkActorIsolation();
        break;
      default:
        throw new Error(`Unknown tool: ${name}`);
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  } catch (error) {
    log(`Tool execution failed: ${error.message}`, 'ERROR');
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: false,
            error: error.message,
            stack: error.stack
          }, null, 2),
        },
      ],
      isError: true,
    };
  }
});

// Start the server
async function main() {
  log('Starting VoiceFlow Development MCP Server...');
  log(`Project root: ${PROJECT_ROOT}`);

  const transport = new StdioServerTransport();
  await server.connect(transport);

  log('Server started and ready for connections');
}

main().catch((error) => {
  log(`Fatal error: ${error.message}`, 'ERROR');
  console.error(error);
  process.exit(1);
});
