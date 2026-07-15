-- Dimensional model. Drops are ordered facts-first so the script re-runs
-- cleanly. Cleaning on load: strip commas and %-signs, then TRY_CAST so any
-- stray value lands as NULL instead of failing the whole insert.

SET NOCOUNT ON;

IF OBJECT_ID('fact.enrollment')   IS NOT NULL DROP TABLE fact.enrollment;
IF OBJECT_ID('fact.attendance')   IS NOT NULL DROP TABLE fact.attendance;
IF OBJECT_ID('fact.staffing')     IS NOT NULL DROP TABLE fact.staffing;
IF OBJECT_ID('fact.expenditures') IS NOT NULL DROP TABLE fact.expenditures;
IF OBJECT_ID('dim.school')        IS NOT NULL DROP TABLE dim.school;
IF OBJECT_ID('dim.date')          IS NOT NULL DROP TABLE dim.date;
IF OBJECT_ID('dim.student_group') IS NOT NULL DROP TABLE dim.student_group;
IF OBJECT_ID('dim.jobclass')      IS NOT NULL DROP TABLE dim.jobclass;
IF OBJECT_ID('dim.grade')         IS NOT NULL DROP TABLE dim.grade;
GO

CREATE TABLE dim.date (
    date_key     INT IDENTITY(1,1) PRIMARY KEY,
    school_year  INT        NOT NULL UNIQUE,
    sy_label     VARCHAR(9) NOT NULL
);
GO

-- DESE codes a school year by its ending year, so SY 2026 = the 2025-2026 year.
INSERT INTO dim.date (school_year, sy_label)
SELECT DISTINCT
       TRY_CAST(SY AS INT),
       CAST(TRY_CAST(SY AS INT) - 1 AS VARCHAR(4)) + '-' + CAST(TRY_CAST(SY AS INT) AS VARCHAR(4))
FROM (
    SELECT SY FROM stg.enrollment
    UNION SELECT SY FROM stg.attendance
    UNION SELECT SY FROM stg.staffing
    UNION SELECT SY FROM stg.expenditures
) y
WHERE TRY_CAST(SY AS INT) IS NOT NULL;
GO

CREATE TABLE dim.school (
    school_key   INT IDENTITY(1,1) PRIMARY KEY,
    org_code     VARCHAR(20) NOT NULL UNIQUE,
    org_name     VARCHAR(200),
    org_type     VARCHAR(50),
    dist_code    VARCHAR(20),
    dist_name    VARCHAR(200)
);
GO

-- One row per org code across all three school-level sources. ORG_TYPE keeps
-- the district-level rollup row distinguishable from actual schools.
INSERT INTO dim.school (org_code, org_name, org_type, dist_code, dist_name)
SELECT org_code, org_name, org_type, dist_code, dist_name
FROM (
    SELECT ORG_CODE AS org_code, ORG_NAME AS org_name, ORG_TYPE AS org_type,
           DIST_CODE AS dist_code, DIST_NAME AS dist_name,
           ROW_NUMBER() OVER (PARTITION BY ORG_CODE ORDER BY ORG_NAME) AS rn
    FROM (
        SELECT ORG_CODE, ORG_NAME, ORG_TYPE, DIST_CODE, DIST_NAME FROM stg.enrollment
        UNION ALL
        SELECT ORG_CODE, ORG_NAME, ORG_TYPE, DIST_CODE, DIST_NAME FROM stg.attendance
        UNION ALL
        SELECT ORG_CODE, ORG_NAME, ORG_TYPE, DIST_CODE, DIST_NAME FROM stg.staffing
    ) all_orgs
    WHERE ORG_CODE IS NOT NULL
) deduped
WHERE rn = 1;
GO

CREATE TABLE dim.grade (
    grade_key    INT IDENTITY(1,1) PRIMARY KEY,
    grade_code   VARCHAR(10) NOT NULL UNIQUE,
    grade_order  INT         NOT NULL,
    grade_label  VARCHAR(20) NOT NULL
);
GO

INSERT INTO dim.grade (grade_code, grade_order, grade_label) VALUES
    ('PK', 0,'Pre-K'), ('K',1,'Kindergarten'),
    ('G1',2,'Grade 1'),('G2',3,'Grade 2'),('G3',4,'Grade 3'),
    ('G4',5,'Grade 4'),('G5',6,'Grade 5'),('G6',7,'Grade 6'),
    ('G7',8,'Grade 7'),('G8',9,'Grade 8'),('G9',10,'Grade 9'),
    ('G10',11,'Grade 10'),('G11',12,'Grade 11'),('G12',13,'Grade 12'),
    ('SP',14,'Special/Ungraded');
GO

CREATE TABLE dim.student_group (
    student_group_key INT IDENTITY(1,1) PRIMARY KEY,
    student_group     VARCHAR(100) NOT NULL UNIQUE,
    is_all_students   BIT NOT NULL
);
GO

INSERT INTO dim.student_group (student_group, is_all_students)
SELECT DISTINCT STU_GRP,
       CASE WHEN STU_GRP = 'All Students' THEN 1 ELSE 0 END
FROM stg.attendance
WHERE STU_GRP IS NOT NULL;
GO

CREATE TABLE dim.jobclass (
    jobclass_key   INT IDENTITY(1,1) PRIMARY KEY,
    jobclass_cat   VARCHAR(200) NOT NULL,
    jobclass       VARCHAR(200) NOT NULL,
    is_all         BIT NOT NULL,
    CONSTRAINT UQ_jobclass UNIQUE (jobclass_cat, jobclass)
);
GO

INSERT INTO dim.jobclass (jobclass_cat, jobclass, is_all)
SELECT DISTINCT JOBCLASS_CAT, JOBCLASS,
       CASE WHEN JOBCLASS_CAT = 'All' AND JOBCLASS = 'All' THEN 1 ELSE 0 END
FROM stg.staffing
WHERE JOBCLASS_CAT IS NOT NULL AND JOBCLASS IS NOT NULL;
GO

CREATE TABLE fact.enrollment (
    school_key  INT NOT NULL REFERENCES dim.school(school_key),
    date_key    INT NOT NULL REFERENCES dim.date(date_key),
    grade_key   INT NOT NULL REFERENCES dim.grade(grade_key),
    enrolled    INT NULL
);
GO

CREATE TABLE fact.attendance (
    school_key         INT NOT NULL REFERENCES dim.school(school_key),
    date_key           INT NOT NULL REFERENCES dim.date(date_key),
    student_group_key  INT NOT NULL REFERENCES dim.student_group(student_group_key),
    attend_period      VARCHAR(20),
    attend_rate        DECIMAL(5,2) NULL,
    avg_days_absent    DECIMAL(6,2) NULL,
    pct_chronic_abs_10 DECIMAL(5,2) NULL,
    pct_chronic_abs_20 DECIMAL(5,2) NULL
);
GO

CREATE TABLE fact.staffing (
    school_key    INT NOT NULL REFERENCES dim.school(school_key),
    date_key      INT NOT NULL REFERENCES dim.date(date_key),
    jobclass_key  INT NOT NULL REFERENCES dim.jobclass(jobclass_key),
    fte_total     DECIMAL(10,1) NULL
);
GO

CREATE TABLE fact.expenditures (
    school_key     INT NOT NULL REFERENCES dim.school(school_key),
    date_key       INT NOT NULL REFERENCES dim.date(date_key),
    ind_cat        VARCHAR(200),
    ind_subcat     VARCHAR(200),
    ind_value      DECIMAL(18,2) NULL,
    ind_value_type VARCHAR(50)
);
GO

-- Grade columns (PK_CNT..SP_CNT) get unpivoted into one row per grade so the
-- fact can be sliced at grade level. Empty grade cells are filtered out.
INSERT INTO fact.enrollment (school_key, date_key, grade_key, enrolled)
SELECT sch.school_key, d.date_key, g.grade_key,
       TRY_CAST(REPLACE(up.enrolled, ',', '') AS INT)
FROM stg.enrollment e
CROSS APPLY (VALUES
        ('PK', e.PK_CNT), ('K', e.K_CNT),
        ('G1', e.G1_CNT), ('G2', e.G2_CNT), ('G3', e.G3_CNT),
        ('G4', e.G4_CNT), ('G5', e.G5_CNT), ('G6', e.G6_CNT),
        ('G7', e.G7_CNT), ('G8', e.G8_CNT), ('G9', e.G9_CNT),
        ('G10',e.G10_CNT),('G11',e.G11_CNT),('G12',e.G12_CNT),
        ('SP', e.SP_CNT)
     ) up(grade_code, enrolled)
JOIN dim.school sch ON sch.org_code  = e.ORG_CODE
JOIN dim.date   d   ON d.school_year = TRY_CAST(e.SY AS INT)
JOIN dim.grade  g   ON g.grade_code  = up.grade_code
WHERE TRY_CAST(REPLACE(up.enrolled, ',', '') AS INT) IS NOT NULL;
GO

INSERT INTO fact.attendance
    (school_key, date_key, student_group_key, attend_period,
     attend_rate, avg_days_absent, pct_chronic_abs_10, pct_chronic_abs_20)
SELECT sch.school_key, d.date_key, sg.student_group_key, a.ATTEND_PERIOD,
       TRY_CAST(REPLACE(a.ATTEND_RATE,      '%','') AS DECIMAL(5,2)),
       TRY_CAST(REPLACE(a.CNT_AVG_ABS,      ',','') AS DECIMAL(6,2)),
       TRY_CAST(REPLACE(a.PCT_CHRON_ABS_10, '%','') AS DECIMAL(5,2)),
       TRY_CAST(REPLACE(a.PCT_CHRON_ABS_20, '%','') AS DECIMAL(5,2))
FROM stg.attendance a
JOIN dim.school        sch ON sch.org_code     = a.ORG_CODE
JOIN dim.date          d   ON d.school_year    = TRY_CAST(a.SY AS INT)
JOIN dim.student_group sg  ON sg.student_group = a.STU_GRP;
GO

INSERT INTO fact.staffing (school_key, date_key, jobclass_key, fte_total)
SELECT sch.school_key, d.date_key, jc.jobclass_key,
       TRY_CAST(REPLACE(s.FTE_TOTAL, ',','') AS DECIMAL(10,1))
FROM stg.staffing s
JOIN dim.school   sch ON sch.org_code    = s.ORG_CODE
JOIN dim.date     d   ON d.school_year   = TRY_CAST(s.SY AS INT)
JOIN dim.jobclass jc  ON jc.jobclass_cat = s.JOBCLASS_CAT
                     AND jc.jobclass     = s.JOBCLASS;
GO

-- Expenditures are district-level; join to the district row via DIST_CODE.
INSERT INTO fact.expenditures
    (school_key, date_key, ind_cat, ind_subcat, ind_value, ind_value_type)
SELECT sch.school_key, d.date_key, x.IND_CAT, x.IND_SUBCAT,
       TRY_CAST(REPLACE(x.IND_VALUE, ',','') AS DECIMAL(18,2)),
       x.IND_VALUE_TYPE
FROM stg.expenditures x
JOIN dim.date   d   ON d.school_year = TRY_CAST(x.SY AS INT)
JOIN dim.school sch ON sch.org_code  = x.DIST_CODE;
GO

SELECT 'dim.school'        AS obj, COUNT(*) AS rows FROM dim.school
UNION ALL SELECT 'dim.date',           COUNT(*) FROM dim.date
UNION ALL SELECT 'dim.grade',          COUNT(*) FROM dim.grade
UNION ALL SELECT 'dim.student_group',  COUNT(*) FROM dim.student_group
UNION ALL SELECT 'dim.jobclass',       COUNT(*) FROM dim.jobclass
UNION ALL SELECT 'fact.enrollment',    COUNT(*) FROM fact.enrollment
UNION ALL SELECT 'fact.attendance',    COUNT(*) FROM fact.attendance
UNION ALL SELECT 'fact.staffing',      COUNT(*) FROM fact.staffing
UNION ALL SELECT 'fact.expenditures',  COUNT(*) FROM fact.expenditures;
GO

SELECT COUNT(*) AS enrollment_unmatched
FROM stg.enrollment e
LEFT JOIN dim.school sch ON sch.org_code = e.ORG_CODE
WHERE sch.school_key IS NULL;
GO
