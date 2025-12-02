# Expected CSV Format for cleaned_master.csv

This document defines the exact column structure that the ResilienceScan application expects in the `cleaned_master.csv` file.

## Critical Required Columns

These columns **MUST** exist for the application to function:

### 1. Identity & Contact (REQUIRED)
- `company_name` - Company/organization name
- `name` - Respondent's full name
- `email_address` - Valid email address (must contain @)
- `function` - Job title/role
- `submitdate` - Survey submission timestamp (format: YYYY-MM-DD HH:MM:SS)

### 2. Metadata
- `reportsent` - Boolean flag for email tracking (True/False)
- `version` - Survey version identifier
- `sector` - Industry sector
- `subsector` - Industry subsector
- `hash` - Unique row identifier
- `rowchecked` - Data validation flag (True/False)

### 3. Score Columns (REQUIRED)

#### Pillar Averages (15 columns):
- Upstream: `up__r`, `up__c`, `up__f`, `up__v`, `up__a`
- Internal: `in__r`, `in__c`, `in__f`, `in__v`, `in__a`
- Downstream: `do__r`, `do__c`, `do__f`, `do__v`, `do__a`

Where:
- `r` = Redundancy
- `c` = Collaboration
- `f` = Flexibility
- `v` = Visibility
- `a` = Agility

#### Individual Question Scores (170+ columns):
Pattern: `{pillar}__{dimension}{question_number}{sub_question}`

Examples:
- `up__r1a`, `up__r1b`, `up__r1c` - Upstream redundancy question 1 sub-parts
- `in__c2` - Internal collaboration question 2
- `do__f3b` - Downstream flexibility question 3 part b

#### Overall Score:
- `overall_scres` - Calculated overall resilience score

### 4. Optional Company Information
- `size_number_of_employees` - Company size
- `value_strategy` - Value strategy type
- `where_is_the_power_in_the_chain` - Supply chain power position
- `position_in_the_value_chain` - Value chain position
- `b2bb2c` - Business model type
- `_competitors`, `_suppliers`, `_customers`, `_productsskus` - Counts
- `customer_order_decoupling_point` - CODP position
- `culture` - Company culture type
- `type_of_company` - Company type classification
- `geographical_footprint_supply_network` - Geographic scope (supply)
- `geographical_footprint_customers` - Geographic scope (customers)
- `language` - Survey language (dutch/english)

## Column Name Variations (Automatic Mapping)

The converter will automatically map these variations:

### Email Address:
- `email_id` → `email_address`
- `email` → `email_address`
- `e-mail` → `email_address`
- `e_mail` → `email_address`
- `mail` → `email_address`
- `contact_email` → `email_address`

### Company Name:
- `company` → `company_name`
- `organization` → `company_name`
- `organisation` → `company_name`
- `firm` → `company_name`
- `business` → `company_name`
- `company_id` → `company_name`

### Respondent Name:
- `respondent` → `name`
- `participant` → `name`
- `respondent_name` → `name`
- `participant_name` → `name`
- `full_name` → `name`

### Submit Date:
- `date` → `submitdate`
- `submit_date` → `submitdate`
- `submission_date` → `submitdate`
- `timestamp` → `submitdate`
- `date_submitted` → `submitdate`

### Function/Role:
- `role` → `function`
- `job_title` → `function`
- `position` → `function`
- `title` → `function`

## Data Types

- **Dates**: String format `YYYY-MM-DD HH:MM:SS`
- **Emails**: String with @ symbol
- **Scores**: Numeric (0-5), NA/NaN for missing
- **Booleans**: `True`/`False` strings
- **Text**: String (UTF-8)

## Score Value Rules

- Valid range: 0.0 to 5.0
- Missing values: NaN or empty
- Invalid values (`?`, `N/A`, text) are converted to NaN during cleaning
- NaN values display as 0 in radar charts (for visualization only)
- NaN values are excluded from average calculations (using na.rm=TRUE)

## Merge Behavior

When converting new Excel files:
- If `cleaned_master.csv` exists: New records are APPENDED
- Duplicates are detected by: (`company_name`, `email_address`)
- Existing records are NOT overwritten
- New columns in Excel are added to the CSV
- Missing columns in Excel are filled with empty values
