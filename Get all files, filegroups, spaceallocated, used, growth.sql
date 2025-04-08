SELECT 
    fg.name AS FileGroupName,
    f.name AS LogicalFileName,
    f.type_desc AS FileType,
    f.physical_name AS PhysicalFileName,
    fg.is_default AS IsDefaultFileGroup,
    f.size * 8 / 1024 AS AllocatedSpaceMB,
    FILEPROPERTY(f.name, 'SpaceUsed') * 8 / 1024 AS UsedSpaceMB,
    (f.max_size * 8 / 1024) AS MaxSizeMB,
    CASE 
        WHEN f.is_percent_growth = 1 THEN CONCAT(f.growth, '%')
        ELSE CONCAT(f.growth * 8 / 1024, ' MB') 
    END AS Growth
FROM 
    sys.filegroups fg
JOIN 
    sys.database_files f ON f.data_space_id = fg.data_space_id
ORDER BY 
    fg.name, f.name;