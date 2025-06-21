CREATE TABLE dbo.ParsedDeadlocks (
    DeadlockID     INT IDENTITY(1,1) PRIMARY KEY,
    CaptureTime    DATETIME DEFAULT GETDATE(),
    VictimSPID     VARCHAR(50),
    SPID1          VARCHAR(10),
    SPID2          VARCHAR(10),
    LoginName1     VARCHAR(100),
    LoginName2     VARCHAR(100),
    HostName1      VARCHAR(100),
    HostName2      VARCHAR(100),
    SQLText1       VARCHAR(MAX),
    SQLText2       VARCHAR(MAX),
    ResourceType1  VARCHAR(50),
    LockedObject1  VARCHAR(256),
    LockedObject2  VARCHAR(256),
    DeadlockGraph  XML
);
ALTER TABLE dbo.ParsedDeadlocks
ADD DeadlockHash AS CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CONVERT(NVARCHAR(MAX), DeadlockGraph)), 2) PERSISTED;
