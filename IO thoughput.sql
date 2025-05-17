--Capture Initial Statistics:
--Run the following query to capture the initial write statistics:
DECLARE @num_of_bytes_written bigint;
declare @start datetime=getdate();
DECLARE @interval_seconds char(8) = '00:00:10' ;

SELECT
    @num_of_bytes_written = vfs.num_of_bytes_written
FROM
    sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN
    sys.master_files AS mf
    ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id;

WAITFOR DELAY @interval_seconds; 

SELECT
    DB_NAME(vfs.database_id) AS database_name,
    mf.name AS logical_file_name,
    mf.physical_name,
    cast((vfs.num_of_bytes_written - @num_of_bytes_written) AS FLOAT) / datediff(second,@start,getdate()) / 1048576 AS write_throughput_MB_per_sec,
    vfs.num_of_writes,
    vfs.io_stall_write_ms
FROM
    sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN
    sys.master_files AS mf
    ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id;

/*
Record the num_of_bytes_written value for the file(s) you're interested in.
Wait for a Specific Interval:
Wait for a predetermined period (e.g., 60 seconds).
Cature Statistics Again:
After the interval, run the same query to capture the new num_of_bytes_written value.
Calculate Write Throughput:
Subtract the initial num_of_bytes_written value from the new value to get the number of bytes written during the interval. Then, divide by the number of seconds in your interval to get bytes per second, and convert to megabytes per second (MB/s):
*/

--This calculation provides the average write throughput in MB/s over the specified interval.

