# VoiceFlow Development MCP Server

MCP server for automating VoiceFlow development tasks including performance analysis, memory leak detection, security scanning, and more.

## Features

### Available Tools

1. **run_performance_analysis**
   - Swift-based performance analysis
   - Code complexity analysis
   - Performance pattern detection
   - Optimization opportunities

2. **run_memory_leak_detection**
   - Retain cycle detection
   - Memory leak identification
   - Memory management analysis

3. **run_security_analysis**
   - Security vulnerability scanning
   - Best practice checks
   - Security pattern analysis

4. **run_full_analysis**
   - Complete analysis suite
   - Performance + Memory + Security
   - Comprehensive code quality report

5. **run_benchmarks**
   - Performance benchmark execution
   - Metric tracking
   - Performance regression detection

6. **coverage_report**
   - Code coverage analysis
   - Test coverage report
   - Untested code identification

7. **check_actor_isolation**
   - Swift 6 concurrency compliance
   - Actor isolation verification
   - Concurrency safety checks

## Installation

### 1. Install Dependencies

```bash
cd /Users/lukaj/voiceflow/mcp-servers/voiceflow-dev
npm install
```

### 2. Configure Claude Desktop

Add to your Claude Desktop configuration (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "voiceflow-dev": {
      "command": "node",
      "args": ["/Users/lukaj/voiceflow/mcp-servers/voiceflow-dev/index.js"]
    }
  }
}
```

### 3. Restart Claude Desktop

The server will be available after restarting Claude Desktop.

## Usage

In Claude Desktop, you can now use commands like:

- "Run performance analysis on VoiceFlow"
- "Check for memory leaks"
- "Run security scan"
- "Generate coverage report"
- "Check actor isolation compliance"

## Requirements

- Node.js 18.0.0 or higher
- Swift toolchain (for Swift scripts)
- Python 3.x (for Python scripts)
- Xcode Command Line Tools
- VoiceFlow project at `/Users/lukaj/voiceflow`

## Project Structure

```
voiceflow-dev/
├── index.js          # Main MCP server implementation
├── package.json      # Node.js dependencies
└── README.md         # This file
```

## Development

### Testing the Server

```bash
# Run the server directly (for debugging)
node index.js
```

### Logs

Server logs are written to stderr and can be viewed in Claude Desktop's developer console.

## Troubleshooting

### Server Not Starting

- Check Node.js version: `node --version` (should be >= 18.0.0)
- Verify package installation: `npm list @modelcontextprotocol/sdk`
- Check Claude Desktop config path

### Tool Execution Fails

- Verify Swift toolchain: `swift --version`
- Verify Python: `python3 --version`
- Check project path: `/Users/lukaj/voiceflow` should exist
- Ensure scripts are executable

### Permission Issues

```bash
# Make scripts executable
chmod +x /Users/lukaj/voiceflow/Scripts/*.swift
chmod +x /Users/lukaj/voiceflow/Scripts/*.py
```

## License

MIT
