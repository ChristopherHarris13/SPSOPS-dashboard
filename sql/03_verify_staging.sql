-- Sanity checks after loading the CSVs. All read-only.

-- Row counts should match each file's line count minus its header.
SELECT 'enrollment'   AS table_name, COUNT(*) AS row_count FROM stg.enrollment
UNION ALL SELECT 'attendance',   COUNT(*) FROM stg.attendance
UNION ALL SELECT 'staffing',     COUNT(*) FROM stg.staffing
UNION ALL SELECT 'expenditures', COUNT(*) FROM stg.expenditures;

SELECT TOP 5 * FROM stg.enrollment;
SELECT TOP 5 * FROM stg.attendance;
SELECT TOP 5 * FROM stg.staffing;
SELECT TOP 5 * FROM stg.expenditures;

-- DIST_CODE must keep its leading zero (02810000). If it reads 2810000
-- the column was imported as a number and the join keys are broken.
SELECT DISTINCT DIST_CODE FROM stg.enrollment;
SELECT DISTINCT DIST_CODE FROM stg.staffing;

SELECT 'enrollment' AS src, SY, COUNT(*) AS n FROM stg.enrollment GROUP BY SY
UNION ALL SELECT 'attendance',   SY, COUNT(*) FROM stg.attendance   GROUP BY SY
UNION ALL SELECT 'staffing',     SY, COUNT(*) FROM stg.staffing     GROUP BY SY
UNION ALL SELECT 'expenditures', SY, COUNT(*) FROM stg.expenditures GROUP BY SY
ORDER BY src, SY;

-- Numeric-looking columns that don't cast cleanly. TOTAL_CNT and FTE_TOTAL
-- return thousands-comma values (1,103); ATTEND_RATE and IND_VALUE return
-- %-signs and commas. These are expected and get cleaned in the fact load.
SELECT DISTINCT TOTAL_CNT
FROM stg.enrollment
WHERE TRY_CAST(TOTAL_CNT AS INT) IS NULL AND TOTAL_CNT IS NOT NULL;

SELECT DISTINCT FTE_TOTAL
FROM stg.staffing
WHERE TRY_CAST(FTE_TOTAL AS DECIMAL(10,2)) IS NULL AND FTE_TOTAL IS NOT NULL;

SELECT DISTINCT ATTEND_RATE
FROM stg.attendance
WHERE TRY_CAST(ATTEND_RATE AS DECIMAL(10,2)) IS NULL AND ATTEND_RATE IS NOT NULL;

SELECT DISTINCT IND_VALUE
FROM stg.expenditures
WHERE TRY_CAST(IND_VALUE AS DECIMAL(18,2)) IS NULL AND IND_VALUE IS NOT NULL;

-- Subgroup rows to be aware of before modelling: attendance carries a
-- STU_GRP breakdown and staffing a JOBCLASS breakdown, each with an "All" row.
SELECT DISTINCT STU_GRP FROM stg.attendance ORDER BY STU_GRP;
SELECT DISTINCT JOBCLASS_CAT FROM stg.staffing ORDER BY JOBCLASS_CAT;
