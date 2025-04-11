# === CONFIGURATION ===

# SQL Server details
$server = "YourSqlServerName"
$database = "YourDatabaseName"

# Output path for query plan files
$outputFolder = "C:\QueryPlans"

# Email settings
$smtpServer = "smtp.yourdomain.com"
$smtpPort = 587
$smtpUser = "your_email@yourdomain.com"
$smtpPass = "your_password_here"
$from = "your_email@yourdomain.com"
$to = "recipient@yourdomain.com"
$subject = "⚠️ Deep Query Plans Detected"
$body = "Attached are the query plans that exceeded 128 nesting levels."

# =======================

# Ensure output folder exists
if (!(Test-Path $outputFolder)) {
    New-Item -Path $outputFolder -ItemType Directory
}

# Load SQL Server module
Import-Module SqlServer -ErrorAction SilentlyContinue

# SQL to retrieve raw binary query plans
$query = @"
SELECT id, session_id, plan_binary 
FROM dbo.DeepQueryPlans
"@

# Fetch query plans
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

# List to hold file paths of deep plans
$deepPlans = @()

# Process plans
foreach ($row in $plans) {
    $id = $row.id
    $sessionId = $row.session_id
    $binaryData = $row.plan_binary

    try {
        $xmlText = [System.Text.Encoding]::Unicode.GetString($binaryData)
        [xml]$xml = $xmlText
        $depth = Get-MaxDepth -xml $xml

        if ($depth -gt 128) {
            Write-Host "Session $sessionId: Depth = $depth (saving plan)"
            $filePath = Join-Path $outputFolder "plan_$sessionId.sqlplan"
            $xml.Save($filePath)
            $deepPlans += $filePath
        } else {
            Write-Host "Session $sessionId: Depth = $depth (OK)"
        }

    } catch {
        Write-Warning "Could not parse XML for session $sessionId"
    }
}

# Send email if deep plans exist
if ($deepPlans.Count -gt 0) {
    $smtpCreds = New-Object System.Management.Automation.PSCredential($smtpUser, (ConvertTo-SecureString $smtpPass -AsPlainText -Force))

    Send-MailMessage -From $from `
                     -To $to `
                     -Subject $subject `
                     -Body $body `
                     -SmtpServer $smtpServer `
                     -Port $smtpPort `
                     -UseSsl `
                     -Credential $smtpCreds `
                     -Attachments $deepPlans

    Write-Host "📬 Email sent with $($deepPlans.Count) .sqlplan file(s)."
} else {
    Write-Host "✅ No deep plans found. No email sent."
}
