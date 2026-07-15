-- Staging mirrors the DESE CSVs as-is. Everything is varchar because the
-- raw files carry %-signs, thousands separators, blanks and suppression
-- markers that would break typed columns. Casting happens on the way to fact.

CREATE TABLE stg.expenditures (
    SY              VARCHAR(10),
    DIST_CODE       VARCHAR(20),
    DIST_NAME       VARCHAR(200),
    IND_CAT         VARCHAR(200),
    IND_SUBCAT      VARCHAR(200),
    IND_VALUE       VARCHAR(50),
    IND_VALUE_TYPE  VARCHAR(50)
);
GO

CREATE TABLE stg.enrollment (
    SY         VARCHAR(10),
    DIST_CODE  VARCHAR(20),
    DIST_NAME  VARCHAR(200),
    ORG_CODE   VARCHAR(20),
    ORG_NAME   VARCHAR(200),
    ORG_TYPE   VARCHAR(50),
    TOTAL_CNT  VARCHAR(20),
    PK_CNT     VARCHAR(20),
    K_CNT      VARCHAR(20),
    G1_CNT     VARCHAR(20),
    G2_CNT     VARCHAR(20),
    G3_CNT     VARCHAR(20),
    G4_CNT     VARCHAR(20),
    G5_CNT     VARCHAR(20),
    G6_CNT     VARCHAR(20),
    G7_CNT     VARCHAR(20),
    G8_CNT     VARCHAR(20),
    G9_CNT     VARCHAR(20),
    G10_CNT    VARCHAR(20),
    G11_CNT    VARCHAR(20),
    G12_CNT    VARCHAR(20),
    SP_CNT     VARCHAR(20),
    AIAN_PCT   VARCHAR(20),
    AS_PCT     VARCHAR(20),
    BAA_PCT    VARCHAR(20),
    HL_PCT     VARCHAR(20),
    MNHL_PCT   VARCHAR(20),
    NHPI_PCT   VARCHAR(20),
    WH_PCT     VARCHAR(20),
    FE_PCT     VARCHAR(20),
    MA_PCT     VARCHAR(20),
    NB_PCT     VARCHAR(20),
    EL_CNT     VARCHAR(20),
    EL_PCT     VARCHAR(20),
    FLNE_CNT   VARCHAR(20),
    FLNE_PCT   VARCHAR(20),
    HN_CNT     VARCHAR(20),
    HN_PCT     VARCHAR(20),
    LI_CNT     VARCHAR(20),
    LI_PCT     VARCHAR(20),
    ECD_CNT    VARCHAR(20),
    ECD_PCT    VARCHAR(20),
    SWD_CNT    VARCHAR(20),
    SWD_PCT    VARCHAR(20)
);
GO

CREATE TABLE stg.staffing (
    SY            VARCHAR(10),
    DIST_CODE     VARCHAR(20),
    DIST_NAME     VARCHAR(200),
    ORG_CODE      VARCHAR(20),
    ORG_NAME      VARCHAR(200),
    ORG_TYPE      VARCHAR(50),
    JOBCLASS_CAT  VARCHAR(200),
    JOBCLASS      VARCHAR(200),
    FTE_TOTAL     VARCHAR(20),
    AIAN_CNT      VARCHAR(20),
    AIAN_PCT      VARCHAR(20),
    AS_CNT        VARCHAR(20),
    AS_PCT        VARCHAR(20),
    BAA_CNT       VARCHAR(20),
    BAA_PCT       VARCHAR(20),
    HL_CNT        VARCHAR(20),
    HL_PCT        VARCHAR(20),
    MNHL_CNT      VARCHAR(20),
    MNHL_PCT      VARCHAR(20),
    NHPI_CNT      VARCHAR(20),
    NHPI_PCT      VARCHAR(20),
    WH_CNT        VARCHAR(20),
    WH_PCT        VARCHAR(20),
    FE_CNT        VARCHAR(20),
    FE_PCT        VARCHAR(20),
    MA_CNT        VARCHAR(20),
    MA_PCT        VARCHAR(20)
);
GO

CREATE TABLE stg.attendance (
    SY                  VARCHAR(10),
    ATTEND_PERIOD       VARCHAR(20),
    DIST_CODE           VARCHAR(20),
    DIST_NAME           VARCHAR(200),
    ORG_CODE            VARCHAR(20),
    ORG_NAME            VARCHAR(200),
    ORG_TYPE            VARCHAR(50),
    STU_GRP             VARCHAR(100),
    ATTEND_RATE         VARCHAR(20),
    CNT_AVG_ABS         VARCHAR(20),
    PCT_ABS_10_DAYS     VARCHAR(20),
    PCT_CHRON_ABS_10    VARCHAR(20),
    PCT_CHRON_ABS_20    VARCHAR(20),
    PCT_UNEXC_10_DAYS   VARCHAR(20),
    DISTRICT_AND_SCHOOL VARCHAR(400)
);
GO
