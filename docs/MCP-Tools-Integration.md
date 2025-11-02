# VoiceFlow MCP Tools Integration

## 🛠️ Available MCP Servers

VoiceFlow uses **3 MCP servers** for development automation:

### 1. XcodeBuildMCP (Essential for Swift)
**Installation:**
```json
// ~/.config/claude/mcp-settings.json
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest"]
    }
  }
}
```

**Available Tools:**
- `xcodebuildmcp__build_project` - Build VoiceFlow for macOS
- `xcodebuildmcp__run_tests` - Execute Swift test suite
- `xcodebuildmcp__swift_package_build` - Build SPM package
- `xcodebuildmcp__swift_package_test` - Test SPM package
- `xcodebuildmcp__list_simulators` - Show available simulators
- `xcodebuildmcp__capture_logs` - Get runtime logs

**VoiceFlow Use Cases:**
```javascript
// Build for release
xcodebuildmcp__build_project({
  project: "VoiceFlow",
  scheme: "VoiceFlow",
  configuration: "Release",
  platform: "macosx"
})

// Run tests after changes
xcodebuildmcp__swift_package_test({
  package: "VoiceFlow",
  filter: "AudioEngineTests"
})
```

### 2. voiceflow-dev (Custom Project Tools)
**Location:** `mcp-servers/voiceflow-dev/`

**Available Tools:**
- `run_performance_analysis` - PerformanceAnalyzer.swift
- `run_memory_leak_detection` - MemoryLeakDetector.swift
- `run_security_analysis` - security_analyzer.py
- `run_full_analysis` - All three analyzers
- `run_benchmarks` - Performance benchmarks
- `coverage_report` - Test coverage
- `check_actor_isolation` - Swift 6 concurrency validation

**Installation:**
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

**Usage:**
```javascript
// Run full analysis before commit
mcp__voiceflow_dev__run_full_analysis()

// Check specific concern
mcp__voiceflow_dev__run_security_analysis()
```

### 3. shadcn UI (Web Dashboard Components)
**Purpose:** Generate UI components for web-based dashboards, admin panels, or companion web apps

**Installation:**
```json
{
  "mcpServers": {
    "shadcn-ui": {
      "command": "npx",
      "args": ["-y", "shadcn-mcp@latest"]
    }
  }
}
```

**Available Tools:**
- `shadcn__add_component` - Add shadcn/ui component
- `shadcn__list_components` - List available components
- `shadcn__init_project` - Initialize shadcn in project

**VoiceFlow Use Cases:**

#### Use Case 1: Performance Dashboard Web App
If you want a web-based performance dashboard:

```javascript
// Initialize shadcn in web directory
shadcn__init_project({
  path: "VoiceFlow/Dashboard-Web",
  style: "default",
  baseColor: "slate"
})

// Add chart components for metrics visualization
shadcn__add_component({
  component: "chart",
  path: "VoiceFlow/Dashboard-Web"
})

// Add data table for detailed metrics
shadcn__add_component({
  component: "data-table",
  path: "VoiceFlow/Dashboard-Web"
})

// Add cards for score displays
shadcn__add_component({
  component: "card",
  path: "VoiceFlow/Dashboard-Web"
})
```

**Result:** Modern React dashboard showing:
- Real-time performance scores
- Memory leak risk charts
- Security issue tables
- Coverage graphs

#### Use Case 2: Admin Panel for Configuration
```javascript
// Add form components
shadcn__add_component({ component: "form" })
shadcn__add_component({ component: "input" })
shadcn__add_component({ component: "select" })
shadcn__add_component({ component: "switch" })

// Create admin panel for:
// - API key management
// - LLM provider configuration
// - Export settings
// - User preferences
```

#### Use Case 3: Documentation Site
```javascript
// Add navigation components
shadcn__add_component({ component: "navigation-menu" })
shadcn__add_component({ component: "tabs" })
shadcn__add_component({ component: "accordion" })

// Build interactive docs with:
// - API reference
// - Code examples
// - Live demos
```

---

## 🎯 Recommended Architecture

### Native macOS App (SwiftUI) - Primary
**Purpose:** Core VoiceFlow application
**Tech Stack:** Swift 6.2, SwiftUI, AppKit
**Tools:** XcodeBuildMCP, voiceflow-dev

### Web Dashboard (React + shadcn) - Optional
**Purpose:** Advanced analytics, team dashboards, admin panels
**Tech Stack:** React, Next.js, shadcn/ui, Tailwind CSS
**Tools:** shadcn-ui MCP

**Project Structure:**
```
voiceflow/
├── VoiceFlow/              # Swift app (main)
├── VoiceFlowTests/
├── Scripts/                # Analysis scripts
├── Dashboard-Web/          # Optional web dashboard
│   ├── app/
│   ├── components/         # shadcn components
│   │   └── ui/
│   ├── lib/
│   └── package.json
└── docs/
```

---

## 🔄 Integration Workflow

### Scenario 1: Build & Test
```
Claude Code → XcodeBuildMCP → Build/Test → voiceflow-dev (analysis)
```

### Scenario 2: Add Feature with Dashboard
```
1. Claude plans feature (orchestrator)
2. Codex generates Swift code
3. XcodeBuildMCP builds and tests
4. shadcn generates dashboard UI for monitoring
5. voiceflow-dev runs analysis
6. Integration agent commits
```

### Scenario 3: Performance Dashboard
```
1. User: "Create web dashboard for performance metrics"
2. shadcn__init_project in Dashboard-Web/
3. shadcn__add_component for charts/tables
4. Codex generates React components that:
   - Fetch from performance_analysis/*.json
   - Display real-time metrics
   - Show historical trends
5. Dashboard runs on localhost:3000
```

---

## 📊 shadcn Components for VoiceFlow

### Recommended Components

**Analytics Dashboard:**
- `chart` - Performance score over time
- `data-table` - Detailed issue lists
- `card` - Metric cards (CPU, Memory, Security)
- `badge` - Severity indicators
- `progress` - Test coverage bars

**Configuration:**
- `form` - Settings management
- `input` - API keys, URLs
- `select` - Provider selection (OpenAI, Anthropic, Deepgram)
- `switch` - Feature toggles
- `slider` - Threshold adjustments

**Navigation:**
- `navigation-menu` - Dashboard sections
- `tabs` - Switch between metrics
- `breadcrumb` - Current location
- `sidebar` - Main navigation

**Data Display:**
- `table` - Test results, issues
- `accordion` - Expandable details
- `dialog` - Detailed issue view
- `tooltip` - Metric explanations

---

## 🚀 Quick Start: Web Dashboard

### Step 1: Initialize (Optional)
```bash
mkdir Dashboard-Web
cd Dashboard-Web
npx create-next-app@latest . --typescript --tailwind --app
```

### Step 2: Add shadcn via MCP
```javascript
// In Claude Code
mcp__shadcn_ui__init_project({
  path: "Dashboard-Web",
  style: "default",
  baseColor: "slate"
})

// Add components
mcp__shadcn_ui__add_component({ component: "chart" })
mcp__shadcn_ui__add_component({ component: "card" })
mcp__shadcn_ui__add_component({ component: "data-table" })
```

### Step 3: Create Dashboard Page
```typescript
// Dashboard-Web/app/page.tsx
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { ChartContainer } from "@/components/ui/chart"

export default function Dashboard() {
  // Fetch performance_analysis/*.json
  const metrics = await fetchMetrics()

  return (
    <div className="grid gap-4 md:grid-cols-3">
      <Card>
        <CardHeader>
          <CardTitle>Performance Score</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold">{metrics.performanceScore}/100</div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Memory Risk</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold">{metrics.memoryRisk}/100</div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Security Score</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold">{metrics.securityScore}/100</div>
        </CardContent>
      </Card>
    </div>
  )
}
```

### Step 4: Run Dashboard
```bash
cd Dashboard-Web
npm run dev
# Open http://localhost:3000
```

---

## 🎯 When to Use Each MCP

| MCP | Use When | Examples |
|-----|----------|----------|
| **XcodeBuildMCP** | Swift/macOS development | Build, test, debug Swift code |
| **voiceflow-dev** | VoiceFlow-specific tasks | Run analysis scripts, benchmarks |
| **shadcn-ui** | Web UI needed | Dashboard, admin panel, docs site |

---

## 📋 Best Practices

### 1. Use MCP for Automation
```javascript
// DON'T: Run commands manually
Bash("swift test")

// DO: Use MCP tools
mcp__xcodebuildmcp__swift_package_test({ package: "VoiceFlow" })
```

### 2. Combine MCPs
```javascript
// Build, test, analyze in sequence
await mcp__xcodebuildmcp__build_project(...)
await mcp__xcodebuildmcp__run_tests(...)
await mcp__voiceflow_dev__run_full_analysis()
```

### 3. Use shadcn for Rapid UI
```javascript
// Instead of writing React from scratch
mcp__shadcn_ui__add_component({ component: "data-table" })
// Then customize the generated component
```

### 4. Error Handling
```javascript
try {
  const result = await mcp__voiceflow_dev__run_security_analysis()
  if (result.security_score < 80) {
    console.warn("Security score below threshold")
  }
} catch (error) {
  console.error("Analysis failed:", error)
}
```

---

## 🔗 MCP Configuration Summary

**Add to:** `~/.config/claude/mcp-settings.json`

```json
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest"]
    },
    "voiceflow-dev": {
      "command": "node",
      "args": ["/Users/lukaj/voiceflow/mcp-servers/voiceflow-dev/index.js"]
    },
    "shadcn-ui": {
      "command": "npx",
      "args": ["-y", "shadcn-mcp@latest"]
    }
  }
}
```

**Restart Claude Code** after adding MCPs.

---

## 🎓 Summary

**3 MCP Servers, Distinct Purposes:**

1. **XcodeBuildMCP** - Swift/Xcode operations
2. **voiceflow-dev** - Custom VoiceFlow analysis tools
3. **shadcn-ui** - Web dashboard UI components (optional)

**No n8n** - All orchestration handled by Claude Code natively.
**Simple, powerful, maintainable.**
