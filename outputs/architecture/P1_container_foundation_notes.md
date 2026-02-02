# P1 Container Foundation - Architecture Notes

## 1. Overview

The ResilienceScan container provides a stable, multi-runtime Docker environment for resilience assessment report generation. This P1 (Phase 1) foundation establishes the base infrastructure — R, Python, Quarto, and LaTeX runtimes — without any application-specific logic. The container starts reliably, exposes a health endpoint, and confirms all runtimes are available. All persistent state lives in mounted host volumes.

**What this container does:**
- Provides R >= 4.3 for statistical analysis
- Provides Python >= 3.10 for scripting and the health endpoint server
- Provides Quarto (with Pandoc) for report rendering (HTML and PDF)
- Provides TinyTeX for PDF compilation via LaTeX
- Exposes a health endpoint at `http://localhost:8080/health`
- Persists data, reports, and logs via Docker volume mounts

**What this container does NOT do (yet):**
- No data ingestion or CSV processing
- No report generation or Quarto templates
- No web UI beyond the health endpoint
- No external service integrations
- No multi-container orchestration

## 2. Architecture Decisions

### Why Rocker (`rocker/r-ver:4.3.2`)

Rocker is the de facto standard for R-based Docker images. It provides a pre-compiled, optimized R installation on Debian, avoiding the lengthy compilation step required when installing R from source on generic Linux images. The `r-ver` variant gives a minimal R installation without RStudio, keeping the image lean. Version 4.3.2 is pinned for reproducibility.

**Alternatives considered:**
- `ubuntu:22.04` + install R from apt — older R versions in default repos, less reliable
- `continuumio/miniconda3` — conda R packages lag behind CRAN, heavier image
- Alpine-based images — R compilation fails frequently on musl libc

### Why TinyTeX (via `quarto install tinytex`)

TinyTeX is a minimal, cross-platform LaTeX distribution designed for document rendering. It installs only the packages needed for compilation, keeping the image size manageable (~300MB vs ~4GB for texlive-full). Quarto's built-in `install tinytex` command ensures compatibility between Quarto and the LaTeX distribution.

**Alternatives considered:**
- `texlive-full` — 4GB+, far too large for a container
- `texlive-base` — missing packages needed for PDF rendering, requires manual package management
- No LaTeX — would prevent PDF output, a core requirement

### Why Python `http.server` for the Health Endpoint

Python's built-in `http.server` module provides a zero-dependency HTTP server suitable for the placeholder health endpoint. It is more reliable than `nc` (netcat) for persistent HTTP serving and requires no additional package installation.

**Alternatives considered:**
- `nc` (netcat) loop — fragile, drops connections, no proper HTTP parsing
- `socat` — additional system dependency, overkill for a health check
- Flask/FastAPI — unnecessary framework dependency for a single endpoint

## 3. Runtime Versions

| Runtime  | Version | Source                          | Notes                              |
|----------|---------|---------------------------------|------------------------------------|
| R        | 4.3.2   | `rocker/r-ver:4.3.2` base image | Pinned via base image tag          |
| Python   | 3.11+   | Debian apt (`python3`)          | Version depends on Debian release  |
| Quarto   | 1.6.39  | GitHub `.deb` release           | Pinned via `QUARTO_VERSION` ARG    |
| Pandoc   | Bundled | Included with Quarto            | Version tied to Quarto release     |
| TinyTeX  | Latest  | `quarto install tinytex`        | Installed at build time            |

## 4. Build Instructions

### First-time build and start

```bash
docker compose up --build
```

This builds the Docker image and starts the container. The first build downloads the Rocker base image, installs system packages, Quarto, and TinyTeX, which may take **10-15 minutes** depending on network speed.

### Subsequent starts (no rebuild)

```bash
docker compose up
```

### Rebuild from scratch (no cache)

```bash
docker compose build --no-cache
docker compose up
```

Use this when you need to force a fresh install of all dependencies (e.g., after changing the Quarto version).

### Stop the container

```bash
docker compose down
```

### Stop and remove volumes

```bash
docker compose down -v
```

> **Warning:** This removes all data in the `data/`, `reports/`, and `logs/` directories inside the container. Host-mounted files remain on disk.

## 5. Verification Commands

After the container is running, verify each runtime:

```bash
# Check container health status
docker compose ps

# Verify R
docker compose exec resiliencescan R --version

# Verify Python
docker compose exec resiliencescan python3 --version

# Verify Quarto
docker compose exec resiliencescan quarto --version

# Verify Pandoc (bundled with Quarto)
docker compose exec resiliencescan quarto pandoc --version

# Verify UTF-8 locale
docker compose exec resiliencescan locale

# Verify TinyTeX / LaTeX
docker compose exec resiliencescan quarto install tinytex --update-path 2>&1 | head -3

# Test health endpoint
curl http://localhost:8080/health

# Test PDF rendering
docker compose exec resiliencescan bash -c \
  'echo -e "---\ntitle: test\nformat: pdf\n---\nHello World" > /tmp/test.qmd && quarto render /tmp/test.qmd --to pdf'
```

## 6. Volume Mount Documentation

The container uses three bind-mounted volumes that map host directories to container paths:

| Host Path    | Container Path | Purpose                                    |
|--------------|----------------|--------------------------------------------|
| `./data/`    | `/data`        | Input data files (CSV, Excel, etc.)        |
| `./reports/` | `/reports`     | Generated reports (PDF, HTML)              |
| `./logs/`    | `/logs`        | Application and startup logs               |

**Key behaviors:**
- Directories are created automatically on the host when `docker compose up` runs
- Files written inside the container appear immediately on the host (and vice versa)
- Data persists across container restarts (`docker compose down` / `docker compose up`)
- Container directories have `chmod 777` permissions to avoid write permission issues across platforms
- The startup log is written to `/logs/container_startup.log` on each container start

## 7. Port Configuration

The container exposes a single port for the health endpoint:

| Host Port | Container Port | Service         |
|-----------|----------------|-----------------|
| 8080      | 8080           | Health endpoint |

### How to override the host port

If port 8080 is already in use on your machine, change the host port mapping in `docker-compose.yml`:

```yaml
ports:
  - "9090:8080"  # Maps host port 9090 to container port 8080
```

Then access the health endpoint at `http://localhost:9090/health`.

Alternatively, override at runtime without editing the file:

```bash
docker compose run --service-ports -p 9090:8080 resiliencescan
```

## 8. Troubleshooting

### Slow first build

**Symptom:** `docker compose up --build` takes 10+ minutes on first run.

**Cause:** The image downloads the Rocker base image (~800MB), installs system packages, downloads Quarto (~200MB), and installs TinyTeX (~300MB).

**Resolution:** This is expected. Subsequent builds use Docker layer caching and complete in seconds unless the Dockerfile changes. If you need a full rebuild, expect similar times with `--no-cache`.

### Port conflicts

**Symptom:** `Bind for 0.0.0.0:8080 failed: port is already allocated`

**Resolution:** Another service is using port 8080. Either stop that service or change the host port mapping as described in Section 7.

```bash
# Find what's using port 8080
# Linux/macOS:
lsof -i :8080
# Windows:
netstat -ano | findstr :8080
```

### Docker Desktop memory

**Symptom:** Build fails with out-of-memory errors, or the container is killed shortly after starting.

**Resolution:** R and LaTeX can be memory-intensive. Allocate at least **4GB RAM** to Docker Desktop:

1. Open Docker Desktop Settings
2. Go to **Resources** > **Advanced**
3. Set **Memory** to at least **4 GB** (recommended: 6 GB)
4. Click **Apply & Restart**

### Container not becoming healthy

**Symptom:** `docker compose ps` shows `health: starting` for more than 2 minutes.

**Resolution:**
1. Check container logs: `docker compose logs resiliencescan`
2. Verify the entrypoint script ran: look for "ResilienceScan Container Startup" in logs
3. Ensure no runtime verification failed (look for error messages in startup output)
4. The health check has a `start_period` of 120 seconds — wait at least 2 minutes

### Windows line ending issues

**Symptom:** Container fails to start with `/bin/bash^M: bad interpreter` error.

**Resolution:** The `entrypoint.sh` script must use LF (Unix) line endings, not CRLF (Windows). The `.gitattributes` file enforces `*.sh text eol=lf`, but if you created the file outside of Git:

```bash
# Fix line endings
sed -i 's/\r$//' app/entrypoint.sh
# Or in Git
git checkout -- app/entrypoint.sh
```

### Volume permission errors

**Symptom:** Application cannot write to `/data`, `/reports`, or `/logs`.

**Resolution:** The Dockerfile sets `chmod 777` on these directories. If issues persist on Linux hosts, ensure the host directories have appropriate permissions:

```bash
chmod 777 ./data ./reports ./logs
```

## 9. Known Constraints and Limitations

1. **Image size:** The final image is approximately 2-3 GB due to R, Quarto, and TinyTeX. This is expected for a multi-runtime container.

2. **Architecture:** The image is built for `linux/amd64` only. Apple Silicon (M1/M2/M3) Macs will run it via Rosetta emulation in Docker Desktop, which may be slower.

3. **No hot-reload:** Changes to `entrypoint.sh` or the Dockerfile require a container rebuild (`docker compose up --build`).

4. **Single process:** The container runs a single Python health server process. There is no process manager (e.g., supervisord). If the health server crashes, the container stops.

5. **No HTTPS:** The health endpoint serves plain HTTP. TLS termination should be handled by a reverse proxy in production.

6. **No R packages pre-installed:** Only base R is available. Future phases will add R package installation (e.g., tidyverse, ggplot2) as needed.

7. **No Python packages pre-installed:** Only the Python standard library is available. Future phases will add pip dependencies as needed.

8. **TinyTeX package coverage:** TinyTeX includes a minimal set of LaTeX packages. Complex PDF layouts may require additional LaTeX packages installed via `tlmgr install <package>`.

9. **Health endpoint is a placeholder:** The `/health` endpoint returns a static response. It does not verify runtime availability at request time — runtimes are checked once at startup.

10. **No resource limits:** The `docker-compose.yml` does not set CPU or memory limits. For production use, add `deploy.resources.limits` configuration.
