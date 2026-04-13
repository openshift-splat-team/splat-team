# MCP Server Configuration

## Overview

**Yes, BotMinter can use MCP (Model Context Protocol) servers!** Claude Code (the coding agent used by BotMinter) has full MCP support for connecting to external data sources like Jira, GitHub, databases, and more.

## What is MCP?

MCP (Model Context Protocol) is Anthropic's standard for connecting AI assistants to external data sources and tools. It provides:
- **Standardized interface** for tools and resources
- **Secure authentication** with external services
- **Real-time data access** during agent execution
- **Tool invocation** from within Claude Code sessions

## Claude Code MCP Support

Claude Code supports MCP servers via:

1. **Command-line flags**
   ```bash
   claude --mcp-config <json-file-or-string>
   ```

2. **Project-scoped configuration**
   - `.mcp.json` file in project root (auto-discovered)
   - Workspace-specific servers

3. **Global configuration**
   - MCP servers added via `claude mcp add`
   - Available to all sessions

4. **Management commands**
   ```bash
   claude mcp list           # List configured servers
   claude mcp add            # Add new server
   claude mcp remove         # Remove server
   claude mcp get <name>     # Get server details
   ```

## JIRA MCP Server Setup

Many of the transferred skills from ai-helpers expect a Jira MCP server to be configured. These skills use MCP tools like:

- `mcp__atlassian__jira_create_issue()` - Create issues
- `mcp__atlassian__jira_search_issues()` - Search with JQL
- `mcp__atlassian__jira_update_issue()` - Update issue fields
- `mcp__atlassian__jira_add_comment()` - Add comments
- `mcp__atlassian__jira_get_issue()` - Fetch issue details

### Option 1: Atlassian Official MCP Server (Recommended)

Check if Atlassian provides an official MCP server:

```bash
# Search for official Jira MCP server
npm search @atlassian/mcp-server-jira

# Or check GitHub
# https://github.com/atlassian
```

If available, install and configure:

```bash
# Install the server
npm install -g @atlassian/mcp-server-jira  # (if it exists)

# Add to Claude Code
claude mcp add jira -- npx @atlassian/mcp-server-jira \
  -e JIRA_URL=https://your-company.atlassian.net \
  -e JIRA_EMAIL=your-email@company.com \
  -e JIRA_API_TOKEN=your-api-token
```

### Option 2: Third-Party Jira MCP Server

Search for community-maintained Jira MCP servers:

```bash
# Example with a hypothetical community server
claude mcp add jira -- npx jira-mcp-server \
  -e JIRA_HOST=https://issues.redhat.com \
  -e JIRA_EMAIL=your-email@redhat.com \
  -e JIRA_API_TOKEN=your-token
```

### Option 3: Custom MCP Server

Build a custom MCP server using the MCP SDK:

**Resources:**
- MCP SDK: https://github.com/modelcontextprotocol
- MCP Specification: https://spec.modelcontextprotocol.io/

**Basic structure:**

```typescript
// jira-mcp-server.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import JiraApi from "jira-client";

const jira = new JiraApi({
  protocol: 'https',
  host: process.env.JIRA_HOST,
  username: process.env.JIRA_EMAIL,
  password: process.env.JIRA_API_TOKEN,
  apiVersion: '3',
  strictSSL: true
});

const server = new Server({
  name: "jira-mcp-server",
  version: "1.0.0",
}, {
  capabilities: {
    tools: {},
  },
});

// Implement tools
server.setRequestHandler("tools/list", async () => ({
  tools: [
    {
      name: "mcp__atlassian__jira_create_issue",
      description: "Create a Jira issue",
      inputSchema: {
        type: "object",
        properties: {
          project_key: { type: "string" },
          summary: { type: "string" },
          description: { type: "string" },
          issue_type: { type: "string" }
        }
      }
    },
    // ... more tools
  ]
}));

server.setRequestHandler("tools/call", async (request) => {
  const { name, arguments: args } = request.params;
  
  if (name === "mcp__atlassian__jira_create_issue") {
    const result = await jira.addNewIssue({
      fields: {
        project: { key: args.project_key },
        summary: args.summary,
        description: args.description,
        issuetype: { name: args.issue_type }
      }
    });
    return { content: [{ type: "text", text: JSON.stringify(result) }] };
  }
  
  // Handle other tools...
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

**Add to Claude Code:**

```bash
claude mcp add jira -- node jira-mcp-server.js \
  -e JIRA_HOST=issues.redhat.com \
  -e JIRA_EMAIL=your-email@redhat.com \
  -e JIRA_API_TOKEN=your-token
```

### Option 4: HTTP/SSE MCP Server

For hosted MCP servers:

```bash
claude mcp add --transport http jira https://your-mcp-server.com/mcp \
  --header "Authorization: Bearer your-token"
```

## Workspace-Scoped MCP Configuration

To configure MCP servers for a specific BotMinter workspace, create `.mcp.json` in the workspace root:

**Location:** `/home/rvanderp/.botminter/workspaces/splat/superman-atlas/.mcp.json`

```json
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["@atlassian/mcp-server-jira"],
      "env": {
        "JIRA_URL": "https://issues.redhat.com",
        "JIRA_EMAIL": "your-email@redhat.com",
        "JIRA_API_TOKEN": "your-token"
      }
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_..."
      }
    }
  }
}
```

**Benefits:**
- Servers only active in this workspace
- Configuration versioned with workspace
- Different projects can use different servers
- Secure - credentials in `.mcp.json` (add to `.gitignore`)

## Team-Level MCP Configuration

For team-wide MCP servers shared across all workspaces, configure in the team repo:

**Location:** `team/coding-agent/.mcp.json`

This would be symlinked or copied to each workspace during `bm teams sync`.

## Environment Variables

Store sensitive credentials in environment variables instead of hardcoding:

```bash
# In ~/.bashrc or ~/.zshrc
export JIRA_URL="https://issues.redhat.com"
export JIRA_EMAIL="your-email@redhat.com"
export JIRA_API_TOKEN="your-jira-api-token"
export GITHUB_TOKEN="ghp_your_github_token"
```

Then reference in `.mcp.json`:

```json
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["jira-mcp-server"],
      "env": {
        "JIRA_URL": "${JIRA_URL}",
        "JIRA_EMAIL": "${JIRA_EMAIL}",
        "JIRA_API_TOKEN": "${JIRA_API_TOKEN}"
      }
    }
  }
}
```

## Getting Jira API Token

1. **Log into Jira** (e.g., https://issues.redhat.com)
2. **Go to Profile → Security**
3. **Create API Token**
   - Name: "BotMinter MCP Server"
   - Copy token immediately (won't be shown again)
4. **Store securely** in environment variable

## Verifying MCP Server

Test the MCP server connection:

```bash
# List configured servers
claude mcp list

# Get details about a specific server
claude mcp get jira

# Test in a Claude Code session
claude
> /mcp tools  # Should show jira tools
> /mcp call jira mcp__atlassian__jira_search_issues jql="project = OCPBUGS AND status = Open" max_results=5
```

## Skills That Use MCP

The following transferred skills expect MCP Jira access:

### JIRA Issue Management (18 skills)
- `create-bug` - Create bug reports
- `create-epic` - Create epics
- `create-feature` - Create features
- `create-story` - Create stories
- `create-task` - Create tasks
- `create-feature-request` - Create feature requests
- `jira-doc-generator` - Generate documentation from issues
- `generate-enhancement` - Generate OpenShift enhancements from epics
- `extract-prs` - Extract PR links from issues
- `status-analysis` - Analyze issue activity
- `categorize-activity-type` - Categorize issues by activity type

### JIRA Integration Skills
- `jira-validate-blockers` - Validate release blockers
- `jira-issues-by-component` - List issues by component
- `create-release-note` - Generate release notes

### SDLC Skills (depend on JIRA)
- `phase-design` - Create implementation specification (reads epic)
- `phase-enhancement` - Generate enhancement proposals (reads epic/feature)
- `phase-completion` - Update Jira on completion
- `sdlc-state-yaml` - SDLC state management (tracks Jira issues)

### CI Skills (optional JIRA integration)
- `triage-regression` - Create/update Component Readiness triage documents
- `stage-payload-reverts` - Create TRT JIRA bugs for payload reverts
- `set-release-blocker` - Set Release Blocker field on JIRA issue

## Fallback: Direct API Access

If MCP is not available, some skills support fallback to direct Jira API access via curl:

```bash
# Skills reference this pattern
curl -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "https://issues.redhat.com/rest/api/3/issue/OCPBUGS-12345"
```

Skills that mention "CLI Fallback Reference" in their prerequisites support this mode.

## Alternative: GitHub Issues Only

If Jira MCP is not available, you can use GitHub Issues for work tracking:

**Skills that work with GitHub Issues:**
- `gh` - GitHub Projects v2 workflow (already configured)
- `board-scanner` - Scans GitHub Projects board
- `status-workflow` - GitHub issue status transitions

**Limitations:**
- No access to corporate Jira for upstream work
- Cannot pull requirements from Jira epics/features
- Enhancement generation from Jira won't work

## Recommended Setup for BotMinter

For the splat team workspace, recommended MCP servers:

1. **Jira** - For reading OCPBUGS, OCPSTRAT, CNTRLPLANE issues
2. **GitHub** - For OpenShift org access (if needed beyond `gh` CLI)
3. **Sippy** - For OpenShift CI metrics (if available as MCP)

**Priority: Jira MCP Server** - Most transferred skills depend on this for full functionality.

## Troubleshooting

### Server Not Listed

```bash
claude mcp list
# Shows: "No MCP servers configured"
```

**Solution:** Add the server first:
```bash
claude mcp add jira -- npx jira-mcp-server
```

### Authentication Errors

```text
Error: Jira authentication failed
```

**Solutions:**
1. Verify API token is valid
2. Check email matches Jira account
3. Ensure token has required permissions
4. Test with curl:
   ```bash
   curl -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
     https://issues.redhat.com/rest/api/3/myself
   ```

### Tools Not Available

In Claude session, tools don't appear:

**Solutions:**
1. Restart Claude Code session
2. Verify server is running: `claude mcp get jira`
3. Check server logs for errors
4. Use `--mcp-debug` flag for verbose output

### Workspace Trust Dialog

When using `.mcp.json` in project:

**Solution:** Approve the workspace when prompted. Only use `.mcp.json` in directories you trust.

## Security Considerations

1. **Never commit API tokens** - Use environment variables or `.gitignore` the config
2. **Use scoped tokens** - Jira API tokens should have minimal required permissions
3. **Workspace trust** - Only approve `.mcp.json` in trusted directories
4. **Token rotation** - Rotate API tokens periodically
5. **Principle of least privilege** - MCP server should only have read/write access needed

## Next Steps

1. **Determine Jira access requirements** - Which Jira projects need access?
2. **Choose MCP server option** - Official, third-party, or custom?
3. **Generate API token** - From Jira profile settings
4. **Configure MCP server** - Global or workspace-scoped
5. **Test configuration** - Verify tools are available
6. **Update workspace** - Add `.mcp.json` if workspace-scoped
7. **Document for team** - Share setup instructions with other team members

## References

- **MCP Specification**: https://spec.modelcontextprotocol.io/
- **MCP SDK**: https://github.com/modelcontextprotocol
- **Claude Code MCP Docs**: `claude mcp --help`
- **Jira REST API**: https://developer.atlassian.com/cloud/jira/platform/rest/v3/
- **Skills expecting MCP**: See `knowledge/transferred-skills.md` JIRA section
