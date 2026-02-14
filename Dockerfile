# =============================================================================
# ResilienceScan Engine Container (Headless / Deterministic)
# - R 4.3.2 (rocker/r-ver)
# - Python 3 + pip
# - Quarto CLI (pinned)
# - TinyTeX (for PDF rendering)
#
# Purpose:
#   Provide a consistent runtime for the DATA + REPORTING ENGINE.
#   (GUI stays outside Docker; this container is for batch execution.)
# =============================================================================

FROM rocker/r-ver:4.3.2

ARG DEBIAN_FRONTEND=noninteractive
ARG QUARTO_VERSION=1.6.39

# -----------------------------------------------------------------------------
# 1) System deps
#    - build tools for R packages
#    - libs commonly needed by tidyverse/plotting/xml/ssl/curl/git
#    - PDF tooling + fonts
#    - dpkg required to install Quarto .deb
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    ca-certificates \
    curl \
    wget \
    git \
    locales \
    tzdata \
    dpkg \
    build-essential \
    gfortran \
    make \
    cmake \
    pkg-config \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libpng-dev \
    libcairo2-dev \
    libjpeg-dev \
    libtiff5-dev \
    libxt-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    ghostscript \
    poppler-utils \
    fonts-dejavu-core \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2) Locale + TZ
# -----------------------------------------------------------------------------
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=UTC

# -----------------------------------------------------------------------------
# 3) Python runtime settings
# -----------------------------------------------------------------------------
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN python3 -m pip install --upgrade pip setuptools wheel

# -----------------------------------------------------------------------------
# 4) Install Quarto (pinned)
# -----------------------------------------------------------------------------
RUN curl -fsSL -o /tmp/quarto.deb \
    "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
    && dpkg -i /tmp/quarto.deb \
    && rm -f /tmp/quarto.deb

# -----------------------------------------------------------------------------
# 5) Install TinyTeX (PDF engine)
#    - Quarto installs TinyTeX under /root/.TinyTeX by default
#    - We add it to PATH explicitly for runtime reliability.
# -----------------------------------------------------------------------------
RUN quarto install tinytex --update-path
ENV PATH="/root/.TinyTeX/bin/x86_64-linux:${PATH}"

# Optional: preinstall a few LaTeX packages that often break PDF builds
# (Safe to keep; if already present, tlmgr is fast.)
RUN tlmgr option repository ctan \
    && tlmgr install \
       latexmk \
       xcolor \
       booktabs \
       longtable \
       multirow \
       colortbl \
       fancyhdr \
       geometry \
       titlesec \
       hyperref \
       xurl \
       url \
       bookmark \
       parskip \
    || true

# -----------------------------------------------------------------------------
# 6) R packages (broad reporting stack)
#    - dependencies=TRUE pulls system-level Suggests/Imports where possible
# -----------------------------------------------------------------------------
RUN R -e "install.packages(c( \
  'readr','dplyr','stringr','tidyr','ggplot2','knitr', \
  'scales','viridis','patchwork','RColorBrewer','gridExtra', \
  'lubridate','kableExtra','rmarkdown','jsonlite','yaml','xml2', \
  'data.table','purrr','forcats','tibble','magrittr', \
  'ggrepel','cowplot','plotly','DT','htmltools', \
  'broom','stringi','cli','rlang','vctrs' \
  ), repos='https://cloud.r-project.org', dependencies=TRUE)"

# -----------------------------------------------------------------------------
# 7) Copy only requirements first for better Docker layer caching
# -----------------------------------------------------------------------------
WORKDIR /app
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt && rm -f /tmp/requirements.txt

# Extra “always useful” python libs for your workload (won’t hurt if already in requirements)
RUN pip3 install --no-cache-dir \
    pandas \
    numpy \
    openpyxl \
    xlrd \
    pypdf \
    PyPDF2 \
    reportlab

# -----------------------------------------------------------------------------
# 8) Copy the application repo (engine + templates + reports)
#    IMPORTANT: add a .dockerignore to exclude venv/, outputs/, large logs, etc.
# -----------------------------------------------------------------------------
COPY . /app

# -----------------------------------------------------------------------------
# 9) Standard folders (match your repo expectations)
# -----------------------------------------------------------------------------
RUN mkdir -p /app/data /app/reports /app/outputs /app/logs \
    && chmod -R 777 /app/data /app/reports /app/outputs /app/logs

# -----------------------------------------------------------------------------
# 10) Fail-fast verification (during build)
# -----------------------------------------------------------------------------
RUN python3 --version && R --version && quarto --version && tlmgr --version

# -----------------------------------------------------------------------------
# 11) Default command: run pipeline (overrideable)
#    This container is headless; no EXPOSE, no healthcheck needed.
# -----------------------------------------------------------------------------
CMD ["python3", "pipeline_runner.py"]
