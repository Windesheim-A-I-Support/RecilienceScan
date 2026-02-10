"""
FastAPI Web Application for ResilienceScan

This module provides the main FastAPI application instance and
configuration for the web control panel.
"""

from pathlib import Path
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

# Import routers
from app.web.routes import home, upload, pipeline, runs, reports, logs


# Initialize FastAPI app
app = FastAPI(
    title="ResilienceScan Web Control Panel",
    description="Web interface for orchestrating P2 ingestion and P3 reporting pipelines",
    version="1.0.0"
)

# Configure paths (cross-platform with pathlib)
BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
TEMPLATES_DIR = BASE_DIR / "templates"

# Mount static files
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

# Configure templates
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

# Register routers
app.include_router(home.router)
app.include_router(upload.router)
app.include_router(pipeline.router)
app.include_router(runs.router)
app.include_router(reports.router)
app.include_router(logs.router)


if __name__ == "__main__":
    import uvicorn
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8080, help="Port to run the server on")
    args = parser.parse_args()

    uvicorn.run(app, host="0.0.0.0", port=args.port)
