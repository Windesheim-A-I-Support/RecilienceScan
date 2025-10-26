# Script: modules/Install-PythonBasicPackages.ps1
# Purpose: Installs essential Python packages for basic data science and development

Write-Host "Installing essential Python packages..." -ForegroundColor Yellow
Write-Host "=== PYTHON BASIC PACKAGES INSTALLATION ===" -ForegroundColor Cyan

# Function to refresh PATH environment variable
function Update-SessionPath {
    $systemPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    
    if ($userPath) {
        $env:PATH = "$systemPath;$userPath"
    } else {
        $env:PATH = $systemPath
    }
}

# Function to test if pip is available
function Test-PipAvailable {
    try {
        $pipVersion = pip --version 2>&1
        if ($pipVersion -match "pip \d+\.\d+") {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Function to test if Python is available
function Test-PythonAvailable {
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match "Python \d+\.\d+") {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Function to install Python package with error handling
function Install-PythonPackage {
    param(
        [string]$PackageName,
        [string]$DisplayName = $PackageName,
        [string]$Version = $null
    )
    
    try {
        $packageSpec = if ($Version) { "$PackageName==$Version" } else { $PackageName }
        Write-Host "  Installing $DisplayName..." -ForegroundColor Cyan
        
        # Use pip to install package
        $result = pip install $packageSpec --upgrade --no-warn-script-location 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    + $DisplayName installed successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "    - $DisplayName installation failed" -ForegroundColor Red
            Write-Host "      Error: $result" -ForegroundColor Gray
            return $false
        }
    } catch {
        Write-Host "    - $DisplayName installation error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to verify package installation
function Test-PythonPackage {
    param([string]$PackageName)
    
    try {
        $result = python -c "import $PackageName; print('$PackageName OK')" 2>&1
        return $result -like "*OK*"
    } catch {
        return $false
    }
}

try {
    # Check if Python is available
    Write-Host "Checking for Python installation..." -ForegroundColor Cyan
    
    if (-not (Test-PythonAvailable)) {
        Write-Host "Python not found in current PATH. Refreshing environment..." -ForegroundColor Yellow
        Update-SessionPath
        Start-Sleep -Seconds 2
        
        if (-not (Test-PythonAvailable)) {
            Write-Host "Python is still not available after PATH refresh." -ForegroundColor Red
            Write-Host "This may happen if Python was just installed in the same session." -ForegroundColor Yellow
            Write-Host "Python packages installation will be skipped for now." -ForegroundColor Yellow
            Write-Host "You can install packages manually later or restart your terminal." -ForegroundColor Yellow
            exit 0  # Don't fail the installation
        }
    }
    
    Write-Host "Python is available. Checking pip..." -ForegroundColor Green
    
    # Check if pip is available
    if (-not (Test-PipAvailable)) {
        Write-Host "pip not found. Refreshing environment..." -ForegroundColor Yellow
        Update-SessionPath
        Start-Sleep -Seconds 2
        
        if (-not (Test-PipAvailable)) {
            Write-Host "pip is still not available. This may indicate an incomplete Python installation." -ForegroundColor Red
            Write-Host "Please ensure Python was installed with pip included." -ForegroundColor Yellow
            exit 1
        }
    }
    
    # Get Python and pip version info
    try {
        $pythonVersion = python --version 2>&1
        $pipVersion = pip --version 2>&1
        Write-Host "Python: $pythonVersion" -ForegroundColor Gray
        Write-Host "pip: $pipVersion" -ForegroundColor Gray
    } catch {
        Write-Host "Could not retrieve Python/pip version information" -ForegroundColor Gray
    }
    
    # Upgrade pip first
    Write-Host "Upgrading pip to latest version..." -ForegroundColor Cyan
    try {
        pip install --upgrade pip --no-warn-script-location 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  + pip upgraded successfully" -ForegroundColor Green
        } else {
            Write-Host "  ! pip upgrade failed, continuing anyway" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ! pip upgrade error, continuing anyway" -ForegroundColor Yellow
    }
    
    # Define essential Python packages for basic usage
    $essentialPackages = @(
        @{ Package = "pip"; Display = "pip (Package Installer)" },
        @{ Package = "setuptools"; Display = "setuptools (Package Development)" },
        @{ Package = "wheel"; Display = "wheel (Binary Package Format)" },
        @{ Package = "requests"; Display = "requests (HTTP Library)" },
        @{ Package = "urllib3"; Display = "urllib3 (HTTP Client)" },
        @{ Package = "certifi"; Display = "certifi (SSL Certificates)" },
        @{ Package = "six"; Display = "six (Python 2/3 Compatibility)" },
        @{ Package = "python-dateutil"; Display = "dateutil (Date/Time Utilities)" },
        @{ Package = "pytz"; Display = "pytz (Timezone Support)" },
        @{ Package = "packaging"; Display = "packaging (Core Packaging Utilities)" },
        @{ Package = "lxml"; Display = "lxml (XML/HTML Parsing)" },
        @{ Package = "PyYAML"; Display = "PyYAML (YAML Files)" },
        @{ Package = "pillow"; Display = "pillow (Image Processing)" },
        @{ Package = "pywin32"; Display = "pywin32 (Windows COM Interface - may need post-install)" }
    )
    
    # Additional useful packages
    $usefulPackages = @(
        @{ Package = "pandas"; Display = "pandas (Data Analysis)" },
        @{ Package = "numpy"; Display = "numpy (Numerical Computing)" },
        @{ Package = "matplotlib"; Display = "matplotlib (Plotting)" },
        @{ Package = "openpyxl"; Display = "openpyxl (Excel Files)" },
        @{ Package = "jupyter"; Display = "jupyter (Interactive Notebooks)" },
        @{ Package = "ipython"; Display = "ipython (Enhanced Python Shell)" },
        @{ Package = "scipy"; Display = "scipy (Scientific Computing)" },
        @{ Package = "seaborn"; Display = "seaborn (Statistical Plotting)" },
        @{ Package = "scikit-learn"; Display = "scikit-learn (Machine Learning)" },
        @{ Package = "matplotlib"; Display = "matplotlib (Plotting)" },
        @{ Package = "plotly"; Display = "plotly (Interactive Plots)" },
        @{ Package = "tqdm"; Display = "tqdm (Progress Bars)" },
        @{ Package = "pytest"; Display = "pytest (Testing Framework)" },
        @{ Package = "virtualenv"; Display = "virtualenv (Virtual Environments)" },
        @{ Package = "pyarrow"; Display = "pyarrow (Arrow/Parquet)" },
        @{ Package = "polars"; Display = "polars (Fast DataFrames)" },
        @{ Package = "duckdb"; Display = "duckdb (In-process OLAP)" },
        @{ Package = "numba"; Display = "numba (JIT acceleration)" },
        @{ Package = "numexpr"; Display = "numexpr (Fast expressions)" },
        @{ Package = "bottleneck"; Display = "bottleneck (NumPy speedups)" },
        @{ Package = "fastparquet"; Display = "fastparquet (Parquet IO)" },
        @{ Package = "pyreadstat"; Display = "pyreadstat (SPSS/Stata/SAS IO)" },
        @{ Package = "xlsxwriter"; Display = "xlsxwriter (Excel writer)" },
        @{ Package = "sqlalchemy"; Display = "SQLAlchemy (DB engine/ORM)" },
        @{ Package = "psycopg[binary]"; Display = "psycopg v3 (PostgreSQL, binary)" },
        @{ Package = "pymysql"; Display = "PyMySQL (MySQL/MariaDB)" },
        @{ Package = "pyodbc"; Display = "pyodbc (ODBC bridge)" },
        @{ Package = "oracledb"; Display = "oracledb (Oracle client)" },
        @{ Package = "snowflake-connector-python"; Display = "Snowflake Connector" },
        @{ Package = "pymongo"; Display = "PyMongo (MongoDB client)" },
        @{ Package = "fsspec"; Display = "fsspec (FS abstraction)" },
        @{ Package = "s3fs"; Display = "s3fs (S3 filesystem)" },
        @{ Package = "gcsfs"; Display = "gcsfs (GCS filesystem)" },
        @{ Package = "adlfs"; Display = "adlfs (Azure Data Lake FS)" },
        @{ Package = "xgboost-cpu"; Display = "XGBoost (CPU-only wheel)" },
        @{ Package = "lightgbm"; Display = "LightGBM (GBM, optional on Windows)" },
        @{ Package = "catboost"; Display = "CatBoost (GBM)" },
        @{ Package = "imbalanced-learn"; Display = "imbalanced-learn (sampling)" },
        @{ Package = "optuna"; Display = "Optuna (hyperparameter tuning)" },
        @{ Package = "scikit-optimize"; Display = "scikit-optimize (Bayesian opt.)" },
        @{ Package = "mlflow"; Display = "MLflow (experiment tracking)" },
        @{ Package = "spacy"; Display = "spaCy (NLP)" },
        @{ Package = "transformers"; Display = "Transformers (HF)" },
        @{ Package = "sentencepiece"; Display = "SentencePiece (tokenizer)" },
        @{ Package = "nltk"; Display = "NLTK (classical NLP)" },
        @{ Package = "gensim"; Display = "Gensim (topic models)" },
        @{ Package = "prophet"; Display = "Prophet (forecasting)" },
        @{ Package = "pmdarima"; Display = "pmdarima (auto-ARIMA)" },
        @{ Package = "bokeh"; Display = "Bokeh (interactive viz)" },
        @{ Package = "altair"; Display = "Altair (declarative viz)" },
        @{ Package = "hvplot"; Display = "hvPlot (Pandas/Geo viz)" },
        @{ Package = "jupyterlab"; Display = "JupyterLab (IDE)" },
        @{ Package = "ipykernel"; Display = "ipykernel (kernel mgmt)" },
        @{ Package = "ipywidgets"; Display = "ipywidgets (widgets)" },
        @{ Package = "jupytext"; Display = "Jupytext (sync .py <-> .ipynb)" },
        @{ Package = "nbconvert"; Display = "nbconvert (export)" },
        @{ Package = "nbformat"; Display = "nbformat (IPYNB schema)" },
        @{ Package = "pandera[pandas]"; Display = "Pandera (DataFrame schemas)" },
        @{ Package = "great_expectations"; Display = "Great Expectations (Data QA)" },
        @{ Package = "black"; Display = "black (formatter)" },
        @{ Package = "ruff"; Display = "ruff (linter)" },
        @{ Package = "mypy"; Display = "mypy (type checking)" },
        @{ Package = "pre-commit"; Display = "pre-commit (git hooks)" },
        @{ Package = "pytest-cov"; Display = "pytest-cov (coverage)" },
        @{ Package = "rich"; Display = "rich (console)" },
        @{ Package = "typer"; Display = "typer (CLIs)" },
        @{ Package = "click"; Display = "click (CLIs)" },
        @{ Package = "loguru"; Display = "loguru (logging)" },
        @{ Package = "orjson"; Display = "orjson (fast JSON)" },
        @{ Package = "joblib"; Display = "joblib (caching/parallel)" },
        @{ Package = "dill"; Display = "dill (serialization)" },
        @{ Package = "graphviz"; Display = "graphviz (render DOT; needs Graphviz app)" },
        @{ Package = "pydot"; Display = "pydot (DOT interface)" },
        @{ Package = "fastapi"; Display = "FastAPI (serve APIs/models)" },
        @{ Package = "uvicorn"; Display = "Uvicorn (ASGI server)" },
        @{ Package = "python-dotenv"; Display = "python-dotenv (.env support)" },
        @{ Package = "tabulate"; Display = "tabulate (pretty tables)" },
        @{ Package = "networkx"; Display = "NetworkX (graphs)" },
        @{ Package = "scikit-image"; Display = "scikit-image (image proc)" },
        @{ Package = "opencv-python"; Display = "OpenCV (image/video; optional)" },
        @{ Package = "h5py"; Display = "h5py (HDF5 IO)" },
        @{ Package = "tables"; Display = "PyTables (HDF5 tables)" },
        @{ Package = "ydata-profiling"; Display = "ydata-profiling (EDA report)" },
        @{ Package = "pydantic"; Display = "pydantic (data models)" },
        @{ Package = "boto3"; Display = "AWS SDK (boto3)" },
        @{ Package = "google-cloud-storage"; Display = "GCP Storage" },
        @{ Package = "google-cloud-bigquery"; Display = "GCP BigQuery" },
        @{ Package = "azure-identity"; Display = "Azure Identity" },
        @{ Package = "azure-storage-blob"; Display = "Azure Blob Storage" },
        @{ Package = "dask"; Display = "Dask (parallel/distributed)" },
        @{ Package = "ray"; Display = "Ray (distributed apps)" },
        @{ Package = "pyspark"; Display = "PySpark (requires Java)" },
        @{ Package = "geopandas"; Display = "GeoPandas (geospatial frames)" },
        @{ Package = "shapely"; Display = "Shapely (geometry)" },
        @{ Package = "pyproj"; Display = "pyproj (projections)" },
        @{ Package = "rtree"; Display = "Rtree (spatial index)" },
        @{ Package = "statsmodels"; Display = "statsmodels (statistical modeling)" },
        @{ Package = "httpx"; Display = "httpx (async HTTP client)" },
        @{ Package = "aiohttp"; Display = "aiohttp (async HTTP client/server)" },
        @{ Package = "requests-cache"; Display = "requests-cache (HTTP cache)" },
        @{ Package = "pendulum"; Display = "pendulum (datetime utilities)" },
        @{ Package = "arrow"; Display = "arrow (friendly datetimes)" },
        @{ Package = "dateparser"; Display = "dateparser (parse natural dates)" },
        @{ Package = "humanize"; Display = "humanize (human-readable nums/dates)" },
        @{ Package = "textdistance"; Display = "textdistance (string metrics)" },
        @{ Package = "thefuzz"; Display = "thefuzz (fuzzy matching)" },
        @{ Package = "rapidfuzz"; Display = "rapidfuzz (fast fuzzy matching)" },
        @{ Package = "gdown"; Display = "gdown (Google Drive downloads)" },
        @{ Package = "pdfplumber"; Display = "pdfplumber (PDF text/tables)" },
        @{ Package = "pypdf"; Display = "pypdf (PDF toolkit)" },
        @{ Package = "pdfminer.six"; Display = "pdfminer.six (PDF parsing)" },
        @{ Package = "python-docx"; Display = "python-docx (Word files)" },
        @{ Package = "python-pptx"; Display = "python-pptx (PowerPoint files)" },
        @{ Package = "xlwings"; Display = "xlwings (Excel automation)" },
        @{ Package = "pyxlsb"; Display = "pyxlsb (read .xlsb)" },
        @{ Package = "odfpy"; Display = "odfpy (OpenDocument files)" },
        @{ Package = "xlrd"; Display = "xlrd (legacy .xls reader)" },
        @{ Package = "xlsx2csv"; Display = "xlsx2csv (convert Excel to CSV)" },
        @{ Package = "redis"; Display = "redis (Redis client)" },
        @{ Package = "pymemcache"; Display = "pymemcache (Memcached client)" },
        @{ Package = "minio"; Display = "minio (S3-compatible client)" },
        @{ Package = "kafka-python"; Display = "kafka-python (Kafka client)" },
        @{ Package = "confluent-kafka"; Display = "confluent-kafka (Kafka client, librdkafka)" },
        @{ Package = "clickhouse-connect"; Display = "clickhouse-connect (ClickHouse client)" },
        @{ Package = "mysql-connector-python"; Display = "MySQL Connector/Python" },
        @{ Package = "trino"; Display = "trino (Trino/Presto client)" },
        @{ Package = "pyhive"; Display = "PyHive (Hive/Presto client)" },
        @{ Package = "vertica-python"; Display = "vertica-python (Vertica client)" },
        @{ Package = "duckdb-engine"; Display = "duckdb-engine (SQLAlchemy dialect)" },
        @{ Package = "pandas-gbq"; Display = "pandas-gbq (Pandas ↔ BigQuery)" },
        @{ Package = "google-cloud-bigquery-storage"; Display = "BigQuery Storage API" },
        @{ Package = "datasets"; Display = "datasets (HF datasets)" },
        @{ Package = "evaluate"; Display = "evaluate (HF evaluation)" },
        @{ Package = "shap"; Display = "SHAP (model explainability)" },
        @{ Package = "lime"; Display = "LIME (model explainability)" },
        @{ Package = "evidently"; Display = "Evidently (model monitoring)" },
        @{ Package = "featuretools"; Display = "Featuretools (feature engineering)" },
        @{ Package = "tsfresh"; Display = "tsfresh (time series features)" },
        @{ Package = "sktime"; Display = "sktime (time series ML)" },
        @{ Package = "statsforecast"; Display = "statsforecast (fast forecasting)" },
        @{ Package = "arch"; Display = "arch (econometrics)" },
        @{ Package = "linearmodels"; Display = "linearmodels (econometrics)" },
        @{ Package = "lifelines"; Display = "lifelines (survival analysis)" },
        @{ Package = "umap-learn"; Display = "UMAP (dimensionality reduction)" },
        @{ Package = "hdbscan"; Display = "HDBSCAN (clustering)" },
        @{ Package = "pynndescent"; Display = "pynndescent (nearest neighbors)" },
        @{ Package = "mlxtend"; Display = "mlxtend (ML extensions)" },
        @{ Package = "scikit-plot"; Display = "scikit-plot (ML plots)" },
        @{ Package = "yellowbrick"; Display = "yellowbrick (model viz)" },
        @{ Package = "connectorx"; Display = "connectorx (fast DB → DF)" },
        @{ Package = "deltalake"; Display = "deltalake (Delta Lake bindings)" },
        @{ Package = "pyiceberg"; Display = "pyiceberg (Apache Iceberg client)" },
        @{ Package = "sqlglot"; Display = "sqlglot (SQL parser/transpiler)" },
        @{ Package = "great-tables"; Display = "great-tables (publication tables)" },
        @{ Package = "datashader"; Display = "datashader (big data viz)" },
        @{ Package = "holoviews"; Display = "holoviews (HV ecosystem)" },
        @{ Package = "panel"; Display = "panel (dashboarding)" },
        @{ Package = "streamlit"; Display = "streamlit (data apps)" },
        @{ Package = "gradio"; Display = "gradio (data/ML apps)" },
        @{ Package = "dash"; Display = "dash (Plotly apps)" },
        @{ Package = "folium"; Display = "folium (leaflet maps)" },
        @{ Package = "contextily"; Display = "contextily (basemaps)" },
        @{ Package = "geopy"; Display = "geopy (geocoding)" },
        @{ Package = "osmnx"; Display = "osmnx (OpenStreetMap graphs)" },
        @{ Package = "pydeck"; Display = "pydeck (WebGL maps)" },
        @{ Package = "voila"; Display = "voila (notebooks → apps)" },
        @{ Package = "jupyterlab-lsp"; Display = "jupyterlab-lsp (LSP support)" },
        @{ Package = "python-lsp-server"; Display = "python-lsp-server (pylsp)" },
        @{ Package = "jupyterlab-code-formatter"; Display = "jupyterlab-code-formatter" },
        @{ Package = "nbqa"; Display = "nbqa (lint/format notebooks)" },
        @{ Package = "papermill"; Display = "papermill (param notebooks)" },
        @{ Package = "pydantic-settings"; Display = "pydantic-settings (config)" },
        @{ Package = "hydra-core"; Display = "hydra-core (config mgmt)" },
        @{ Package = "omegaconf"; Display = "omegaconf (config)" },
        @{ Package = "jinja2"; Display = "jinja2 (templating)" },
        @{ Package = "cookiecutter"; Display = "cookiecutter (project templates)" },
        @{ Package = "httpx"; Display = "httpx (modern HTTP client)" },
        @{ Package = "websockets"; Display = "websockets (async WS)" },
        @{ Package = "sentry-sdk"; Display = "sentry-sdk (telemetry)" },
        @{ Package = "tenacity"; Display = "tenacity (retries)" },
        @{ Package = "psutil"; Display = "psutil (system info)" },
        @{ Package = "colorama"; Display = "colorama (terminal colors)" },
        @{ Package = "smart_open"; Display = "smart_open (stream from S3/GCS)" },
        @{ Package = "pip-tools"; Display = "pip-tools (pip-compile/resolve)" },
        @{ Package = "marshmallow"; Display = "marshmallow (data validation)" },
        @{ Package = "cerberus"; Display = "cerberus (data validation)" },
        @{ Package = "ujson"; Display = "ujson (ultra-fast JSON)" },
        @{ Package = "msgpack"; Display = "msgpack (binary JSON)" },
        @{ Package = "zstandard"; Display = "zstandard (compression)" },
        @{ Package = "lz4"; Display = "lz4 (compression)" },
        @{ Package = "brotli"; Display = "brotli (compression)" },
        @{ Package = "pyjanitor"; Display = "pyjanitor (data cleaning)" },
        @{ Package = "petl"; Display = "petl (ETL tools)" },
        @{ Package = "modin"; Display = "modin (pandas acceleration)" },
        @{ Package = "vaex"; Display = "vaex (lazy big dataframes)" },
        @{ Package = "datatable"; Display = "datatable (H2O DataFrame)" },
        @{ Package = "category_encoders"; Display = "category_encoders (encoding)" },
        @{ Package = "hyperopt"; Display = "hyperopt (hyperparam search)" },
        @{ Package = "prefect"; Display = "prefect (workflow orchestration)" },
        @{ Package = "kedro"; Display = "kedro (pipeline framework)" },
        @{ Package = "kedro-datasets"; Display = "kedro-datasets (IO connectors)" },
        @{ Package = "kedro-viz"; Display = "kedro-viz (pipeline viz)" },
        @{ Package = "prefect-aws"; Display = "prefect-aws (AWS blocks)" },
        @{ Package = "prefect-dask"; Display = "prefect-dask (Dask integration)" },
        @{ Package = "duckdb-engine"; Display = "duckdb-engine (SQLAlchemy driver)" },
        @{ Package = "awswrangler"; Display = "awswrangler (AWS SDK for pandas)" },
        @{ Package = "connectorx"; Display = "connectorx (DB → DF fast loader)" },
        @{ Package = "sqlglot"; Display = "sqlglot (SQL parser/transpiler)" }
    )
    
    # Track installation results
    $successCount = 0
    $failureCount = 0
    $allPackages = $essentialPackages + $usefulPackages
    $totalPackages = $allPackages.Count
    
    Write-Host "Installing $totalPackages essential Python packages..." -ForegroundColor Yellow
    Write-Host "This may take several minutes depending on internet speed..." -ForegroundColor Gray
    Write-Host ""
    
    # Install essential packages first
    Write-Host "Installing core packages..." -ForegroundColor Cyan
    foreach ($pkg in $essentialPackages) {
        if (Install-PythonPackage -PackageName $pkg.Package -DisplayName $pkg.Display) {
            $successCount++
        } else {
            $failureCount++
        }
    }
    
    Write-Host ""
    Write-Host "Installing data science packages..." -ForegroundColor Cyan
    foreach ($pkg in $usefulPackages) {
        if (Install-PythonPackage -PackageName $pkg.Package -DisplayName $pkg.Display) {
            $successCount++
        } else {
            $failureCount++
        }
    }
    
    # Summary
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "PYTHON BASIC PACKAGES INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    
    Write-Host "Total packages: $totalPackages" -ForegroundColor Gray
    Write-Host "Successfully installed: $successCount" -ForegroundColor Green
    Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Gray" })
    
    # Test key packages
    Write-Host ""
    Write-Host "Testing key package imports..." -ForegroundColor Cyan
    
    $testPackages = @("requests", "pandas", "numpy", "matplotlib")
    $importSuccesses = 0
    
    foreach ($testPkg in $testPackages) {
        if (Test-PythonPackage -PackageName $testPkg) {
            Write-Host "  + $testPkg imports successfully" -ForegroundColor Green
            $importSuccesses++
        } else {
            Write-Host "  - $testPkg import failed" -ForegroundColor Red
        }
    }
    
    # Check Jupyter installation
    Write-Host ""
    Write-Host "Checking Jupyter installation..." -ForegroundColor Cyan
    try {
        $jupyterVersion = jupyter --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  + Jupyter is available" -ForegroundColor Green
        } else {
            Write-Host "  - Jupyter may not be properly installed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  - Jupyter installation test failed" -ForegroundColor Red
    }
    
    # List installed packages
    Write-Host ""
    Write-Host "Checking pip package list..." -ForegroundColor Cyan
    try {
        $packageCount = (pip list 2>$null | Measure-Object -Line).Lines
        if ($packageCount -gt 0) {
            Write-Host "  + Total pip packages installed: $packageCount" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ! Could not retrieve package list" -ForegroundColor Yellow
    }
    
    # Final status
    if ($successCount -eq $totalPackages -and $importSuccesses -eq $testPackages.Count) {
        Write-Host ""
        Write-Host "All essential Python packages installed and working!" -ForegroundColor Green
        Write-Host "Python environment is ready for data science work." -ForegroundColor Green
        exit 0
    } elseif ($successCount -gt ($totalPackages * 0.7)) {
        Write-Host ""
        Write-Host "Most essential Python packages installed successfully." -ForegroundColor Yellow
        Write-Host "Some packages failed but core Python functionality should work." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host ""
        Write-Host "Multiple Python package installations failed." -ForegroundColor Red
        Write-Host "Python environment may not be fully functional." -ForegroundColor Red
        
        Write-Host ""
        Write-Host "Common solutions:" -ForegroundColor Yellow
        Write-Host "1. Ensure internet connectivity for package downloads" -ForegroundColor Yellow
        Write-Host "2. Update pip: python -m pip install --upgrade pip" -ForegroundColor Yellow
        Write-Host "3. Try installing packages manually: pip install pandas numpy matplotlib" -ForegroundColor Yellow
        Write-Host "4. Check for Python installation issues" -ForegroundColor Yellow
        
        # Don't fail completely - some packages might still work
        exit 0
    }
    
} catch {
    Write-Host "ERROR: Unexpected error during Python package installation." -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "You can try installing packages manually:" -ForegroundColor Yellow
    Write-Host "pip install pandas numpy matplotlib requests openpyxl jupyter" -ForegroundColor Cyan
    exit 1
}