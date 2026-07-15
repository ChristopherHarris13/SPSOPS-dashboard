-- Curated views are the only objects the dashboard connects to. They join
-- facts to dimensions so Power BI sees names instead of keys, and expose the
-- is_all / is_all_students flags so report filters stay simple.

CREATE OR ALTER VIEW fact.vw_enrollment AS
SELECT d.school_year, d.sy_label,
       sch.org_code, sch.org_name AS school_name, sch.org_type,
       sch.dist_name AS district_name,
       g.grade_code, g.grade_label, g.grade_order,
       f.enrolled
FROM fact.enrollment f
JOIN dim.date   d   ON d.date_key    = f.date_key
JOIN dim.school sch ON sch.school_key = f.school_key
JOIN dim.grade  g   ON g.grade_key   = f.grade_key;
GO

CREATE OR ALTER VIEW fact.vw_enrollment_by_school AS
SELECT d.school_year, d.sy_label,
       sch.org_code, sch.org_name AS school_name, sch.org_type,
       sch.dist_name AS district_name,
       SUM(f.enrolled) AS total_enrolled
FROM fact.enrollment f
JOIN dim.date   d   ON d.date_key    = f.date_key
JOIN dim.school sch ON sch.school_key = f.school_key
GROUP BY d.school_year, d.sy_label, sch.org_code,
         sch.org_name, sch.org_type, sch.dist_name;
GO

CREATE OR ALTER VIEW fact.vw_attendance AS
SELECT d.school_year, d.sy_label,
       sch.org_code, sch.org_name AS school_name, sch.org_type,
       sch.dist_name AS district_name,
       sg.student_group, sg.is_all_students,
       f.attend_period, f.attend_rate, f.avg_days_absent,
       f.pct_chronic_abs_10, f.pct_chronic_abs_20
FROM fact.attendance f
JOIN dim.date          d   ON d.date_key          = f.date_key
JOIN dim.school        sch ON sch.school_key       = f.school_key
JOIN dim.student_group sg  ON sg.student_group_key = f.student_group_key;
GO

CREATE OR ALTER VIEW fact.vw_staffing AS
SELECT d.school_year, d.sy_label,
       sch.org_code, sch.org_name AS school_name, sch.org_type,
       sch.dist_name AS district_name,
       jc.jobclass_cat, jc.jobclass, jc.is_all,
       f.fte_total
FROM fact.staffing f
JOIN dim.date     d   ON d.date_key     = f.date_key
JOIN dim.school   sch ON sch.school_key  = f.school_key
JOIN dim.jobclass jc  ON jc.jobclass_key = f.jobclass_key;
GO

CREATE OR ALTER VIEW fact.vw_expenditures AS
SELECT d.school_year, d.sy_label,
       sch.dist_name AS district_name,
       f.ind_cat        AS category,
       f.ind_subcat     AS subcategory,
       f.ind_value      AS value,
       f.ind_value_type AS value_type
FROM fact.expenditures f
JOIN dim.date   d   ON d.date_key    = f.date_key
JOIN dim.school sch ON sch.school_key = f.school_key;
GO

-- Flagship page dataset: one row per school-year combining enrollment totals
-- with the All-Students attendance metrics, averaged across attendance periods.
CREATE OR ALTER VIEW fact.vw_operations_summary AS
WITH att_all AS (
    SELECT f.school_key, f.date_key,
           AVG(f.attend_rate)        AS attend_rate,
           AVG(f.avg_days_absent)    AS avg_days_absent,
           AVG(f.pct_chronic_abs_10) AS pct_chronic_abs_10
    FROM fact.attendance f
    JOIN dim.student_group sg ON sg.student_group_key = f.student_group_key
    WHERE sg.is_all_students = 1
    GROUP BY f.school_key, f.date_key
),
enr AS (
    SELECT school_key, date_key, SUM(enrolled) AS total_enrolled
    FROM fact.enrollment
    GROUP BY school_key, date_key
)
SELECT d.school_year, d.sy_label,
       sch.org_code, sch.org_name AS school_name, sch.org_type,
       sch.dist_name AS district_name,
       enr.total_enrolled,
       att_all.attend_rate, att_all.avg_days_absent, att_all.pct_chronic_abs_10
FROM enr
JOIN dim.date   d   ON d.date_key    = enr.date_key
JOIN dim.school sch ON sch.school_key = enr.school_key
LEFT JOIN att_all ON att_all.school_key = enr.school_key
                 AND att_all.date_key   = enr.date_key;
GO
