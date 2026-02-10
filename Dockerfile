# =============================================================================
# ResilienceScan Container Foundation
# Multi-runtime environment: R 4.3, Python 3.10+, Quarto, TinyTeX
# =============================================================================
FROM rocker/r-ver:4.3.2

# ---------------------------------------------------------------------------
# (1) System dependencies - single layer with cache cleanup
# (2) Python 3.10+ and pip
# (6) PDF-compatible fonts (fonts-dejavu-core)
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    wget \
    locales \
    fonts-dejavu-core \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# (3) UTF-8 locale and TZ=UTC
# ---------------------------------------------------------------------------
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC

# ---------------------------------------------------------------------------
# (8) Python environment variables
# ---------------------------------------------------------------------------
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ---------------------------------------------------------------------------
# Install Python dependencies
# ---------------------------------------------------------------------------
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# ---------------------------------------------------------------------------
# (4) Quarto CLI from official GitHub .deb release (pinned version)
# ---------------------------------------------------------------------------
ARG QUARTO_VERSION=1.6.39
RUN curl -fsSL -o /tmp/quarto.deb \
    "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
    && dpkg -i /tmp/quarto.deb \
    && rm /tmp/quarto.deb

# ---------------------------------------------------------------------------
# (5) TinyTeX via quarto install tinytex
# ---------------------------------------------------------------------------
RUN quarto install tinytex --update-path

# ---------------------------------------------------------------------------
# (7) Container directory structure
# ---------------------------------------------------------------------------
RUN mkdir -p /app/data /app/outputs /app/logs \
    && chmod 777 /app/data /app/outputs /app/logs

# ---------------------------------------------------------------------------
# Copy application files
# ---------------------------------------------------------------------------
COPY app/ /app/
COPY tests/ /tests/
RUN chmod +x /app/entrypoint.sh

# ---------------------------------------------------------------------------
# Working directory
# ---------------------------------------------------------------------------
WORKDIR /app

# ---------------------------------------------------------------------------
# Expose health endpoint port
# ---------------------------------------------------------------------------
EXPOSE 8080

# ---------------------------------------------------------------------------
# (9) HEALTHCHECK instruction
# ---------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=120s \
    CMD curl -f http://localhost:8080/health || exit 1

# ---------------------------------------------------------------------------
# (10) ENTRYPOINT pointing to app/entrypoint.sh
# ---------------------------------------------------------------------------
ENTRYPOINT ["/app/entrypoint.sh"]
