param (
    [string]$SqlInstance
)

if (-not $SqlInstance) {
    Write-Host "Usage: .\BlockingTree.ps1 <SQLServerInstance>" -ForegroundColor Yellow
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Use script directory or a manual path for logs
$LogRoot = "C:\BlockingLogs"
# Or if running from script file, use this:
# $LogRoot = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "BlockingLogs"

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "SQL Server Blocking Tree - Connected to $SqlInstance"
$form.Size = New-Object System.Drawing.Size(1200, 800)

# TreeView
$treeView = New-Object System.Windows.Forms.TreeView
$treeView.Dock = 'Top'
$treeView.Height = 650
$form.Controls.Add($treeView)

# Refresh button
$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Manual Refresh"
$btnRefresh.Dock = 'Top'
$form.Controls.Add($btnRefresh)

# Export button
$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = "Save to CSV"
$btnExport.Dock = 'Top'
$form.Controls.Add($btnExport)

# Kill blocker button
$btnKill = New-Object System.Windows.Forms.Button
$btnKill.Text = "Kill Selected Blocker"
$btnKill.Dock = 'Top'
$form.Controls.Add($btnKill)

Import-Module SqlServer -ErrorAction SilentlyContinue

# Define global session data
$global:Sessions = @{}

# SQL query
$query = @"
SELECT
    r.session_id,
    r.blocking_session_id,
    s.login_name,
    s.original_login_name,
    s.host_name,
    s.program_name,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    s.status,
    r.command
FROM
    sys.dm_exec_requests r
JOIN
    sys.dm_exec_sessions s ON r.session_id = s.session_id
WHERE
    r.blocking_session_id <> 0
    OR r.session_id IN (SELECT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id <> 0)
"@

function Load-BlockingData {
    try {
        $data = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop
        return $data
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to connect to $SqlInstance`nError: $_")
        return $null
    }
}

function Populate-Tree {
    $treeView.Nodes.Clear()
    $global:Sessions.Clear()

    $blockingData = Load-BlockingData
    if (!$blockingData -or $blockingData.Count -eq 0) {
        $rootNode = New-Object System.Windows.Forms.TreeNode("No blocking detected.")
        $treeView.Nodes.Add($rootNode)
        return
    }

    foreach ($row in $blockingData) {
        $global:Sessions[$row.session_id] = $row
    }

    function Add-BlockingNode {
        param (
            [int]$SessionId,
            [System.Windows.Forms.TreeNode]$ParentNode
        )

        if ($global:Sessions.ContainsKey($SessionId)) {
            $session = $global:Sessions[$SessionId]
            $text = "SID: $($session.session_id) | Login: $($session.login_name) | Original Login: $($session.original_login_name) | Host: $($session.host_name) | Program: $($session.program_name) | Wait: $($session.wait_type)"

            $node = New-Object System.Windows.Forms.TreeNode($text)

            # Highlight blockers
            if (($global:Sessions.Values | Where-Object { $_.blocking_session_id -eq $session.session_id }).Count -gt 0) {
                $node.ForeColor = [System.Drawing.Color]::Red
            }

            if ($ParentNode -eq $null) {
                $treeView.Nodes.Add($node)
            } else {
                $ParentNode.Nodes.Add($node)
            }

            foreach ($child in $global:Sessions.Values | Where-Object { $_.blocking_session_id -eq $SessionId }) {
                Add-BlockingNode -SessionId $child.session_id -ParentNode $node
            }
        }
    }

    $rootBlockers = $global:Sessions.Values | Where-Object { $_.blocking_session_id -eq 0 }

    foreach ($blocker in $rootBlockers) {
        Add-BlockingNode -SessionId $blocker.session_id -ParentNode $null
    }

    $treeView.ExpandAll()

    # --- Auto-Save to CSV ---
    $currentDate = Get-Date -Format "yyyy-MM-dd"
    $currentTime = Get-Date -Format "HH-mm-ss"
    $serverSafeName = $SqlInstance.Replace(",", "_")
    $folderPath = Join-Path -Path $LogRoot -ChildPath "$serverSafeName\$currentDate"

    if (-not (Test-Path -Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
    }

    $fileName = "Blocking_${currentDate}_${currentTime}.csv"
    $filePath = Join-Path -Path $folderPath -ChildPath $fileName

    $csvData = @()
    foreach ($session in $global:Sessions.Values) {
        $csvData += [PSCustomObject]@{
            SessionId           = $session.session_id
            BlockingSessionId   = $session.blocking_session_id
            LoginName           = $session.login_name
            OriginalLoginName   = $session.original_login_name
            HostName            = $session.host_name
            ProgramName         = $session.program_name
            WaitType            = $session.wait_type
            WaitTimeMs          = $session.wait_time
            Status              = $session.status
            Command             = $session.command
        }
    }

    if ($csvData.Count -gt 0) {
        $csvData | Export-Csv -Path $filePath -NoTypeInformation
    }
}

# Refresh event
$btnRefresh.Add_Click({ Populate-Tree })

# Export to CSV
$btnExport.Add_Click({
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV Files (*.csv)|*.csv"
    $saveFileDialog.Title = "Save Blocking Tree to CSV"
    $saveFileDialog.ShowDialog()

    if ($saveFileDialog.FileName) {
        $csvData = @()
        foreach ($session in $global:Sessions.Values) {
            $csvData += [PSCustomObject]@{
                SessionId           = $session.session_id
                BlockingSessionId   = $session.blocking_session_id
                LoginName           = $session.login_name
                OriginalLoginName   = $session.original_login_name
                HostName            = $session.host_name
                ProgramName         = $session.program_name
                WaitType            = $session.wait_type
                WaitTimeMs          = $session.wait_time
                Status              = $session.status
                Command             = $session.command
            }
        }
        $csvData | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation
        [System.Windows.Forms.MessageBox]::Show("Blocking Tree exported successfully!")
    }
})

# Kill blocker event
$btnKill.Add_Click({
    if ($treeView.SelectedNode -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Please select a session to kill.")
        return
    }

    $selectedText = $treeView.SelectedNode.Text
    if ($selectedText -match "SID: (\d+)") {
        $sessionId = $Matches[1]
        $confirm = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to KILL session $sessionId?", "Confirm Kill", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                Invoke-Sqlcmd -ServerInstance $SqlInstance -Database "master" -Query "KILL $sessionId;"
                [System.Windows.Forms.MessageBox]::Show("Session $sessionId killed.")
                Populate-Tree
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Failed to kill session $sessionId.`nError: $_")
            }
        }
    }
})

# Auto-refresh timer
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000 # 5 seconds
$timer.Add_Tick({ Populate-Tree })
$timer.Start()

# Initial population
Populate-Tree

# Show the form
[void]$form.ShowDialog()
