--If your application can tolerate potential data loss in the event of a crash, enabling delayed durability can enhance write throughput.
--SQL Shack

--To enable delayed durability at the database level:

ALTER DATABASE [YourDatabaseName] SET DELAYED_DURABILITY = FORCED;

--This setting allows transactions to commit without immediately flushing log records to disk, reducing write latency. 