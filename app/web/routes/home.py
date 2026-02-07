"""
Homepage and Health Check Routes
"""

from fastapi import APIRouter, Request
from fastapi.templating import Jinja2Templates
from pathlib import Path

from app.web.run_tracker import list_runs

router = APIRouter(tags=["home"])
templates = Jinja2Templates(directory=str(Path(__file__).parent.parent / "templates"))


@router.get("/")
async def homepage(request: Request):
    """Render homepage with recent runs"""
    recent_runs = list_runs(limit=10)
    return templates.TemplateResponse("index.html", {
        "request": request,
        "runs": recent_runs
    })


@router.get("/health")
async def health_check():
    """Container health check endpoint"""
    return {"status": "ok", "service": "resiliencescan-web"}
