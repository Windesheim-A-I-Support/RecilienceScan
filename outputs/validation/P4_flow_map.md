# ResilienceScan Web Interface Flow Map

## Overview
This document maps the complete UI flow for the ResilienceScan web interface, showing how users navigate through the application to upload files, trigger pipelines, and access outputs.

## Application Entry Points

### **1. Landing Page** (`GET /`)
- **Purpose**: Main entry point with navigation and recent runs
- **Template**: `index.html`
- **Flow**:
  1. User accesses `http://localhost:8000/`
  2. Homepage renders with recent runs table
  3. Provides navigation to runs and reports
  4. Contains embedded forms for file upload and pipeline execution

### **2. Health Check** (`GET /health`)
- **Purpose**: Container health verification
- **Response**: JSON status object
- **Flow**:
  1. Load balancer or orchestrator calls endpoint
  2. Returns `{"status": "ok", "service": "resiliencescan-web"}` when healthy
  3. Returns 503 with error details if not ready

## Core User Workflows

### **Workflow A: File Upload**
```
GET / → Embedded Upload Form → POST /upload → JSON Response
```

#### **Step 1: Upload Form** (`GET /`)
- **Purpose**: Display file upload interface (embedded in homepage)
- **Location**: Embedded in landing page section
- **Form Fields**:
  - File input (accepts .xlsx, .xls, .csv, .tsv)
  - Submit button

#### **Step 2: File Processing** (`POST /upload`)
- **Validation**: File type and size validation (50MB max)
- **Sanitization**: Filename sanitization and duplicate handling
- **Storage**: Saves to `/uploads/` directory
- **Response**: JSON with upload confirmation and file path

### **Workflow B: Pipeline Execution**
```
GET / → Embedded Pipeline Buttons → POST /run/ingest → GET /runs → GET /logs/{run_id}
```

#### **Step 1: Trigger Ingestion** (`POST /run/ingest`)
- **Purpose**: Start P2 ingestion pipeline
- **Input**: Optional filename parameter (defaults to most recent upload)
- **Process**:
  - Validates file existence
  - Triggers ingestion pipeline
  - Creates run metadata with UUID
  - Stores logs in `/logs/runs/{run_id}.log`
- **Response**: JSON with run status and statistics

#### **Step 2: View Run Status** (`GET /runs`)
- **Purpose**: List recent runs with metadata
- **Filters**: Optional run type filtering (ingest/render)
- **Display**:
  - Run ID (UUID)
  - Action type (ingest/render)
  - Timestamp
  - Status (pending/running/completed/failed)
  - Links to logs (only for failed runs)

#### **Step 3: View Run Logs** (`GET /logs/{run_id}`)
- **Purpose**: Access detailed run logs
- **Format**: Plain text log content
- **Content**: Pipeline execution details, errors, statistics

### **Workflow C: Report Generation**
```
GET / → Embedded Report Button → POST /run/render → GET /reports → GET /reports/{filename}
```

#### **Step 1: Trigger Rendering** (`POST /run/render`)
- **Purpose**: Start P3 report generation
- **Input**:
  - `company_name` (required, prompted via JavaScript)
  - `person_name` (optional)
  - `output_format` (default: pdf)
- **Process**:
  - Validates input parameters
  - Triggers rendering pipeline
  - Creates run metadata
  - Stores report in `/reports/` directory
- **Response**: JSON with report path and status

#### **Step 2: List Reports** (`GET /reports`)
- **Purpose**: Browse available reports
- **Display**:
  - Filename
  - File size
  - Modification timestamp
  - Report type (PDF/HTML)
- **Sorting**: By modification time (newest first)

#### **Step 3: Download Report** (`GET /reports/{filename}`)
- **Purpose**: Download specific report
- **Security**: Path traversal prevention
- **Response**: FileResponse with appropriate MIME type

## Navigation Map

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    Landing Page (/)                         │
├────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Embedded Forms                        │  │
│  │  • Upload File  → POST /upload                             │  │
│  │  • Run Ingestion→ POST /run/ingest                        │  │
│  │  • Run Report   → POST /run/render                       │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
├────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Navigation Links                       │  │
│  │  • View Runs    → GET /runs                              │  │
│  │  • List Reports → GET /reports                           │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
├────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Runs Management                         │  │
│  │  • View Logs    → GET /logs/{run_id}                     │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
├────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Reports Management                      │  │
│  │  • Download     → GET /reports/{filename}                │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

## API Endpoints Summary

| Endpoint | Method | Purpose | Template |
|----------|--------|---------|----------|
| `/` | GET | Landing page with recent runs and embedded forms | `index.html` |
| `/upload` | POST | Process file upload | - |
| `/run/ingest` | POST | Trigger ingestion pipeline | - |
| `/run/render` | POST | Trigger rendering pipeline | - |
| `/runs` | GET | List recent runs | - |
| `/runs/{run_id}` | GET | Get run details | - |
| `/logs/{run_id}` | GET | View run logs | - |
| `/reports` | GET | List available reports | - |
| `/reports/{filename}` | GET | Download report | - |
| `/health` | GET | Health check | - |

## Data Flow Patterns

### **File Upload Flow**
1. User selects file via embedded upload form in `/`
2. POST to `/upload` with multipart form data
3. Server validates file type/size (50MB max)
4. File saved to `/uploads/` with sanitized name
5. Returns JSON confirmation with file path

### **Pipeline Execution Flow**
1. User triggers action via embedded buttons in `/`
2. POST to `/run/ingest` or `/run/render`
3. Server creates UUID for run
4. Pipeline orchestrator executes P2/P3 processes
5. Run metadata stored in `/logs/runs/{run_id}.json`
6. Logs written to `/logs/runs/{run_id}.log`
7. Response includes run status and statistics

### **Report Access Flow**
1. User requests report list via `/reports`
2. Server scans `/reports/` directory
3. Returns JSON array of available reports
4. User selects report for download
5. GET `/reports/{filename}` serves file with security validation

## Security Considerations

### **Input Validation**
- File uploads: Type whitelist (.xlsx, .xls, .csv, .tsv), size limits (50MB), filename sanitization
- Path parameters: Prevent directory traversal
- Query parameters: Validation and sanitization

### **Authentication**
- Currently no authentication implemented
- All endpoints publicly accessible
- Consider adding authentication for production use

### **Error Handling**
- Internal errors logged with full details
- User-facing errors provide meaningful messages
- HTTP status codes properly set

## Performance Considerations

### **File Handling**
- Streaming file uploads to prevent memory issues
- Asynchronous file operations
- Proper cleanup of temporary files

### **Database Operations**
- JSON file storage for run metadata
- Efficient file system operations
- Caching for frequently accessed data
- JSON file storage for run metadata
- Efficient file system operations
- Caching for frequently accessed data

## Monitoring and Observability

### **Health Checks**
- Basic health endpoint available
- Consider adding readiness and liveness probes
- Monitor file system and service dependencies

### **Logging**
- Structured logging with run context
- Log aggregation for troubleshooting
- Performance metrics collection

## Future Enhancements

### **Immediate Priorities**
1. Add user authentication and authorization
2. Implement rate limiting for API endpoints
3. Add file cleanup for old uploads and reports
4. Enhance error pages with user guidance

### **Long-term Goals**
1. Real-time status updates via WebSockets
2. Advanced analytics dashboard
3. Multi-tenant support
4. Automated report scheduling

---

**Note**: This flow map represents the current implementation state. Some UI components (landing page, error pages, runs list view) are implemented but may require additional polish to meet P4 requirements for a teaching-friendly interface.

**Last Updated**: 2026-02-07
**Version**: 1.0.0