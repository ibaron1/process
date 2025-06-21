WITH Deadlocks AS (
    SELECT 
        XEventData.event_data.query('(event/data[@name="xml_report"]/value/deadlock)[1]') AS DeadlockGraph
    FROM 
    (
        SELECT CAST(target_data AS XML) AS TargetData
        FROM sys.dm_xe_sessions AS s
        JOIN sys.dm_xe_session_targets AS t
            ON s.address = t.event_session_address
        WHERE s.name = 'system_health'
          AND t.target_name = 'ring_buffer'
    ) AS SessionData
    CROSS APPLY TargetData.nodes('//event[@name="xml_deadlock_report"]') AS XEventData(event_data)
)
INSERT INTO dbo.ParsedDeadlocks (
    VictimSPID, SPID1, SPID2, LoginName1, LoginName2, HostName1, HostName2,
    SQLText1, SQLText2, ResourceType1, LockedObject1, LockedObject2, DeadlockGraph
)
SELECT
    D.value('(//victim-list/victimProcess/@id)[1]', 'varchar(50)'),
    D.value('(//process-list/process/@spid)[1]', 'varchar(10)'),
    D.value('(//process-list/process/@spid)[2]', 'varchar(10)'),
    D.value('(//process-list/process/@loginname)[1]', 'varchar(100)'),
    D.value('(//process-list/process/@loginname)[2]', 'varchar(100)'),
    D.value('(//process-list/process/@hostname)[1]', 'varchar(100)'),
    D.value('(//process-list/process/@hostname)[2]', 'varchar(100)'),
    D.value('(//process-list/process/inputbuf)[1]', 'varchar(max)'),
    D.value('(//process-list/process/inputbuf)[2]', 'varchar(max)'),
    D.value('(//resource-list/*[1]/@type)[1]', 'varchar(50)'),
    D.value('(//resource-list/*[1]/@objectname)[1]', 'varchar(256)'),
    D.value('(//resource-list/*[2]/@objectname)[1]', 'varchar(256)'),
    D AS DeadlockGraph
FROM Deadlocks AS X
CROSS APPLY (SELECT DeadlockGraph) AS A(D)
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.ParsedDeadlocks
    WHERE DeadlockHash = CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONVERT(NVARCHAR(MAX), A.D)), 2)
);
