SELECT ITEM.mfg, COALESCE(IP.itemId,ITEM.itemId) AS itemId , IP.D90TranQty, IP.D60TranQty, IP.D90qStk, IP.D60qStk, IP.D1qStk, IP.[diffene of invenTrack < 20%]
     , IP.[TranTrack / inventory < 20%], IP.buildQTY, IP.openQty, IP.STAopenQty, ITEM.cAvg
FROM
	(SELECT COALESCE(ITM.itemId,OP.itemId) AS itemId, ITM.D90TranQty, ITM.D60TranQty, ITM.D90qStk, ITM.D60qStk, ITM.D1qStk
		 , ITM.invenTrack AS [diffene of invenTrack < 20%], ITM.TranTrack AS [TranTrack / inventory < 20%]
		 , ITM.buildQTY, ISNULL(OP.openQty,0) AS openQty , ISNULL(OP.STAopenQty,0) AS STAopenQty
		 --, ISNULL(OP.cAvg,0) AS cAvg, ISNULL(OP.openAmt,0) AS openAmt
	FROM
		(SELECT COALESCE(IT.itemId, BP.partId) AS itemId, IT.D90TranQty, IT.D60TranQty, IT.D90qStk, IT.D60qStk
			 , IT.D1qStk, IT.invenTrack, IT.TranTrack, ISNULL(BP.buildQTY,0) AS buildQTY, IT.cAvg
		FROM
			(SELECT COALESCE(T.itemId,I.itemId) AS itemId , ISNULL(T.D90TranQty,0) AS D90TranQty
				  , ISNULL(T.D60TranQty,0) AS D60TranQty , ISNULL(I.D90qStk,0) AS D90qStk, ISNULL(I.D60qStk,0) AS D60qStk, ISNULL(I.D1qStk,0) AS D1qStk
				  ,CASE
					  WHEN (ISNULL(I.D60qStk,0)!=0 AND ISNULL(I.D1qStk,0)!=0) 
					  AND ABS((ISNULL(I.D90qStk,0)-ISNULL(I.D60qStk,0))/ ISNULL(I.D60qStk,0))<0.2
					  AND ABS((ISNULL(I.D60qStk,0)-ISNULL(I.D1qStk,0))/ ISNULL(I.D1qStk,0))<0.2  THEN 'slowChange'
					  ELSE ''
				   END AS invenTrack--If inventory  both (d90: d60  and d60:d1) < 20%
				  ,CASE
					   WHEN (ISNULL(I.D60qStk,0)!=0 AND ISNULL(I.D90qStk,0)!=0) 
					   AND ( ABS((ISNULL(T.D90TranQty,0)/ISNULL(I.D90qStk,0)))<0.2
					   AND ABS((ISNULL(T.D60TranQty,0)/ISNULL(I.D60qStk,0)))<0.2) THEN 'slowMove'
					   ELSE ''
				   END AS TranTrack--If stock transfer both (d60transfer: d60qstk  and d90transfer: d90qstk) < 20%
				   , I.cAvg
			FROM
				(SELECT COALESCE(D60.itemId, D90.itemId) AS itemId , D90.D90TranQty,D60.D60TranQty
				FROM
					(SELECT 
						  --[tranDate]
						  --,[userId]
						  --,[entry]
						  --,[type]
						  [itemId]
						  ,SUM([qty]) AS D60TranQty
						 -- ,[jobId]
						  --,RTRIM([locId]) AS locId
						  --,[binId]
						  --,RTRIM([xvarToLoc]) As xvarToLoc
					   --   ,[tranDt]
						  --,[comment]
					FROM [CVE].[dbo].[MILOGH]
					WHERE 
					tranDt >=convert( nvarchar(8), DATEADD(day, -60, GETDATE()),112)
					AND type = 24
					AND ((locId LIKE 'PMS%' AND xvarToLoc LIKE 'ASY%')
					OR(locId LIKE 'PMS%' AND xvarToLoc = 'PNT')
					OR (locId LIKE 'PLN%' AND xvarToLoc LIKE 'ASY%')
					OR (locId LIKE 'PLN%' AND xvarToLoc=  'PNT')
					)
					AND locId !='PMS5'
					AND locId !='PMS6'
					AND (jobId='APPLE' OR jobId='Samsung')
					GROUP BY [itemId]) AS D60
				FULL JOIN
					(SELECT 
						  --[tranDate]
						  --,[userId]
						  --,[entry]
						  --,[type]
						   [itemId]
						  ,SUM([qty]) AS D90TranQty
						 -- ,[jobId]
						  --,RTRIM([locId]) AS locId
						  --,[binId]
						  --,RTRIM([xvarToLoc]) As xvarToLoc
					   --   ,[tranDt]
						  --,[comment]
					FROM [CVE].[dbo].[MILOGH]
					WHERE 
					tranDt >=convert( nvarchar(8), DATEADD(day, -60, GETDATE()),112)
					AND type = 24
					AND ((locId LIKE 'PMS%' AND xvarToLoc LIKE 'ASY%')
					OR(locId LIKE 'PMS%' AND xvarToLoc = 'PNT')
					OR (locId LIKE 'PLN%' AND xvarToLoc LIKE 'ASY%')
					OR (locId LIKE 'PLN%' AND xvarToLoc=  'PNT')
					)
					AND locId !='PMS5'
					AND locId !='PMS6'
					AND (jobId='APPLE' OR jobId='Samsung')
					GROUP BY [itemId]) AS D90
				ON D60.itemId=D90.itemId) AS T--60/90 Day Transfer data
			FULL JOIN 
				(SELECT P.itemId, SUM(ISNULL(P.D1qStk,0)) AS D1qStk, SUM(ISNULL(P.D60qStk,0)) AS D60qStk , SUM(ISNULL(P.D90qStk,0)) AS D90qStk
					   , (SUM(ISNULL(P.D1extAmt,0))+SUM(ISNULL(P.D60extAmt,0))+SUM(ISNULL(P.D90extAmt,0)))/(SUM(ISNULL(P.D1qStk,0))+SUM(ISNULL(P.D60qStk,0))+SUM(ISNULL(P.D90qStk,0)))AS cAvg
				FROM
					(SELECT RTRIM(inv.itemId) AS itemId
							  --,RIGHT(itm.xdesc,(LEN(itm.xdesc) - CHARINDEX('|',itm.xdesc))) AS mfg
							  --,LEFT(itm.xdesc,CHARINDEX('|',itm.xdesc)
							  --) AS type
							  --,RTRIM(inv.locId) AS locId
							  ,ROUND(inv.qStk,0) As qStk
							  --,itm.cAvg
							  ,inv.qStk * itm.cAvg AS extAmt
							  --,inv.dateISO
							  ,CASE
								   WHEN date= convert( nvarchar(8), DATEADD(day, -1, GETDATE()),112)  THEN 'D1qStk'
								   WHEN date= convert( nvarchar(8), DATEADD(day, -60, GETDATE()),112) THEN 'D60qStk'
								   WHEN date= convert( nvarchar(8), DATEADD(day, -90, GETDATE()),112) THEN 'D90qStk'
								   ELSE 'Error'
							   END AS DqStk
							  ,CASE
								   WHEN date= convert( nvarchar(8), DATEADD(day, -1, GETDATE()),112)  THEN 'D1extAmt'
								   WHEN date= convert( nvarchar(8), DATEADD(day, -60, GETDATE()),112) THEN 'D60extAmt'
								   WHEN date= convert( nvarchar(8), DATEADD(day, -90, GETDATE()),112) THEN 'D90extAmt'
								   ELSE 'Error'
							   END AS DextAmt
					FROM [CVE].[dbo].[MIILOCQT] inv LEFT JOIN [CVE].[dbo].[MIITEM] itm
					ON inv.itemId = itm.itemId
					WHERE itm.type IN (0,2)
					AND itm.status = 0
					AND (inv.locId LIKE 'PMS%'
					OR inv.locId LIKE 'PLN%'
					)
					AND (inv.locId NOT IN ('PMS5','PMS6','PLN5','PLN6') )
					AND ROUND(inv.qStk,0) <> 0
					AND (  date= convert( nvarchar(8), DATEADD(day, -1, GETDATE()),112)
						OR date= convert( nvarchar(8), DATEADD(day, -60, GETDATE()),112)
						OR date= convert( nvarchar(8), DATEADD(day, -90, GETDATE()),112))) AS S--SNAPSHOP
				PIVOT(  SUM([qStk]) FOR DqStk IN ([D1qStk],[D60qStk],[D90qStk])  ) AS P
				PIVOT(  SUM([extAmt]) FOR DextAmt IN ([D1extAmt],[D60extAmt],[D90extAmt])  ) AS P
				GROUP BY P.itemId) AS I --1/60/90 Day Inventory SnapSHOT
			ON T.itemId =I.itemId) AS IT--Inventory Snapshop and Transfer Info
		LEFT JOIN
			(SELECT DISTINCT BD.partId, SUM(MO.buildQTY) OVER(Partition by BD.partId ) AS buildQTY
			FROM
				(SELECT --[mohId]
					  --[jobId]
					 -- ,[locId]
					  [buildItem]
					  --,[bomRev]
					  --,[moStat]
					  --,[ordDate]
					  --,[endDate]
					  ,SUM([endQty]) AS buildQTY
				FROM [CVE].[dbo].[MIMOH]
				WHERE [bomRev]='ASY'
				AND [moStat]=1
				AND ([jobId]='APPLE' OR [jobId]='SAMSUNG' )
				AND [locId]='SHP'
				AND [ordDate]>= CONVERT(NVARCHAR(10), DATEADD(day, -30, GETDATE()),112)
				GROUP BY [buildItem]) AS MO
			LEFT JOIN
				(SELECT [bomItem]
					  --,[bomRev]
					  ,[partId]
				FROM [CVE].[dbo].[MIBOMD]
				WHERE [bomRev]='ASY'
				AND ([bomItem] LIKE 'IPHONE-%' OR [bomItem] LIKE 'SGH-%' OR
				[bomItem] LIKE 'SPH-%' OR [bomItem] LIKE 'SM-%')) AS bd
			ON mo.buildItem=bd.bomItem) AS bp --D30 (PREVIOUS 30 DAY TP NOW) Consumed Part with BuildPhone Qty 
		ON IT.itemId=BP.partId) AS ITM--Inventory Snapshot/ Stock Transfer/ Mo
	LEFT JOIN
		(SELECT COALESCE(AO.itemId,SPO.itemId) AS itemId, AO.openQty, ISNULL(SPO.STAopenQty,0) AS STAopenQty
	FROM
		(SELECT DISTINCT
			   d.itemId
			  ,SUM((d.ordered - d.received)) OVER (Partition by d.itemId) AS openQty
			  --,SUM(d.price * (d.ordered - d.received)) OVER (Partition by d.itemId) / SUM((d.ordered - d.received)) OVER (Partition by d.itemId) AS cAvg
			  --,SUM(d.price * (d.ordered - d.received)) OVER (Partition by d.itemId)  AS openAmt
		FROM [CVE].[dbo].[MIPOD] d LEFT JOIN [CVE].[dbo].[MIPOH] h
		ON d.pohId = h.pohId JOIN [CVE].[dbo].[MIITEM] i
		ON d.itemId = i.itemId
		WHERE 
		h.poStatus <> 0
		AND
		d.dStatus = 1
		AND
		i.type IN (0,2) -- Purchase Items Only; 4 should be used for RCL
		AND 
		(d.ordered - d.received) > 0
		AND h.ordDate >= 20160101
		AND (d.pohId LIKE 'PMS%' OR  d.pohId LIKE 'ATT%' OR d.pohId LIKE 'TMO%' OR d.pohId LIKE 'BBY%' )) AS AO--ALL OPEN PO
	LEFT JOIN
		(SELECT DISTINCT
			   d.itemId
			  ,SUM((d.ordered - d.received)) OVER (Partition by d.itemId) AS STAopenQty
			  --,SUM(d.price * (d.ordered - d.received)) OVER (Partition by d.itemId) / SUM((d.ordered - d.received)) OVER (Partition by d.itemId) AS cAvg
			  --,SUM(d.price * (d.ordered - d.received)) OVER (Partition by d.itemId)  AS openAmt
		FROM [CVE].[dbo].[MIPOD] d LEFT JOIN [CVE].[dbo].[MIPOH] h
		ON d.pohId = h.pohId JOIN [CVE].[dbo].[MIITEM] i
		ON d.itemId = i.itemId
		WHERE 
		h.poStatus <> 0
		AND
		d.dStatus = 1
		AND
		i.type IN (0,2) -- Purchase Items Only; 4 should be used for RCL
		AND 
		(d.ordered - d.received) > 0
		AND h.ordDate >= 20160101
		AND (d.pohId LIKE 'PMS%' OR  d.pohId LIKE 'ATT%' OR d.pohId LIKE 'TMO%' OR d.pohId LIKE 'BBY%' )
		AND h.suplId='STA') AS Spo--STA PO
	ON AO.itemId=SPO.itemId) AS OP --OPEN PO
	ON ITM.itemId=OP.itemId) AS IP--ITM+OPEN PO
LEFT JOIN
	(SELECT  [itemId]
		  ,CASE SUBSTRING(xdesc,ABS(CHARINDEX('|',xdesc))+1,3)
				WHEN 'APP' THEN 'APPLE'
				WHEN 'SAM' THEN 'SAMSUNG'
				ELSE 'OTHER'
			END AS mfg
		  ,[cAvg]
	FROM [CVE].[dbo].[MIITEM]) AS ITEM
ON IP.itemId=ITEM.itemId
