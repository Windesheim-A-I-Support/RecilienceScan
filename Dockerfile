# =============================================================================
# ResilienceScan Container Foundation (Fully Provisioned)
# R 4.3.2 + Python 3.10 + Quarto + TinyTeX
# Deterministic, production-grade runtime
# =============================================================================

FROM rocker/r-ver:4.3.2

# ---------------------------------------------------------------------------
# System Dependencies (R compilation + graphics + PDF + XML + SSL + build)
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
    build-essential \
    gfortran \
    make \
    cmake \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libpng-dev \
    libcairo2-dev \
    libjpeg-dev \
    libtiff5-dev \
    libxt-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    libgit2-dev \
    libglpk-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    ghostscript \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# UTF-8 Locale
# ---------------------------------------------------------------------------
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC

# ---------------------------------------------------------------------------
# Python Environment
# ---------------------------------------------------------------------------
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Upgrade pip first
RUN python3 -m pip install --upgrade pip setuptools wheel

# ---------------------------------------------------------------------------
# Install Python dependencies (deterministic)
# ---------------------------------------------------------------------------
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# Ensure common PDF + Excel stack exists
RUN pip3 install --no-cache-dir \
    pypdf \
    PyPDF2 \
    reportlab \
    openpyxl \
    xlrd \
    pandas \
    numpy

# ---------------------------------------------------------------------------
# Install Quarto
# ---------------------------------------------------------------------------
ARG QUARTO_VERSION=1.6.39
RUN curl -fsSL -o /tmp/quarto.deb \
    "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
    && dpkg -i /tmp/quarto.deb \
    && rm /tmp/quarto.deb

# ---------------------------------------------------------------------------
# Install TinyTeX
# ---------------------------------------------------------------------------
RUN quarto install tinytex --update-path

# ---------------------------------------------------------------------------
# Install R Packages (Full Reporting Stack)
# ---------------------------------------------------------------------------
RUN R -e "install.packages(c( \
  'readr','dplyr','stringr','tidyr','ggplot2','knitr', \
  'fmsb','scales','viridis','patchwork','RColorBrewer', \
  'gridExtra','png','lubridate','kableExtra', \
  'rmarkdown','quarto','jsonlite','yaml','xml2', \
  'data.table','purrr','forcats','tibble','magrittr', \
  'ggrepel','cowplot','plotly','DT','htmltools', \
  'broom','stringi','cli','rlang','vctrs' \
  ), repos='https://cloud.r-project.org', dependencies=TRUE)"

# ---------------------------------------------------------------------------
# Verify runtimes during build (fail fast)
# ---------------------------------------------------------------------------
RUN R --version && \
    python3 --version && \
    quarto --version

# ---------------------------------------------------------------------------
# Directory Structure
# ---------------------------------------------------------------------------
RUN mkdir -p /app/data /app/outputs /app/logs \
    && chmod -R 777 /app

# ---------------------------------------------------------------------------
# Copy Application
# ---------------------------------------------------------------------------
COPY app/ /app/
COPY tests/ /tests/
RUN chmod +x /app/entrypoint.sh

WORKDIR /app

# ---------------------------------------------------------------------------
# Expose FastAPI port
# ---------------------------------------------------------------------------
EXPOSE 8080

# ---------------------------------------------------------------------------
# Healthcheck
# ---------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=120s \
    CMD curl -f http://localhost:8080/health || exit 1

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------
ENTRYPOINT ["/app/entrypoint.sh"]
