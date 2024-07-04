DECLARE @FromDate DateTime = '2023-11-01' -- '2022-11-01'
DECLARE @ToDate DateTime = '2024-04-30' -- '2023-10-31'

SELECT
	PAT.patientid AS PID_PDMS,
	W.patid AS PID_KISPI,
	W.fallid AS FID_KISPI,
	CAST(W.datum AS DATE) AS Date,
	CAST(ROUND(MIN(W.gewicht), 3) AS FLOAT) AS Weight_min_KG,
	CAST(ROUND(MAX(W.gewicht), 3) AS FLOAT) AS Weight_max_KG,
	CAST(ROUND(MIN(W.laenge), 3) AS FLOAT) AS Length_min_CM,
	CAST(ROUND(MAX(W.laenge), 3) AS FLOAT) AS Length_max_CM,
	CAST(ROUND(MIN(W.kopfumfang), 3) AS FLOAT) AS Head_min_CM,
	CAST(ROUND(MAX(W.kopfumfang), 3) AS FLOAT) AS Head_max_CM
FROM [CDMH_PSA].phx_out.psa_bas_wachstum_cur W
JOIN [CDMH_PSA].mv5_out.psa_patients_cur PAT ON CAST(W.fallid AS NVARCHAR) = PAT.socialsecurity
WHERE W.datum BETWEEN @FromDate AND @ToDate
GROUP BY PAT.patientid, W.patid, W.fallid, CAST(W.datum AS DATE)

SELECT 
	S.patientid AS PID_PDMS,
	PAT.hospitalnumber AS PID_KISPI,
	PAT.socialsecurity AS FID_KISPI,
	CAST(S.time AS DATE) AS Date,
	MIN(CASE WHEN S.parameterid = 25363 THEN S.Value END) AS Hb_min_gperl,
	MAX(CASE WHEN parameterid = 25363 THEN S.Value END) AS Hb_max_gperl,
	MIN(CASE WHEN S.parameterid = 28790 THEN ROUND(S.Value*1000,2) END) AS Ca_min_mmolperl,
	MAX(CASE WHEN parameterid = 28790 THEN ROUND(S.Value*1000,2) END) AS Ca_max_mmolperl,
	MIN(CASE WHEN S.parameterid = 14255 THEN ROUND(S.Value*1000,2) END) AS Mg_min_mmolperl, --*1000 since [mol/l -> mmol/l]
	MAX(CASE WHEN parameterid = 14255 THEN ROUND(S.Value*1000,2) END) AS Mg_max_mmolperl, 
	MIN(CASE WHEN S.parameterid = 14262 THEN ROUND(S.Value*1000,2) END) AS Triglyc_min_mmolperl, --*1000 since [mol/l -> mmol/l]
	MAX(CASE WHEN parameterid = 14262 THEN ROUND(S.Value*1000,2) END) AS Triglyc_max_mmolperl, 
	MIN(CASE WHEN S.parameterid = 14275 THEN S.Value END) AS Alb_min_gperl,
	MAX(CASE WHEN parameterid = 14275 THEN S.Value END) AS Alb_max_gperl,
	MIN(CASE WHEN S.parameterid = 28783 THEN ROUND(S.Value*1000,2) END) AS CRP_min_mgperl, --*1000 since [g/l -> mg/l]
	MAX(CASE WHEN parameterid = 28783 THEN ROUND(S.Value*1000,2) END) AS CRP_max_mgperl,
	MIN(CASE WHEN S.parameterid = 14274 THEN ROUND(S.Value*1000,2) END) AS Harn_min_mmolperl, --*1000 since [g/l -> mg/l]
	MAX(CASE WHEN parameterid = 14274 THEN ROUND(S.Value*1000,2) END) AS Harn_max_mmolperl,
	MIN(CASE WHEN S.parameterid = 20779 THEN S.Value*1000000 END) AS Krea_min_umolperl, --*1000000 since [mol/l -> umol/l]
	MAX(CASE WHEN parameterid = 20779 THEN S.Value*1000000 END) AS Krea_max_umolperl,
	MIN(CASE WHEN S.parameterid = 948 THEN S.Value END) AS pH_min,
	MAX(CASE WHEN parameterid = 948 THEN S.Value END) AS pH_max,
	MIN(CASE WHEN S.parameterid = 967 THEN ROUND(S.Value/7.501,2) END) AS pO2_min_kPa,
	MAX(CASE WHEN parameterid = 967 THEN ROUND(S.Value/7.501,2) END) AS pO2_max_kPa, -- /7.501 since [mmHg -> kPa]
	MIN(CASE WHEN S.parameterid = 959 THEN ROUND(S.Value/7.501,2) END) AS pCO2_min_kPa,
	MAX(CASE WHEN parameterid = 959 THEN ROUND(S.Value/7.501,2) END) AS pCO2_max_kPa,
	MIN(CASE WHEN S.parameterid = 27 THEN ROUND(S.Value*1000,2) END) AS Bicarbo_min_mmolperl, --*1000 since [mol/l -> mmol/l]
	MAX(CASE WHEN parameterid = 27 THEN ROUND(S.Value*1000,2) END) AS Bicarbo_max_mmolperl,
	MIN(CASE WHEN S.parameterid = 1214 THEN ROUND(S.Value*1000,2) END) AS BE_min_mmolperl, --*1000 since [mol/l -> mmol/l]
	MAX(CASE WHEN parameterid = 1214 THEN ROUND(S.Value*1000,2) END) AS BE_max_mmolperl,
	MIN(CASE WHEN S.parameterid = 1216 THEN S.Value*1000 END) AS Na_min_mmolperl, --*1000 since [mol/l -> mmol/l]
	MAX(CASE WHEN parameterid = 1216 THEN S.Value*1000 END) AS Na_max_mmolperl,
	MIN(CASE WHEN S.parameterid = 245 THEN ROUND(S.Value*1000,1) END) AS K_min_mmolperl, --*1000 since [mol/l -> mmol/l]
	MAX(CASE WHEN parameterid = 245 THEN ROUND(S.Value*1000,1) END) AS K_max_mmolperl,
	MIN(CASE WHEN S.parameterid = 246 THEN ROUND(S.Value*1000,1) END) AS Gluc_min_mmolperl, --*1000 since [mol/l -> mmol/l]
	MAX(CASE WHEN parameterid = 246 THEN ROUND(S.Value*1000,1) END) AS Gluc_max_mmolperl
--FROM [CDMH_PSA].mv5_out.psa_Signals_cur S
--FROM [dwh-sql-d].[CDMH_PSA].[mv5].[psa_Signals] S
FROM [dwh-sql-d].[Prototyping].[tmpTab].[tmp_PDMS_signals_NUMETA] S -- since runs on P; Signals, which are not completed there
JOIN [CDMH_PSA].mv5_out.psa_patients_cur PAT ON S.patientid = PAT.patientid
WHERE S.time BETWEEN @FromDate AND @ToDate
GROUP BY S.patientid, PAT.hospitalnumber, PAT.socialsecurity, CAST(S.time AS DATE)