
DECLARE @FromDate DateTime = '2022-11-01' -- '2023-11-01'
DECLARE @ToDate DateTime = '2023-10-31'; -- '2024-04-30'

WITH Table_RS_S AS (
	SELECT
		PatientID AS patientid,
		ParameterID,
		777 AS Status, -- Signals don't have a status (777) since they are applied anyway
		Time AS StartTime,
		NULL AS Endtime,
		Value, -- Value = amount
		Error
	FROM [dwh-sql-d].[Prototyping].[tmpTab].[tmp_PDMS_signals_NUMETA] -- since runs on P; Signals, which are not completed there

	UNION

	SELECT
		PatientID AS patientid,
		ParameterID,
		status AS Status,
		StartTime,
		Endtime,
		(DATEDIFF(MINUTE, StartTime, EndTime)*Value) AS Value, -- 'Value' = rate per min -> so you need to multiply by the duration in min
		NULL AS Error -- RangeSignals don't have errors; set to NULL
	FROM [CDMH_PSA].mv5_out.psa_rangesignals_cur
	)


SELECT DISTINCT
	RS.patientid AS PID_PDMS, 
	PAT.hospitalnumber AS PID_KISPI, 
	PAT.socialsecurity AS FID_KISPI,
	IPSSTAT.GEBDATUM AS Birthdate,
	IPSSTAT.IPSEINTRITT AS IPS_Admission,
	IPSSTAT.IPSAUSTRITT AS IPS_Discharge,
	IPSSTAT.LOS,
	DATEDIFF(DAY, IPSSTAT.GEBDATUM, IPSSTAT.IPSEINTRITT) / 365.25 AS Age_Years,
	(KONZEPT.ssw_k + KONZEPT.ssw_t_k/7.0) AS GA_Weeks, --important '7.0'; since '7' will result in 0
	CASE
		WHEN DATEDIFF(DAY, IPSSTAT.GEBDATUM, IPSSTAT.IPSEINTRITT) / 365.25 > 2 AND DATEDIFF(DAY, IPSSTAT.GEBDATUM, IPSSTAT.IPSEINTRITT) / 365.25 <=18 THEN 'Child'
		WHEN DATEDIFF(DAY, IPSSTAT.GEBDATUM, IPSSTAT.IPSEINTRITT) / 365.25 <= 2 AND (KONZEPT.ssw_k + KONZEPT.ssw_t_k/7.0) > 37 THEN 'Infant'
		WHEN DATEDIFF(DAY, IPSSTAT.GEBDATUM, IPSSTAT.IPSEINTRITT) / 365.25 <= 2 AND (KONZEPT.ssw_k + KONZEPT.ssw_t_k/7.0) <= 37 THEN 'Preterm Infant'
	END AS Age_Group,
	IPSSTAT.HAUPTDIAGNOSE AS Hauptdiagnose,
	IPSSTAT.WICHTIGSTE_DIAGNOSE AS Wichtigste_Diagnose,
	IPSSTAT.INTERVENTION AS Intervention,
	CASE	
		-- HAUPTDIAGNOSE needs to be numeric (old=with letters) or NULL, and INTERVENTION numeric or NULL (if no intervention)
		WHEN ((ISNUMERIC(IPSSTAT.HAUPTDIAGNOSE)=1 OR IPSSTAT.HAUPTDIAGNOSE IS NULL) AND (ISNUMERIC(IPSSTAT.INTERVENTION)=1 OR IPSSTAT.INTERVENTION IS NULL))
		THEN CASE
			--for sure post-surgerey
			WHEN (IPSSTAT.HAUPTDIAGNOSE >= 1100) OR (IPSSTAT.INTERVENTION IS NOT NULL) THEN 1
			--for sure not post-surgery 
			WHEN (IPSSTAT.HAUPTDIAGNOSE < 1100) AND (IPSSTAT.INTERVENTION IS NULL) THEN 0 --m_interv1 is NULL when no intervention
			--making a statement is not possible
			WHEN (IPSSTAT.HAUPTDIAGNOSE IS NULL) AND (IPSSTAT.INTERVENTION IS NULL) THEN NULL
			ELSE NULL
		END
		ELSE NULL
	END as Post_Surgery,
	CASE
		-- HAUPTDIAGNOSE/WICHTIGSTE_DIAGNOSE need to be numeric (old=with letters) or NULL (let's consider them), and INTERVENTION numeric or NULL (if no intervention)
		WHEN ((ISNUMERIC(IPSSTAT.HAUPTDIAGNOSE)=1 OR IPSSTAT.HAUPTDIAGNOSE IS NULL) AND (ISNUMERIC(IPSSTAT.WICHTIGSTE_DIAGNOSE)=1 OR IPSSTAT.WICHTIGSTE_DIAGNOSE IS NULL) AND (ISNUMERIC(IPSSTAT.INTERVENTION)=1 OR IPSSTAT.INTERVENTION IS NULL))
		THEN CASE
			--for sure cardio
			WHEN ((IPSSTAT.HAUPTDIAGNOSE BETWEEN '200' AND '299') OR (IPSSTAT.WICHTIGSTE_DIAGNOSE BETWEEN '200' AND '299') OR (IPSSTAT.INTERVENTION BETWEEN '1200' AND '1299')) THEN 1
			--for sure not cardio
			WHEN ((IPSSTAT.HAUPTDIAGNOSE NOT BETWEEN '200' AND '299') AND (IPSSTAT.WICHTIGSTE_DIAGNOSE NOT BETWEEN '200' AND '299') AND ((IPSSTAT.INTERVENTION NOT BETWEEN '1200' AND '1299') OR (IPSSTAT.INTERVENTION IS NULL))) THEN 0 --m_interv1 allowed to be NUL (no intervention), while others cannot be missing (if missing, we cannot say if cardio or not)
			--not sure
			ELSE NULL
		END
		ELSE NULL
	END as Cardio,
	DATAPRO.forschungsfreigabe_1 AS General_Consent,
	RS.parameterid AS ParameterID, 
	P.parametername AS ParameterName, 
	P.abbreviation AS ParameterAbbr, 
	RS.Status AS Status,
	RS.StartTime AS StartTime, 
	RS.EndTime AS EndTime, 
	(RS.Value/U.multiplier) AS Wert, -- Value needs to be divided by its Multiplicator in order to match the indicated Unit
	U.unitname AS Unit --will be part of the Parameter-Column-Names (_<UNIT>)
FROM Table_RS_S RS
JOIN [CDMH_PSA].mv5_out.psa_parameters_mv5_cur P ON RS.parameterid = P.parameterid
JOIN [CDMH_PSA].mv5_out.psa_units_mv5_cur U ON P.unitid = U.unitid -- for Multiplicator and Unit
JOIN [CDMH_PSA].mv5_out.psa_patients_cur PAT ON RS.patientid = PAT.patientid
JOIN [phx]..[PHOENIX].[V_IPS_STATISTIK] IPSSTAT ON PAT.socialsecurity = CAST(IPSSTAT.FALLID AS NVARCHAR) 
	--since multiple rows per FID (due to multiple NEBENDIAGNOSE and multiple IPSEINTRITT (in case of IPS<->Neo) for the same case), but only one / HAUPT / WICHTIGSTE / INTERVENTION per FID
	AND RS.starttime BETWEEN IPSSTAT.IPSEINTRITT AND IPSSTAT.IPSAUSTRITT
-- / I took birthday from IPSSTAT finally since not complete with any of the two tables below /
--LEFT JOIN CDMH_PSA.hng_out.psa_person_hng_cur PERS ON PAT.hospitalnumber = CAST(PERS.personnummer AS NVARCHAR) --EXEC sp_describe_first_result_set N'SELECT YourColumnName FROM YourTableName'; only 11min since LEFT added
--LEFT JOIN CDMH_Core.dwh_out.dim_patient_cur PERS ON PAT.hospitalnumber = PERS.InternalId
JOIN CDMH_PSA.phx_out.psa_bas_datenschutz_cur DATAPRO ON PAT.hospitalnumber = CAST(DATAPRO.patid AS NVARCHAR) 
LEFT JOIN [CDMH_PSA].phx_out.psa_bas_konzeption_cur KONZEPT ON PAT.hospitalnumber = CAST(KONZEPT.patid AS NVARCHAR) -- left join since if not found can still be used

-- /// Parentale Ernährung Parameter ///
-- / for patients having "inclusion parameter(s)" -> also select "additional parameter(s)" if present /
WHERE (
		-- take inclusion pe-parameters
		RS.parameterid IN (4060, 4066, 4068, 4069, 4070, 4071, 4072, 8344, 8350, 8357, 8358, 8359, 12517, 14778, 14779, 20381, 20382, 21658, 23221, 23467, 23468, 23926, 29636, 29637, 29751, 31564, 32179) --Inclusion PE-Parameter (Einschlussparameter ParenteraleErnährung.xlsx -> Parameter mit "1")
		OR 
		(RS.patientid
			IN (
				-- patients that have at least one Inclusion PE-Parameter
				SELECT RSsub.patientid
				FROM Table_RS_S RSsub
				WHERE RSsub.parameterid IN (4060, 4066, 4068, 4069, 4070, 4071, 4072, 8344, 8350, 8357, 8358, 8359, 12517, 14778, 14779, 20381, 20382, 21658, 23221, 23467, 23468, 23926, 29636, 29637, 29751, 31564, 32179) --Inclusion PE-Parameter (Einschlussparameter ParenteraleErnährung.xlsx -> Parameter mit "1")
				)
				-- then take also additional parameters
			AND (
				RS.parameterid IN (3752, 8223, 10603, 22045, 22478, 32266, 32267) --Additional PE-Parameter (Einschlussparameter ParenteraleErnährung.xlsx -> Parameter ohne "1")
				OR 
				RS.parameterid IN (23111, 23112, 22802, 22804, 22807, 22811, 22812, 22817, 22818, 22824, 22826, 22829, 22833, 22834, 22835, 22328, 22329, 22164, 22165, 22166, 21067, 31405, 31406, 31407, 25359, 28779, 30218, 30219, 30220, 30384, 30385, 30386, 30405, 30406, 30407, 30408, 30409, 30410, 16706, 16422, 16426, 17454, 13910, 13917, 10746, 10747, 10748, 10749, 10765, 10766, 7799, 4291, 4292, 4293, 4462, 4336, 4337, 4338, 4339, 4340, 4341, 4342, 4343, 4344, 4345, 4346, 4347, 4348, 4349, 4391, 4392, 4393, 3979, 4000, 4037, 4038, 4039, 4040, 4083, 4086, 4087, 4088, 4089, 4090, 4091, 4092, 4093, 4094, 4095, 4096, 4097, 4098, 4099, 4100, 4101, 4102, 4103, 4104, 4109, 4111, 4112, 4113, 4114, 4115, 4116, 4153, 4154, 4155, 4280, 4260, 4269, 4270, 4271, 4272, 4273, 4274, 4275, 4276, 4157, 4158, 5994, 5917, 5901) --Additional Parameter: EnteraleErnährung (Einschlussparameter EnteraleErnährung.xlsx -> Parameter mit "1")
				OR
				RS.parameterid IN (4053, 4054, 4055, 4056, 8339, 8340, 8341, 8342, 8343, 8345, 8346, 8347, 8348, 8349, 8351, 8352, 8353, 8354, 8355, 8356, 8357, 8358, 8359, 9821, 9824, 10435, 10603, 11205, 11231, 11232, 11251, 11436, 13653, 13676, 13677, 13678, 14040, 14361, 16431, 16432, 18436, 18785, 20960, 21916, 22918, 23221, 25169, 25170, 25171, 26216, 29091, 30382, 30555, 31569, 32266, 32267) --Additional Parameter: Infusionen (Parameter Infusionen.xlsx -> Parameter mit "1")
				OR 
				RS.parameterid IN (3969, 3971, 3970, 3968, 3972, 5889, 3962, 3963, 3965, 4042, 3966) -- Zufuhr-Parameter || Flüssigkeit würde es noch mehr/andere Parameter geben
				)
		)
	)

AND RS.starttime BETWEEN @FromDate AND @ToDate
AND RS.status IN (0,1,2, 777) -- 777 for signals (they don't have a status, 777 declared in WITH clause above) --takes 2.5h to run
AND (RS.Error = 0 OR RS.Error IS NULL) -- 0 for Signals, NULL for RangeSignals
AND DATEDIFF(YEAR, IPSSTAT.GEBDATUM, IPSSTAT.IPSEINTRITT) <= 18
AND DATAPRO.forschungsfreigabe_1 = 1
AND DATEDIFF (DAY, IPSSTAT.IPSEINTRITT, RS.starttime) <=30 --evt anpassen
ORDER BY RS.StartTime ASC






