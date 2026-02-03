description: Implement the reporting engine that renders SCROL-style strategic reports using Quarto, driven by the canonical cleaned_master.csv

PHASE TASK (REPORTING CORE)
This phase turns normalized data into reproducible, SCROL-style outputs.
No web UI yet; reports are generated programmatically inside the container.
input: project: "ResilienceScan" architecture_reference: "outputs/architecture/resiliencescan_architecture_and_principles.md" ingestion_reference: "P2_resiliencescan_data_ingestion_and_normalization" canonical_dataset: "data/cleaned_master.csv" render_targets: - pdf - html report_modes: - strategic_overview # SCROL-style, aggregate-first - appendix_optional # detailed tables, optional

steps:

Establish the reporting structure:
reports/templates/ (Quarto .qmd templates)
reports/outputs/ (rendered PDFs/HTML)
reports/assets/ (logos, CSS, fonts)
Create SCROL-style Quarto templates:
Strategic Overview report (.qmd)
Clear section hierarchy:
Executive Strategic Overview
Resilience Landscape
Key Drivers & Tensions
Confidence, Blind Spots, and Limits
How to Read This Report
Templates must:
Render even if some sections are empty
Avoid KPI-heavy tables in the main narrative
Implement parameterized rendering:
Pass parameters from Python to Quarto
Support:
full dataset overview
filtered views (e.g. by company, cohort, scenario)
Integrate R where appropriate:
Data summarization and aggregation
Plot generation for SCROL-style visuals (optional in this phase)
Ensure reproducibility:
Fixed seeds where randomness is used
Explicit package versions (R + Python)
Deterministic file paths
Implement a render orchestrator:
app/render.py
Takes input parameters
Calls Quarto
Writes outputs to reports/outputs/
Logs render metadata (time, parameters, success/failure)
Validate rendering:
PDF renders without LaTeX errors
HTML renders correctly
Missing data results in warnings, not crashes
output: format: files generated_artifacts: - reports/templates/strategic_scrol_overview.qmd - app/render.py - reports/outputs/ (generated examples) - logs/render.log documentation: - path: outputs/architecture/P3_reporting_engine_design.md

constraints:

"Use cleaned_master.csv as the single data source"
"No hardcoded organization-specific content"
"No web UI in this phase"
"SCROL principles must be reflected in structure and language"
"Reports must render in a headless container"
style: reporting_philosophy: - patterns_over_metrics - aggregate_before_detail - uncertainty_is_explicit failure_mode: - log_and_continue_when_safe - fail_loud_on_render_errors

success_criteria:

"At least one SCROL-style PDF and HTML report renders successfully"
"Rendering is fully automated and repeatable"
"No manual Quarto steps required inside the container"
"Outputs are suitable for teaching and decision-making"