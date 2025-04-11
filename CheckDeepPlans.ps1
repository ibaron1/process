# PowerShell script to detect deep XML query plans from SQL Server

# Configuration
$server = "YourSqlServerName"
$database = "YourDatabaseName"
$outputFolder = "C:\QueryPlans"

# Ensure output folder exists
if (!(Test-Path $outputFolder)) {
    New-Item -Path $outputFolder -ItemType Directory
}

# Load SQL Server module if not loaded
Import-Module SqlServer -ErrorAction SilentlyContinue

# Query to get raw plan binaries
$query = @"
SELECT id, session_id, plan_binary 
FROM dbo.DeepQueryPlans
"@

# Connect and fetch plans
$plans = Invoke-Sqlcmd -ServerInstance $server -Database $database -Query $query

# Function to check XML depth
function Get-MaxDepth {
    param([xml]$xml)

    function Traverse($node, $depth) {
        $max = $depth
        foreach ($child in $node.ChildNodes) {
            if ($child.NodeType -eq 'Element') {
                $max = [Math]::Max($max, (Traverse $child ($depth + 1)))
            }
        }
        return $max
    }

    return Traverse $xml.DocumentElement 1
}

foreach ($row in $plans) {
    $id = $row.id
    $sessionId = $row.session_id
    $binaryData = $row.plan_binary

    # Convert binary to string (assumes UTF-16 encoding)
    $xmlText = [System.Text.Encoding]::Unicode.GetString($binaryData)

    try {
        [xml]$xml = $xmlText
        $depth = Get-MaxDepth -xml $xml

        if ($depth -gt 128) {
            Write-Host "Session $sessionId has deep plan (Depth: $depth) - Saving to file"

            $fileName = Join-Path $outputFolder "plan_$sessionId.sqlplan"
            $xml.Save($fileName)
        } else {
            Write-Host "Session $sessionId - OK (Depth: $depth)"
        }

    } catch {
        Write-Warning "Failed to parse plan for Session $sessionId"
    }
}
