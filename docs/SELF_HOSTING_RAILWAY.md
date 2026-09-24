# Railway Self-Hosting

Run OpenSEO on [Railway](https://railway.com) as a single service with a
persistent volume, protected by HTTP basic auth.

## How it works

`Dockerfile.railway` builds the same app as the Docker self-host image, with
`AUTH_MODE=local_noauth`, and puts [Caddy](https://caddyserver.com) in front of
it:

- Caddy listens on Railway's `$PORT` and requires a username and password for
  every path except `/api/health`, which stays open for Railway's healthcheck.
- The app runs on an internal port and is never reachable without passing
  through Caddy.
- A background tick fires the scheduled handler every 5 minutes, so scheduled
  rank tracking runs (plain Docker self-hosting has no scheduler).
- The app is built into the image, so a container boots in seconds instead of
  rebuilding on every start.

Data (the SQLite database, KV, and R2 storage) lives in a Railway volume
mounted at `/app/.wrangler/state`. Mount the volume there and not at
`/app/.wrangler`: the build writes `/app/.wrangler/deploy`, and a volume at the
parent directory would hide it.

## Setup

1. Create a Railway service from this repository. `railway.json` selects
   `Dockerfile.railway` and configures the healthcheck.
2. Add a volume mounted at `/app/.wrangler/state`.
3. Generate a Railway domain (or add a custom domain).
4. Set the service variables:

| Variable               | Required | Value                                                                                                   |
| ---------------------- | -------- | ------------------------------------------------------------------------------------------------------- |
| `OPENSEO_USERNAME`     | Yes      | Basic auth username.                                                                                    |
| `OPENSEO_PASSWORD`     | Yes      | Basic auth password. Use a long random value.                                                           |
| `ALLOWED_HOST`         | Yes      | The public hostname, for example `openseo-production.up.railway.app`.                                   |
| `DATAFORSEO_API_KEY`   | Yes      | See [`DATAFORSEO_API_KEY.md`](./DATAFORSEO_API_KEY.md).                                                 |
| `OPENROUTER_API_KEY`   | No       | Enables SAM, the in-app SEO agent.                                                                      |
| `GOOGLE_CLIENT_ID`     | No       | Search Console. See [`SELF_HOSTING_GOOGLE_SEARCH_CONSOLE.md`](./SELF_HOSTING_GOOGLE_SEARCH_CONSOLE.md). |
| `GOOGLE_CLIENT_SECRET` | No       | Search Console.                                                                                         |
| `BETTER_AUTH_SECRET`   | No       | Search Console. At least 32 characters: `openssl rand -base64 32`.                                      |

`ALLOWED_HOST` takes one hostname. If you move to a custom domain, update it,
and update the Search Console redirect URI to
`https://<your-domain>/api/gsc/oauth/callback`.

Don't set `AUTH_MODE` or `VITE_*` variables on Railway. They are fixed at image
build time in `Dockerfile.railway`.

## Connect an AI agent over MCP

The MCP endpoint is `https://<your-domain>/mcp`. Clients authenticate with the
same basic auth credentials, sent as a header. For Claude Code:

```sh
claude mcp add --transport http --scope user openseo https://<your-domain>/mcp \
  --header "Authorization: Basic $(printf '%s' 'USERNAME:PASSWORD' | base64)"
```

Clients that only support OAuth for remote MCP servers can't connect through
basic auth.

## Updating

Sync this fork with the upstream repository. If the Railway service deploys
from GitHub, the push triggers a new build and deploy. The volume keeps your
data, and database migrations run on boot.

Deploys cause a short downtime. A service with a volume stops the old
container before starting the new one.

## Telemetry

The same anonymous heartbeat as the Docker self-host applies. To disable it,
set `OPENSEO_TELEMETRY_DISABLED=1`. See
[`SELF_HOSTING_DOCKER.md`](./SELF_HOSTING_DOCKER.md#telemetry).
