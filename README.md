# Plane Kanban + MCP Self-Hosted Setup

A self-contained Docker Compose prototype and production deployment stack for [Plane Community Edition](https://github.com/makeplane/plane) (`makeplane/plane-aio-community:stable`) integrated with PostgreSQL, Redis, RabbitMQ, Chainguard MinIO object storage, and the Plane Model Context Protocol (`plane-mcp`) agent server.

## 1. Quick Start (Local `127.0.0.1` Prototype)

Clone the repository and start the stack. It runs out of the box on `127.0.0.1:8085` with zero configuration required:

```bash
git clone https://github.com/adamoutler/plane-kanban-setup.git ~/git/plane-kanban-setup
cd ~/git/plane-kanban-setup
docker compose up -d
```

Wait roughly 60 to 90 seconds on the first boot for database migrations (`migrator`) and service initialization to complete, then access:

- **Plane Web UI:** `http://127.0.0.1:8085`
- **Plane Instance Admin (God Mode):** `http://127.0.0.1:8085/god-mode/`
- **Plane Agent MCP Endpoint:** `http://127.0.0.1:8085/mcp` (also routed at `http://127.0.0.1:8085/mcp/agent/api-key/mcp`)
- **MinIO Console:** `http://127.0.0.1:9001` (default local credentials: `minioadmin` / `minioadmin`)

You can verify that the API has finished migrating by running:

```bash
curl -s http://127.0.0.1:8085/api/instances/
```

---

## 2. First-Time Instance, Workspace, and API Token Setup

### Step 1: Register the Instance Administrator
1. Open `http://127.0.0.1:8085/god-mode/` (or `http://127.0.0.1:8085`, which redirects to `/god-mode/` on first boot).
2. Complete the **Setup your Plane Instance** form (First name, Last name, Email, Company name, Password) and click **Continue**.
3. You will land on the God Mode instance settings page (`http://127.0.0.1:8085/god-mode/general/`).

### Step 2: Create a Workspace and Project
1. Click **Create workspace** (or navigate to `http://127.0.0.1:8085/`) and sign in with your administrator email and password.
2. Complete your user profile and create a new workspace (for example, `my-workspace`).
   - Note the **Workspace Slug** shown in the URL (`http://127.0.0.1:8085/<workspace-slug>/...`). You will use this as `PLANE_SLUG` / `X-Workspace-slug`.
3. Create at least one **Project** inside the workspace (for example, name `Test Project` with project identifier `TEST`).
   - Ensure the project has workflow states across the standard groups (`Backlog`, `Todo`, `In Progress`, `Done`, `Cancelled`), which Plane creates by default.

### Step 3: Generate a Personal Access Token (`PLANE_API_KEY`)
1. In the Plane Web UI (`http://127.0.0.1:8085`), click your profile avatar and open **Profile Settings -> API Tokens** (or Workspace Settings -> API Tokens).
2. Click **Add API token**, give it a label (e.g., `agent-mcp`), and copy the generated token (`plane_api_...`).

---

## 3. Configuring AI Agents and the Kanban Extension

Caddy routes `http://127.0.0.1:8085/mcp` directly to the 7-tool Agent MCP server (`plane-mcp:8211/agent/api-key/mcp`), while preserving `/mcp/*` subpaths (such as `/mcp/agent/api-key/mcp` and `/mcp/http/api-key/mcp`).

### Option A: Gemini CLI Kanban Agent Extension (`.gemini/.env`)

If you use the Gemini CLI Kanban Agent extension (`plane-agent`), set `PLANE_URL` and `PLANE_API_KEY` globally in `~/.bashrc` (or locally in `.gemini/.env`) and set `PLANE_SLUG` per project in `.gemini/.env`:

```dotenv
# .gemini/.env (inside your project workspace)
PLANE_SLUG=your-workspace-slug
PLANE_URL=http://127.0.0.1:8085
PLANE_API_KEY=plane_api_your_generated_token_here
```

### Option B: Direct MCP Client Configuration (`mcp_config.json`)

For any MCP client that supports Streamable HTTP with custom headers:

```json
{
  "mcpServers": {
    "plane-kanban": {
      "serverUrl": "http://127.0.0.1:8085/mcp",
      "headers": {
        "Authorization": "Bearer plane_api_your_generated_token_here",
        "X-Workspace-slug": "your-workspace-slug"
      }
    }
  }
}
```

### Exposed Agent MCP Tools (7 Tools)

1. `search_tickets`: Search and filter tickets by `project_slug`, `query`, `labels`, `priority`, `states`, or `assignees`.
2. `read_ticket`: Read ticket details, description, and comments by sequence ID (e.g., `TEST-1`).
3. `create_ticket`: Create a new ticket in a project (`project_slug`, `title`, `description`, `state_name`, `labels`, `cycle_name`).
4. `update_ticket`: Update a ticket's title, append/replace description content, and post a comment.
5. `begin_work`: Assign one or more tickets (`ticket_ids`) to a cycle (`cycle_name`) and transition them into an active started state.
6. `transition_ticket`: Move a ticket (`ticket_id`) to a target workflow state by name (e.g., `Todo`, `In Progress`, `Done`).
7. `complete_work`: Transition a ticket (`ticket_id`) to the completed state and record a closing comment.

### Verifying MCP Connectivity via `curl`

You can test the MCP endpoint directly from the command line:

```bash
curl -s -X POST http://127.0.0.1:8085/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer plane_api_your_generated_token_here" \
  -H "X-Workspace-slug: your-workspace-slug" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

---

## 4. Customizing for Custom Domains or Production

All environment-specific parameters in `docker-compose.yml` use `${VAR:-default}` syntax with sane `127.0.0.1` defaults. Every personal or production setting is kept outside `docker-compose.yml` (either in a local `.env` file or in CI/CD via `Jenkinsfile`).

### Option 1: Using a `.env` File (Reverse Proxy / Nginx Proxy Manager)

When hosting behind an external reverse proxy (such as Nginx Proxy Manager, Traefik, or Caddy) that terminates TLS and forwards traffic to port `8085`, create a `.env` file in the repository root (ignored by Git):

```dotenv
# Public Domain and Protocol
DOMAIN_NAME=kanban.example.com
WEB_URL=https://kanban.example.com
CORS_ALLOWED_ORIGINS=https://kanban.example.com
APP_PROTOCOL=https
LISTEN_HTTP_PORT=8085

# Object Storage (MinIO S3 proxied through /uploads/*)
AWS_S3_ENDPOINT_URL=https://kanban.example.com
MINIO_ENDPOINT_SSL=1
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=replace-with-strong-minio-secret
AWS_S3_BUCKET_NAME=uploads

# Database and Application Secrets
POSTGRES_USER=plane
POSTGRES_DB=plane
PGPASSWORD=replace-with-strong-db-password
SECRET_KEY=replace-with-strong-random-secret-key

# Plane MCP Server
MCP_IMAGE=adamoutler/plane-mcp-server:plane-agent
PLANE_BASE_URL=https://kanban.example.com
PLANE_OAUTH_PROVIDER_BASE_URL=https://kanban.example.com/mcp/http

# Optional Gitea / Forgejo OAuth Integration
IS_GITEA_ENABLED=1
GITEA_HOST=https://git.example.com
PLANE_FORGEJO_CLIENT_ID=your-oauth-client-id
PLANE_FORGEJO_CLIENT_SECRET=your-oauth-client-secret
```

Apply your changes with:

```bash
docker compose up -d --force-recreate
```

### Option 2: CI/CD Deployment (`Jenkinsfile`)

For automated deployments, set the environment overrides in the `environment` block of `Jenkinsfile` and inject secrets via Jenkins Credentials (`SECRET_KEY`, `PGPASSWORD`, `AWS_SECRET_ACCESS_KEY`, `PLANE_FORGEJO_CLIENT_ID`, `PLANE_FORGEJO_CLIENT_SECRET`). Docker Compose automatically inherits the exported environment variables during `docker compose up -d`.

---

## 5. Architecture Overview

- **`plane-aio` (`makeplane/plane-aio-community:stable`):** Runs the Plane web frontend, space app, admin app (`/god-mode/`), Django API/auth backend, Celery workers, and an internal Caddy reverse proxy on port `80` (mapped to host port `8085`).
- **`Caddyfile.fixed`:** Mounted into `/app/proxy/Caddyfile` inside `plane-aio`. Routes `/api/*`, `/auth/*`, `/spaces/*`, `/live/*`, `/god-mode/*`, `/uploads/*` (to `plane-minio:9000`), and `/mcp` + `/mcp/*` (to `plane-mcp:8211`) through the single exposed port.
- **`plane-minio` and `plane-minio-setup`:** Provides S3-compatible storage and automatically initializes the `uploads` bucket prior to starting `plane-aio`.
- **`plane-mcp` (`adamoutler/plane-mcp-server:plane-agent`):** Exposes the 7-tool Plane Agent Model Context Protocol server at `/mcp` (and `/mcp/agent/api-key/mcp`) for AI agent ticket orchestration.
