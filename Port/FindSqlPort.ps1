param (
    [string]$Server,
    [int]$StartPort = 1433,
    [int]$EndPort = 1445
)

$ErrorActionPreference = "SilentlyContinue"

# Try resolving the server name once before scanning
try {
    [System.Net.Dns]::GetHostEntry($Server) | Out-Null
} catch {
    Write-Host "❌ Name resolution failed for '$Server'"
    exit 2
}

# Proceed to scan ports only if name resolution succeeded
$ports = $StartPort..$EndPort

foreach ($port in $ports) {
    $result = Test-NetConnection -ComputerName $Server -Port $port -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) {
        Write-Output $port
        exit 0
    }
}

Write-Host "❌ No open SQL Server port found on $Server in range $StartPort-$EndPort"
exit 1
