# Springfield Public Schools — District Operations Dashboard

An end-to-end analytics project that takes raw Massachusetts DESE data for
Springfield Public Schools (the state's third-largest district, ~24,000
students) from flat CSV files through a cloud data warehouse to an interactive
Power BI dashboard covering enrollment, attendance, spending, and data quality.

## Screenshots
<img width="1457" height="807" alt="image" src="https://github.com/user-attachments/assets/f10da2c3-e93c-46cd-a700-b69853f1af6b" />
<img width="1468" height="805" alt="image" src="https://github.com/user-attachments/assets/1d654331-b895-488f-8398-6984844e2048" />
<img width="1438" height="801" alt="image" src="https://github.com/user-attachments/assets/6669288f-e603-4226-a152-7bc8e8720629" />


## Architecture

```
DESE CSV files
      │  load (SSMS Import Flat File)
      ▼
Azure SQL Database
  ├── stg.*    raw staging (all text, loaded verbatim)
  ├── dim.*    conformed dimensions (date, school, grade, student group, job class)
  ├── fact.*   fact tables (enrollment, attendance, staffing, expenditures)
  └── fact.vw_* curated + data-quality views
      │  Import mode
      ▼
Power BI Desktop
  ├── Operations   enrollment & attendance KPIs, trends, by-school breakdown
  ├── Finance      per-pupil spending trend and category breakdown
  └── Data Quality validation checks, coverage windows, lineage reconciliation
```

## Stack

- **Azure SQL Database** — cloud data warehouse 
- **T-SQL** — staging, dimensional model, curated views, validation layer
- **VS Code + MSSQL extension** — query development and source control
- **SSMS** — flat-file loading into staging
- **Power BI Desktop** — data model, DAX measures, three-page report
- **Git / GitHub** — versioning

## Data model

A star schema. Facts join to conformed dimensions on surrogate keys; the
curated views resolve those keys back to friendly names for reporting.

- **Dimensions:** `dim.date`, `dim.school`, `dim.grade`, `dim.student_group`, `dim.jobclass`
- **Facts:** `fact.enrollment` (school × year × grade), `fact.attendance`
  (school × year × period × student group), `fact.staffing` (school × year ×
  job class), `fact.expenditures` (district × year × category)

Two modelling decisions worth calling out:

- **Enrollment is unpivoted** from wide grade columns (PK–G12) into one row per
  grade, so enrollment can be sliced by grade level.
- **Subgroups are preserved.** Attendance and staffing keep their demographic /
  job-class breakdowns, with `is_all_students` / `is_all` flags so the report
  can toggle between district totals and subgroup detail without double-counting.

## Repository layout

```
sql/
  01_schemas.sql         schema creation
  02_staging_ddl.sql     staging tables (all varchar)
  03_verify_staging.sql  post-load sanity checks
  04_star_schema.sql     dimensions, facts, and cleaned load from staging
  05_views.sql           curated reporting views
  06_data_quality.sql    validation / data-quality views
pbix/
  measures.md            DAX measures used in the report
  dashboard.pbix         Power BI file (add after export)
data-raw/                source CSVs 

```

Run the SQL files in numeric order against a fresh Azure SQL database, loading
the CSVs into the `stg.*` tables between steps 2 and 4.

## Data cleaning notes

The raw DESE files store numbers as text with quirks that would break typed
columns, so staging loads everything as `varchar` and casting happens on the
way into the facts:

- Thousands separators (`23,722.9`) stripped with `REPLACE`
- Percent signs (`94.9%`) stripped before casting to decimal
- Blanks and suppression markers handled by `TRY_CAST` (bad values → `NULL`)
- District codes kept as text to preserve leading zeros (`02810000`)

## Data quality

The Data Quality page is backed by four views and reports:

- **Seven named validation checks** (value ranges, non-negativity, foreign-key
  validity, unique keys) — all currently passing
- **Coverage windows per subject** — documenting that per-pupil expenditure data
  runs 2009–2024 (DESE publishes finances on a year-end reporting lag) while
  enrollment and attendance run current
- **Row-count reconciliation** — staging vs. fact, confirming no data loss
  (enrollment intentionally expands via the grade unpivot)

## Production / next steps

This is a working analytics build; scaling it to a production district platform
would add:

- **Automated ingestion** — replace the manual CSV load with a Blob Storage +
  `BULK INSERT` step or an Azure Data Factory pipeline
- **Scheduled refresh** — publish to the Power BI Service and trigger dataset
  refresh via Power Automate
- **Incremental refresh** on the large fact tables rather than full reload
- **Row-level security** for school-level vs. district-level access
- **CI/CD** for the SQL project using a database project + deployment pipeline

## Data source

Massachusetts Department of Elementary and Secondary Education (DESE) —
[School and District Profiles](https://profiles.doe.mass.edu/), Springfield
district code 02810000.
