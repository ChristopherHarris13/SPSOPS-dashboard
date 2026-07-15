-- Validation layer feeding the Data Quality dashboard page.

-- Row counts either side of the stg -> fact load. Enrollment intentionally
-- grows because of the grade unpivot; the others reconcile 1:1.
CREATE OR ALTER VIEW fact.vw_dq_rowcounts AS
SELECT 'enrollment' AS subject,
       (SELECT COUNT(*) FROM stg.enrollment)  AS staging_rows,
       (SELECT COUNT(*) FROM fact.enrollment) AS fact_rows
UNION ALL
SELECT 'attendance',
       (SELECT COUNT(*) FROM stg.attendance), (SELECT COUNT(*) FROM fact.attendance)
UNION ALL
SELECT 'staffing',
       (SELECT COUNT(*) FROM stg.staffing), (SELECT COUNT(*) FROM fact.staffing)
UNION ALL
SELECT 'expenditures',
       (SELECT COUNT(*) FROM stg.expenditures), (SELECT COUNT(*) FROM fact.expenditures);
GO

-- Year window per subject. Documents the real coverage, e.g. expenditures
-- stop at 2024 because of DESE's year-end financial reporting lag.
CREATE OR ALTER VIEW fact.vw_dq_coverage AS
SELECT 'enrollment' AS subject,
       MIN(d.school_year) AS first_year, MAX(d.school_year) AS last_year,
       COUNT(DISTINCT d.school_year) AS years_covered
FROM fact.enrollment f JOIN dim.date d ON d.date_key = f.date_key
UNION ALL
SELECT 'attendance', MIN(d.school_year), MAX(d.school_year), COUNT(DISTINCT d.school_year)
FROM fact.attendance f JOIN dim.date d ON d.date_key = f.date_key
UNION ALL
SELECT 'staffing', MIN(d.school_year), MAX(d.school_year), COUNT(DISTINCT d.school_year)
FROM fact.staffing f JOIN dim.date d ON d.date_key = f.date_key
UNION ALL
SELECT 'expenditures', MIN(d.school_year), MAX(d.school_year), COUNT(DISTINCT d.school_year)
FROM fact.expenditures f JOIN dim.date d ON d.date_key = f.date_key;
GO

-- Named validation rules. Each returns a fail count; add rules here as the
-- data set grows. pass_fail = PASS when nothing violates the rule.
CREATE OR ALTER VIEW fact.vw_dq_checks AS
SELECT 'Enrollment non-negative' AS check_name, COUNT(*) AS fail_count,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS pass_fail
FROM fact.enrollment WHERE enrolled < 0
UNION ALL
SELECT 'Attendance rate 0-100', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact.attendance
WHERE attend_rate IS NOT NULL AND (attend_rate < 0 OR attend_rate > 100)
UNION ALL
SELECT 'Chronic absence 0-100', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact.attendance
WHERE pct_chronic_abs_10 IS NOT NULL AND (pct_chronic_abs_10 < 0 OR pct_chronic_abs_10 > 100)
UNION ALL
SELECT 'Staffing FTE non-negative', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact.staffing WHERE fte_total < 0
UNION ALL
SELECT 'Per-pupil spend positive', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact.expenditures
WHERE ind_subcat = 'Total Expenditures' AND ind_value IS NOT NULL AND ind_value <= 0
UNION ALL
SELECT 'Enrollment school FK valid', COUNT(*),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact.enrollment f
LEFT JOIN dim.school s ON s.school_key = f.school_key
WHERE s.school_key IS NULL
UNION ALL
SELECT 'School codes unique',
       CASE WHEN COUNT(*) = COUNT(DISTINCT org_code) THEN 0 ELSE 1 END,
       CASE WHEN COUNT(*) = COUNT(DISTINCT org_code) THEN 'PASS' ELSE 'FAIL' END
FROM dim.school;
GO

-- The rows behind any failing check, for drill-down. Empty means all clean.
CREATE OR ALTER VIEW fact.vw_dq_flagged AS
SELECT 'Attendance rate out of range' AS issue,
       sch.org_name AS school_name, d.school_year,
       CAST(f.attend_rate AS VARCHAR(20)) AS bad_value
FROM fact.attendance f
JOIN dim.school sch ON sch.school_key = f.school_key
JOIN dim.date   d   ON d.date_key    = f.date_key
WHERE f.attend_rate IS NOT NULL AND (f.attend_rate < 0 OR f.attend_rate > 100)
UNION ALL
SELECT 'Negative enrollment', sch.org_name, d.school_year, CAST(f.enrolled AS VARCHAR(20))
FROM fact.enrollment f
JOIN dim.school sch ON sch.school_key = f.school_key
JOIN dim.date   d   ON d.date_key    = f.date_key
WHERE f.enrolled < 0
UNION ALL
SELECT 'Negative FTE', sch.org_name, d.school_year, CAST(f.fte_total AS VARCHAR(20))
FROM fact.staffing f
JOIN dim.school sch ON sch.school_key = f.school_key
JOIN dim.date   d   ON d.date_key    = f.date_key
WHERE f.fte_total < 0;
GO
