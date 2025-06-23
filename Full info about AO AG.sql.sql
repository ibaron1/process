SELECT 
    ag.name AS AvailabilityGroupName,
    agl.dns_name AS ListenerDNSName,
    agl.port AS ListenerPort,
    aglip.ip_address AS ListenerIPAddress,
    ar.replica_server_name AS ReplicaServerName,
    ar.endpoint_url AS ReplicaEndpointURL,
    -- Extract just the port from endpoint_url like TCP://Server:5022
    RIGHT(ar.endpoint_url, CHARINDEX(':', REVERSE(ar.endpoint_url)) - 1) AS ReplicaPort,
    ars.role_desc AS ReplicaRole,                 -- PRIMARY / SECONDARY
    ars.connected_state_desc AS ConnectedState,
    ars.synchronization_health_desc AS SyncHealth,
    ar.availability_mode_desc AS AvailabilityMode,
    ar.failover_mode_desc AS FailoverMode,
    db.name AS DatabaseName,
    drs.synchronization_state_desc AS DB_SyncState
FROM 
    sys.availability_groups ag
JOIN 
    sys.availability_group_listeners agl ON ag.group_id = agl.group_id
LEFT JOIN 
    sys.availability_group_listener_ip_addresses aglip ON agl.listener_id = aglip.listener_id
JOIN 
    sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN 
    sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
LEFT JOIN 
    sys.dm_hadr_database_replica_states drs ON ar.replica_id = drs.replica_id AND ag.group_id = drs.group_id
LEFT JOIN 
    sys.databases db ON drs.database_id = db.database_id
ORDER BY 
    ag.name, ar.replica_server_name, db.name;
